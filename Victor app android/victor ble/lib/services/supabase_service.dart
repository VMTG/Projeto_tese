import 'dart:async';
import 'package:supabase/supabase.dart';
import 'package:uuid/uuid.dart';
import 'package:Sensor/main.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  late SupabaseClient _supabase;
  bool _initialized = false;
  bool get isInitialized => _initialized;

  String _deviceId = '';
  String get deviceId => _deviceId;

  double _impactThreshold = 10.0; // Deve corresponder ao ESP32
  double get impactThreshold => _impactThreshold;
  DateTime? _lastImpactTime;
  DateTime? get lastImpactTime => _lastImpactTime;

  OperationMode _currentMode = OperationMode.continuous;
  OperationMode get currentMode => _currentMode;
  set currentMode(OperationMode mode) {
    _currentMode = mode;

    if (mode == OperationMode.neutral) {
      _resetDataStreams();
    }

    if (_initialized && _deviceId.isNotEmpty) {
      try {
        String modeString;
        if (mode == OperationMode.continuous) {
          modeString = 'continuous';
        } else if (mode == OperationMode.impact) {
          modeString = 'impact';
        } else {
          modeString = 'neutral';
        }

        _supabase
            .from('devices')
            .update({'operation_mode': modeString}).eq('id', _deviceId);
      } catch (e) {
        print('Error updating operation mode: $e');
      }
    }
  }

  void _resetDataStreams() {
    _temperatureStreamController.add([]);
    _pressureStreamController.add([]);
    _accelXStreamController.add([]);
    _accelYStreamController.add([]);
    _accelZStreamController.add([]);
    _accelTotalStreamController.add([]);
    _gyroXStreamController.add([]);
    _gyroYStreamController.add([]);
    _gyroZStreamController.add([]);
    _gyroTotalStreamController.add([]);

    _preImpactTempBuffer.clear();
    _preImpactPressureBuffer.clear();
    _preImpactAccelXBuffer.clear();
    _preImpactAccelYBuffer.clear();
    _preImpactAccelZBuffer.clear();
    _preImpactAccelTotalBuffer.clear();
    _preImpactGyroXBuffer.clear();
    _preImpactGyroYBuffer.clear();
    _preImpactGyroZBuffer.clear();
    _preImpactGyroTotalBuffer.clear();

    _impactDataDisplayed = false;
    _lastImpactTime = null;

    // Limpar variáveis de processamento de impacto
    _currentImpactTimestamp = null;
    _expectedSamples = 0;
    _impactDataBuffer.clear();
  }

  // Stream controllers
  final _temperatureStreamController =
      StreamController<List<SensorData>>.broadcast();
  final _pressureStreamController =
      StreamController<List<SensorData>>.broadcast();
  final _accelTotalStreamController =
      StreamController<List<SensorData>>.broadcast();
  final _gyroTotalStreamController =
      StreamController<List<SensorData>>.broadcast();
  final _accelXStreamController =
      StreamController<List<SensorData>>.broadcast();
  final _accelYStreamController =
      StreamController<List<SensorData>>.broadcast();
  final _accelZStreamController =
      StreamController<List<SensorData>>.broadcast();
  final _gyroXStreamController = StreamController<List<SensorData>>.broadcast();
  final _gyroYStreamController = StreamController<List<SensorData>>.broadcast();
  final _gyroZStreamController = StreamController<List<SensorData>>.broadcast();
  final _impactDetectedController = StreamController<DateTime>.broadcast();

  // Getters para streams
  Stream<List<SensorData>> get temperatureStream =>
      _temperatureStreamController.stream;
  Stream<List<SensorData>> get pressureStream =>
      _pressureStreamController.stream;
  Stream<List<SensorData>> get accelTotalStream =>
      _accelTotalStreamController.stream;
  Stream<List<SensorData>> get gyroTotalStream =>
      _gyroTotalStreamController.stream;
  Stream<List<SensorData>> get accelXStream => _accelXStreamController.stream;
  Stream<List<SensorData>> get accelYStream => _accelYStreamController.stream;
  Stream<List<SensorData>> get accelZStream => _accelZStreamController.stream;
  Stream<List<SensorData>> get gyroXStream => _gyroXStreamController.stream;
  Stream<List<SensorData>> get gyroYStream => _gyroYStreamController.stream;
  Stream<List<SensorData>> get gyroZStream => _gyroZStreamController.stream;
  Stream<DateTime> get impactDetectedStream => _impactDetectedController.stream;

  Timer? _pollingTimer;

  // Controle de dados em modo de impacto
  bool _impactDataDisplayed = false;
  bool get impactDataDisplayed => _impactDataDisplayed;

  // Buffer para dados pré-impacto
  final List<SensorData> _preImpactTempBuffer = [];
  final List<SensorData> _preImpactPressureBuffer = [];
  final List<SensorData> _preImpactAccelXBuffer = [];
  final List<SensorData> _preImpactAccelYBuffer = [];
  final List<SensorData> _preImpactAccelZBuffer = [];
  final List<SensorData> _preImpactAccelTotalBuffer = [];
  final List<SensorData> _preImpactGyroXBuffer = [];
  final List<SensorData> _preImpactGyroYBuffer = [];
  final List<SensorData> _preImpactGyroZBuffer = [];
  final List<SensorData> _preImpactGyroTotalBuffer = [];
  final int _bufferSize = 50;

  // Variáveis para processamento de impacto via BLE
  String? _currentImpactTimestamp;
  int _expectedSamples = 0;
  List<Map<String, dynamic>> _impactDataBuffer = [];

  Future<bool> initialize(String supabaseUrl, String supabaseKey) async {
    if (_initialized) return true;

    try {
      _supabase = SupabaseClient(supabaseUrl, supabaseKey);
      await testConnection();
      _initialized = true;
      await _initializeDevice();
      _setupDataPolling();
      print('Supabase service initialized with device ID: $_deviceId');
      return true;
    } catch (e) {
      print('Error initializing Supabase service: $e');
      return false;
    }
  }

  Future<bool> testConnection() async {
    try {
      final response = await _supabase.from('devices').select().limit(1);
      print('Connection test successful');
      return true;
    } catch (e) {
      print('Connection test failed: $e');
      return false;
    }
  }

  Future<void> _initializeDevice() async {
    try {
      final uuid = Uuid();
      _deviceId = uuid.v4();

      // Tentar inserir o device e verificar resposta
      final insertResponse = await _supabase.from('devices').insert({
        'id': _deviceId,
        'name': 'ESP32_GY91',
        'operation_mode':
            _currentMode == OperationMode.continuous ? 'continuous' : 'impact',
        'impact_threshold': _impactThreshold,
      }).select(); // pedir dados de retorno para verificar

      // Se a resposta tiver erro, insertResponse pode estar vazio ou null
      if (insertResponse == null ||
          (insertResponse is List && insertResponse.isEmpty)) {
        // Tentar recuperar device por name (caso já exista)
        final query = await _supabase
            .from('devices')
            .select()
            .eq('name', 'ESP32_GY91')
            .limit(1);
        if (query != null && query is List && query.isNotEmpty) {
          final found = query.first;
          if (found['id'] != null) {
            _deviceId = found['id'] as String;
            print('Device already exists. Using existing ID: $_deviceId');
            return;
          }
        }

        print(
            'Warning: device insert returned empty. DeviceId left as: $_deviceId');
      } else {
        // Normalmente insertResponse contém a linha criada
        try {
          final created =
              insertResponse is List ? insertResponse.first : insertResponse;
          if (created != null && created['id'] != null) {
            _deviceId = created['id'] as String;
            print('Device registered with ID: $_deviceId');
            return;
          }
        } catch (_) {
          print('Device inserted but response parsing failed. ID: $_deviceId');
        }
      }
    } catch (e) {
      print('Error initializing device: $e');
      // Não limpar _deviceId aqui — se insert falhou por RLS ou permissões,
      // manter o uuid local pode ajudar no debugging, mas avisa no log
    }
  }

  Future<void> updateImpactThreshold(double threshold) async {
    _impactThreshold = threshold;

    if (_initialized && _deviceId.isNotEmpty) {
      try {
        await _supabase
            .from('devices')
            .update({'impact_threshold': threshold}).eq('id', _deviceId);

        print('Impact threshold updated to $threshold');
      } catch (e) {
        print('Error updating impact threshold: $e');
      }
    }
  }

  void _setupDataPolling() {
    _pollingTimer = Timer.periodic(Duration(milliseconds: 1000), (timer) {
      _pollSensorData();
    });
  }

  Future<void> _pollSensorData() async {
    if (!_initialized || _deviceId.isEmpty) return;

    try {
      if (_currentMode == OperationMode.impact && !_impactDataDisplayed) {
        await _checkForImpacts();
        return;
      }

      final sensorData = await _supabase
          .from('raw_sensor_data')
          .select()
          .eq('device_id', _deviceId)
          .order('timestamp', ascending: false)
          .limit(150);

      if (sensorData != null && sensorData.isNotEmpty) {
        _processSensorData(sensorData);
      }
    } catch (e) {
      print('Error during data polling: $e');
    }
  }

  void _processSensorData(List<dynamic> data) {
    List<SensorData> tempData = [];
    List<SensorData> pressureData = [];
    List<SensorData> accelXData = [];
    List<SensorData> accelYData = [];
    List<SensorData> accelZData = [];
    List<SensorData> accelTotalData = [];
    List<SensorData> gyroXData = [];
    List<SensorData> gyroYData = [];
    List<SensorData> gyroZData = [];
    List<SensorData> gyroTotalData = [];

    data = data.reversed.toList();

    for (var item in data) {
      try {
        DateTime timestamp = DateTime.parse(item['timestamp'] as String);

        tempData.add(
            SensorData(timestamp, (item['temperature'] as num).toDouble()));
        pressureData
            .add(SensorData(timestamp, (item['pressure'] as num).toDouble()));
        accelXData
            .add(SensorData(timestamp, (item['accel_x'] as num).toDouble()));
        accelYData
            .add(SensorData(timestamp, (item['accel_y'] as num).toDouble()));
        accelZData
            .add(SensorData(timestamp, (item['accel_z'] as num).toDouble()));
        accelTotalData.add(
            SensorData(timestamp, (item['accel_total'] as num).toDouble()));
        gyroXData
            .add(SensorData(timestamp, (item['gyro_x'] as num).toDouble()));
        gyroYData
            .add(SensorData(timestamp, (item['gyro_y'] as num).toDouble()));
        gyroZData
            .add(SensorData(timestamp, (item['gyro_z'] as num).toDouble()));
        gyroTotalData
            .add(SensorData(timestamp, (item['gyro_total'] as num).toDouble()));

        if (_currentMode == OperationMode.continuous || _impactDataDisplayed) {
          _temperatureStreamController.add(tempData);
          _pressureStreamController.add(pressureData);
          _accelXStreamController.add(accelXData);
          _accelYStreamController.add(accelYData);
          _accelZStreamController.add(accelZData);
          _accelTotalStreamController.add(accelTotalData);
          _gyroXStreamController.add(gyroXData);
          _gyroYStreamController.add(gyroYData);
          _gyroZStreamController.add(gyroZData);
          _gyroTotalStreamController.add(gyroTotalData);
        } else {
          _updatePreImpactBuffer(
              timestamp,
              (item['temperature'] as num).toDouble(),
              (item['pressure'] as num).toDouble(),
              (item['accel_x'] as num).toDouble(),
              (item['accel_y'] as num).toDouble(),
              (item['accel_z'] as num).toDouble(),
              (item['accel_total'] as num).toDouble(),
              (item['gyro_x'] as num).toDouble(),
              (item['gyro_y'] as num).toDouble(),
              (item['gyro_z'] as num).toDouble(),
              (item['gyro_total'] as num).toDouble());
        }
      } catch (e) {
        print('Error processing sensor data: $e');
      }
    }
  }

  Future<void> _checkForImpacts() async {
    if (_currentMode != OperationMode.impact) return;

    try {
      final recentData = await _supabase
          .from('raw_sensor_data')
          .select()
          .eq('device_id', _deviceId)
          .order('timestamp', ascending: false)
          .limit(10);

      if (recentData != null && recentData.isNotEmpty) {
        for (var item in recentData) {
          double accelTotal = (item['accel_total'] as num).toDouble();
          DateTime timestamp = DateTime.parse(item['timestamp'] as String);

          _updatePreImpactBuffer(
              timestamp,
              (item['temperature'] as num).toDouble(),
              (item['pressure'] as num).toDouble(),
              (item['accel_x'] as num).toDouble(),
              (item['accel_y'] as num).toDouble(),
              (item['accel_z'] as num).toDouble(),
              accelTotal,
              (item['gyro_x'] as num).toDouble(),
              (item['gyro_y'] as num).toDouble(),
              (item['gyro_z'] as num).toDouble(),
              (item['gyro_total'] as num).toDouble());

          if (accelTotal >= _impactThreshold) {
            _handleImpactDetected(timestamp);
            break;
          }
        }
      }
    } catch (e) {
      print('Error checking for impacts: $e');
    }
  }

  void _handleImpactDetected(DateTime impactTime) {
    _lastImpactTime = impactTime;
    _impactDataDisplayed = true;

    _impactDetectedController.add(impactTime);

    _temperatureStreamController.add(_preImpactTempBuffer);
    _pressureStreamController.add(_preImpactPressureBuffer);
    _accelXStreamController.add(_preImpactAccelXBuffer);
    _accelYStreamController.add(_preImpactAccelYBuffer);
    _accelZStreamController.add(_preImpactAccelZBuffer);
    _accelTotalStreamController.add(_preImpactAccelTotalBuffer);
    _gyroXStreamController.add(_preImpactGyroXBuffer);
    _gyroYStreamController.add(_preImpactGyroYBuffer);
    _gyroZStreamController.add(_preImpactGyroZBuffer);
    _gyroTotalStreamController.add(_preImpactGyroTotalBuffer);

    Timer(Duration(seconds: 10), () {
      _impactDataDisplayed = false;
    });
  }

  void _updatePreImpactBuffer(
      DateTime timestamp,
      double temp,
      double pressure,
      double ax,
      double ay,
      double az,
      double accelTotal,
      double gx,
      double gy,
      double gz,
      double gyroTotal) {
    _preImpactTempBuffer.add(SensorData(timestamp, temp));
    _preImpactPressureBuffer.add(SensorData(timestamp, pressure));
    _preImpactAccelXBuffer.add(SensorData(timestamp, ax));
    _preImpactAccelYBuffer.add(SensorData(timestamp, ay));
    _preImpactAccelZBuffer.add(SensorData(timestamp, az));
    _preImpactAccelTotalBuffer.add(SensorData(timestamp, accelTotal));
    _preImpactGyroXBuffer.add(SensorData(timestamp, gx));
    _preImpactGyroYBuffer.add(SensorData(timestamp, gy));
    _preImpactGyroZBuffer.add(SensorData(timestamp, gz));
    _preImpactGyroTotalBuffer.add(SensorData(timestamp, gyroTotal));

    if (_preImpactTempBuffer.length > _bufferSize)
      _preImpactTempBuffer.removeAt(0);
    if (_preImpactPressureBuffer.length > _bufferSize)
      _preImpactPressureBuffer.removeAt(0);
    if (_preImpactAccelXBuffer.length > _bufferSize)
      _preImpactAccelXBuffer.removeAt(0);
    if (_preImpactAccelYBuffer.length > _bufferSize)
      _preImpactAccelYBuffer.removeAt(0);
    if (_preImpactAccelZBuffer.length > _bufferSize)
      _preImpactAccelZBuffer.removeAt(0);
    if (_preImpactAccelTotalBuffer.length > _bufferSize)
      _preImpactAccelTotalBuffer.removeAt(0);
    if (_preImpactGyroXBuffer.length > _bufferSize)
      _preImpactGyroXBuffer.removeAt(0);
    if (_preImpactGyroYBuffer.length > _bufferSize)
      _preImpactGyroYBuffer.removeAt(0);
    if (_preImpactGyroZBuffer.length > _bufferSize)
      _preImpactGyroZBuffer.removeAt(0);
    if (_preImpactGyroTotalBuffer.length > _bufferSize)
      _preImpactGyroTotalBuffer.removeAt(0);
  }

  // PROCESSAMENTO DE DADOS VIA BLE (MODO DE IMPACTO)
  Future<void> sendSensorData(String rawData) async {
    if (!_initialized || _deviceId.isEmpty) return;

    try {
      // Verificar tipo de mensagem do ESP32
      if (rawData.startsWith('IMPACT_START:')) {
        _handleImpactStart(rawData);
      } else if (rawData.startsWith('IMPACT_DATA:')) {
        _handleImpactData(rawData);
      } else if (rawData.startsWith('IMPACT_END:')) {
        await _handleImpactEnd(rawData);
      } else if (rawData.contains('A:') && rawData.contains('G:')) {
        // Dados de modo contínuo
        await _handleContinuousData(rawData);
      }
    } catch (e) {
      print('Error processing sensor data: $e');
    }
  }

  // Processar início de evento de impacto
  void _handleImpactStart(String data) {
    try {
      // Formato: IMPACT_START:timestamp,totalSamples,preImpactSamples
      final parts = data.substring(13).split(',');
      // Guardar o timestamp vindo do ESP apenas como referência (millis desde boot).
      final espImpactMillis = parts.isNotEmpty ? parts[0] : null;
      _expectedSamples = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
      _impactDataBuffer.clear();

      // **Registar um timestamp absoluto que usaremos na BD**
      final nowIso = DateTime.now().toIso8601String();
      _currentImpactTimestamp = nowIso; // string ISO usada para inserir na BD
      print('📥 Impact event started (ESP millis: $espImpactMillis). '
          'Using impact_timestamp = $_currentImpactTimestamp, expecting $_expectedSamples samples');
    } catch (e) {
      print('❌ Error handling impact start: $e');
    }
  }

  // Processar dados de impacto individuais
  void _handleImpactData(String data) {
    try {
      // Formato: IMPACT_DATA:impactTimestamp,sequenceNumber,isPreImpact,timestamp,ax,ay,az,at,gx,gy,gz,gt
      final parts = data.substring(12).split(',');

      if (parts.length < 12) {
        print('❌ Invalid impact data format: $data');
        return;
      }

      if (_currentImpactTimestamp == null) {
        // Se não tivermos um impact start registado, criar um now e avisar
        _currentImpactTimestamp = DateTime.now().toIso8601String();
        print(
            '⚠️ IMPACT_DATA recebido sem IMPACT_START. Criando impact_timestamp: $_currentImpactTimestamp');
      }

      final sequenceNumber = int.parse(parts[1]);
      final isPreImpact = parts[2] == '1';

      // sampleTimestamp é millis do ESP — em vez de converter estranhamente,
      // usamos timestamp absoluto agora (DateTime.now()), mas guardamos também a millis original como meta se quiseres.
      final sampleTimestampMillis = int.tryParse(parts[3]) ?? 0;
      final sampleIso = DateTime.now().toIso8601String();

      final ax = double.parse(parts[4]);
      final ay = double.parse(parts[5]);
      final az = double.parse(parts[6]);
      final accelTotal = double.parse(parts[7]);
      final gx = double.parse(parts[8]);
      final gy = double.parse(parts[9]);
      final gz = double.parse(parts[10]);
      final gyroTotal = double.parse(parts[11]);

      // Armazenar no buffer (usar _currentImpactTimestamp ISO)
      _impactDataBuffer.add({
        'device_id': _deviceId,
        'impact_timestamp': _currentImpactTimestamp,
        'sample_timestamp': sampleIso,
        'sequence_number': sequenceNumber,
        'is_pre_impact': isPreImpact,
        'accel_x': ax,
        'accel_y': ay,
        'accel_z': az,
        'accel_total': accelTotal,
        'gyro_x': gx,
        'gyro_y': gy,
        'gyro_z': gz,
        'gyro_total': gyroTotal,
        // opcional: guardar o millis original para referência
        //'sample_millis': sampleTimestampMillis,
      });

      print(
          '📊 Buffered impact sample ${sequenceNumber + 1}/$_expectedSamples');
    } catch (e) {
      print('❌ Error handling impact data: $e');
    }
  }

  // Processar fim de evento de impacto - ENVIA PARA SUPABASE
  Future<void> _handleImpactEnd(String data) async {
    try {
      print(
          '✅ Impact event ended. Sending ${_impactDataBuffer.length} samples to Supabase...');

      if (_impactDataBuffer.isEmpty) {
        print('⚠️ Warning: No impact data to send');
        return;
      }

      // Inserir em lote e verificar resposta
      final response = await _supabase
          .from('impact_mode_data')
          .insert(_impactDataBuffer)
          .select();
      // O pacote supabase/supabase.dart normalmente retorna algo (lista) quando .select() é usado.
      if (response == null) {
        print('❌ Insert returned null response. Trying batch fallback.');
        await _sendImpactDataInBatches();
      } else {
        print(
            '🎉 Successfully sent ${_impactDataBuffer.length} impact samples to Supabase (response length: ${(response is List) ? response.length : 1})');
      }

      // Notificar a UI sobre o impacto
      _impactDetectedController.add(DateTime.now());

      // Limpar buffer
      _impactDataBuffer.clear();
      _currentImpactTimestamp = null;
      _expectedSamples = 0;
    } catch (e) {
      print('❌ Error handling impact end: $e');
      // Se houver erro, tentar enviar em batches
      await _sendImpactDataInBatches();
    }
  }

  // Fallback: enviar em lotes menores se der erro
  Future<void> _sendImpactDataInBatches() async {
    const batchSize = 10;

    for (int i = 0; i < _impactDataBuffer.length; i += batchSize) {
      try {
        final end = (i + batchSize < _impactDataBuffer.length)
            ? i + batchSize
            : _impactDataBuffer.length;

        final batch = _impactDataBuffer.sublist(i, end);
        final resp =
            await _supabase.from('impact_mode_data').insert(batch).select();

        if (resp == null) {
          print('❌ Batch ${i ~/ batchSize + 1} insert returned null.');
        } else {
          print(
              '✅ Sent batch ${i ~/ batchSize + 1} (${batch.length} samples). Response len: ${(resp is List) ? resp.length : 1}');
        }

        await Future.delayed(Duration(milliseconds: 100));
      } catch (e) {
        print('❌ Error sending batch ${i ~/ batchSize + 1}: $e');
      }
    }

    // Se tudo correr bem, limpar buffer
    _impactDataBuffer.clear();
    _currentImpactTimestamp = null;
    _expectedSamples = 0;
  }

  // Processar dados de modo contínuo
  Future<void> _handleContinuousData(String rawData) async {
    try {
      // Formato: A:ax,ay,az, At:at, G:gx,gy,gz, Gt:gt
      final RegExp regExp = RegExp(
        r'A:([\d.-]+),([\d.-]+),([\d.-]+),\s*At:([\d.]+),\s*G:([\d.-]+),([\d.-]+),([\d.-]+),\s*Gt:([\d.]+)',
      );
      final Match? match = regExp.firstMatch(rawData);

      if (match != null) {
        final double ax = double.parse(match.group(1)!);
        final double ay = double.parse(match.group(2)!);
        final double az = double.parse(match.group(3)!);
        final double accelTotal = double.parse(match.group(4)!);
        final double gx = double.parse(match.group(5)!);
        final double gy = double.parse(match.group(6)!);
        final double gz = double.parse(match.group(7)!);
        final double gyroTotal = double.parse(match.group(8)!);

        await _supabase.from('raw_sensor_data').insert({
          'device_id': _deviceId,
          'accel_x': ax,
          'accel_y': ay,
          'accel_z': az,
          'accel_total': accelTotal,
          'gyro_x': gx,
          'gyro_y': gy,
          'gyro_z': gz,
          'gyro_total': gyroTotal,
          'timestamp': DateTime.now().toIso8601String(),
        });

        print('✅ Sent continuous data to Supabase');
      }
    } catch (e) {
      print('❌ Error handling continuous data: $e');
    }
  }

  // Converter millis do ESP32 para DateTime
  String _convertMillisToDateTime(int millis) {
    final now = DateTime.now();
    // Usar timestamp relativo ao momento atual
    final timestamp = now.subtract(Duration(milliseconds: millis % 1000000));
    return timestamp.toIso8601String();
  }

  void resetImpactDisplay() {
    _impactDataDisplayed = false;
  }

  void dispose() {
    _pollingTimer?.cancel();
    _temperatureStreamController.close();
    _pressureStreamController.close();
    _accelTotalStreamController.close();
    _gyroTotalStreamController.close();
    _accelXStreamController.close();
    _accelYStreamController.close();
    _accelZStreamController.close();
    _gyroXStreamController.close();
    _gyroYStreamController.close();
    _gyroZStreamController.close();
    _impactDetectedController.close();
  }
}
