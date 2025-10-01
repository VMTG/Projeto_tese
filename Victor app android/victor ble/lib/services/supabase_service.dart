import 'dart:async';
import 'dart:math';
import 'package:supabase/supabase.dart';
import 'package:uuid/uuid.dart';
import 'package:Sensor/main.dart';

class SupabaseService {
  // Singleton pattern
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  // Supabase client
  late SupabaseClient _supabase;
  bool _initialized = false;
  bool get isInitialized => _initialized;

  // Device ID
  String _deviceId = '';
  String get deviceId => _deviceId;

  // Impact detection
  double _impactThreshold = 5.0;
  double get impactThreshold => _impactThreshold;
  DateTime? _lastImpactTime;
  DateTime? get lastImpactTime => _lastImpactTime;

  // Operation mode
  OperationMode _currentMode = OperationMode.continuous;
  OperationMode get currentMode => _currentMode;
  set currentMode(OperationMode mode) {
    _currentMode = mode;

    // Se o modo for neutro, podemos limpar os dados em cache ou parar de processar
    if (mode == OperationMode.neutral) {
      // Limpar os dados em cache
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
          // mode == OperationMode.neutral
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
    // Limpar todos os dados em cache
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

    // Também limpar os buffers de pré-impacto
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

    // Resetar flags
    _impactDataDisplayed = false;
    _lastImpactTime = null;
  }

  // Stream controllers para dados básicos do sensor
  final _temperatureStreamController =
      StreamController<List<SensorData>>.broadcast();
  final _pressureStreamController =
      StreamController<List<SensorData>>.broadcast();
  final _accelTotalStreamController =
      StreamController<List<SensorData>>.broadcast();
  final _gyroTotalStreamController =
      StreamController<List<SensorData>>.broadcast();

  // Stream controllers para dados de eixos individuais
  final _accelXStreamController =
      StreamController<List<SensorData>>.broadcast();
  final _accelYStreamController =
      StreamController<List<SensorData>>.broadcast();
  final _accelZStreamController =
      StreamController<List<SensorData>>.broadcast();
  final _gyroXStreamController = StreamController<List<SensorData>>.broadcast();
  final _gyroYStreamController = StreamController<List<SensorData>>.broadcast();
  final _gyroZStreamController = StreamController<List<SensorData>>.broadcast();

  // Stream controller para notificação de impacto
  final _impactDetectedController = StreamController<DateTime>.broadcast();

  // Getters para streams básicos
  Stream<List<SensorData>> get temperatureStream =>
      _temperatureStreamController.stream;
  Stream<List<SensorData>> get pressureStream =>
      _pressureStreamController.stream;
  Stream<List<SensorData>> get accelTotalStream =>
      _accelTotalStreamController.stream;
  Stream<List<SensorData>> get gyroTotalStream =>
      _gyroTotalStreamController.stream;

  // Getters para streams de eixos individuais
  Stream<List<SensorData>> get accelXStream => _accelXStreamController.stream;
  Stream<List<SensorData>> get accelYStream => _accelYStreamController.stream;
  Stream<List<SensorData>> get accelZStream => _accelZStreamController.stream;
  Stream<List<SensorData>> get gyroXStream => _gyroXStreamController.stream;
  Stream<List<SensorData>> get gyroYStream => _gyroYStreamController.stream;
  Stream<List<SensorData>> get gyroZStream => _gyroZStreamController.stream;

  // Getter para stream de impacto
  Stream<DateTime> get impactDetectedStream => _impactDetectedController.stream;

  // Timer para polling
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

  // Inicializar o serviço Supabase com as credenciais fornecidas
  Future<bool> initialize(String supabaseUrl, String supabaseKey) async {
    if (_initialized) return true;

    try {
      // Criar cliente Supabase
      _supabase = SupabaseClient(supabaseUrl, supabaseKey);

      // Testar conexão
      await testConnection();

      _initialized = true;

      // Gerar ID de dispositivo
      await _initializeDevice();

      // Configurar polling periódico
      _setupDataPolling();

      print('Supabase service initialized with device ID: $_deviceId');
      return true;
    } catch (e) {
      print('Error initializing Supabase service: $e');
      return false;
    }
  }

  // Testar conexão com o Supabase
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

  // Registrar ou recuperar ID do dispositivo
  Future<void> _initializeDevice() async {
    try {
      // Gerar novo ID de dispositivo
      final uuid = Uuid();
      _deviceId = uuid.v4();

      // Registrar dispositivo no Supabase
      await _supabase.from('devices').insert({
        'id': _deviceId,
        'name': 'ESP32_GY91',
        'operation_mode':
            _currentMode == OperationMode.continuous ? 'continuous' : 'impact',
        'impact_threshold': _impactThreshold,
      });

      print('Device registered with ID: $_deviceId');
    } catch (e) {
      print('Error initializing device: $e');
    }
  }

  // Atualizar threshold de impacto
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

  // Configurar polling periódico para simular Realtime
  void _setupDataPolling() {
    // Polling a cada 1 segundo
    _pollingTimer = Timer.periodic(Duration(milliseconds: 1000), (timer) {
      _pollSensorData();
    });
  }

  // Buscar dados periodicamente
  Future<void> _pollSensorData() async {
    if (!_initialized || _deviceId.isEmpty) return;

    try {
      // Se estiver em modo de impacto e não estiver mostrando dados de impacto,
      // apenas atualizar o buffer e verificar impactos
      if (_currentMode == OperationMode.impact && !_impactDataDisplayed) {
        await _checkForImpacts();
        return;
      }

      // Buscar últimos dados de sensores
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

  // Processar dados dos sensores obtidos do Supabase
  void _processSensorData(List<dynamic> data) {
    // Listas temporárias para armazenar os dados
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

    // Inverter a ordem para cronológica (mais antigo primeiro)
    data = data.reversed.toList();

    // Processar dados
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

        // Em modo contínuo ou quando mostrando dados de impacto, atualizar todos os buffers
        if (_currentMode == OperationMode.continuous || _impactDataDisplayed) {
          // Enviar dados para as streams
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
          // Em modo de impacto sem impacto detectado, atualizar buffer pré-impacto
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

  // Verificar impactos nos dados recentes
  Future<void> _checkForImpacts() async {
    if (_currentMode != OperationMode.impact) return;

    try {
      // Buscar dados mais recentes
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

          // Atualizar buffer pré-impacto
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

          // Verificar se aceleração total excede o threshold
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

  // Lidar com impacto detectado
  void _handleImpactDetected(DateTime impactTime) {
    _lastImpactTime = impactTime;
    _impactDataDisplayed = true;

    // Notificar sobre o impacto
    _impactDetectedController.add(impactTime);

    // Enviar dados do buffer pré-impacto para as streams
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

    // Configurar timer para resetar o modo de impacto após 10 segundos
    Timer(Duration(seconds: 10), () {
      _impactDataDisplayed = false;
    });
  }

  // Atualizar buffer pré-impacto
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
    // Adicionar aos buffers pré-impacto
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

    // Manter buffers no tamanho definido
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

  // Enviar dados brutos do sensor para o Supabase
  Future<void> sendSensorData(String rawData) async {
    if (!_initialized || _deviceId.isEmpty) return;

    try {
      // Analisar os dados brutos do sensor
      final RegExp regExp = RegExp(
        r'T:([\d.]+), P:([\d.]+), A:([\d.-]+),([\d.-]+),([\d.-]+), At:([\d.]+), G:([\d.-]+),([\d.-]+),([\d.-]+), Gt:([\d.]+)',
      );
      final Match? match = regExp.firstMatch(rawData);

      if (match != null) {
        final double temp = double.parse(match.group(1)!);
        final double pressure = double.parse(match.group(2)!);
        final double ax = double.parse(match.group(3)!);
        final double ay = double.parse(match.group(4)!);
        final double az = double.parse(match.group(5)!);
        final double accelTotal = double.parse(match.group(6)!);
        final double gx = double.parse(match.group(7)!);
        final double gy = double.parse(match.group(8)!);
        final double gz = double.parse(match.group(9)!);
        final double gyroTotal = double.parse(match.group(10)!);

        final DateTime now = DateTime.now();

        // Enviar dados para o Supabase
        await _supabase.from('raw_sensor_data').insert({
          'device_id': _deviceId,
          'temperature': temp,
          'pressure': pressure,
          'accel_x': ax,
          'accel_y': ay,
          'accel_z': az,
          'accel_total': accelTotal,
          'gyro_x': gx,
          'gyro_y': gy,
          'gyro_z': gz,
          'gyro_total': gyroTotal,
          'timestamp': now.toIso8601String(),
        });

        // Verificar impacto para modo de impacto
        if (_currentMode == OperationMode.impact &&
            accelTotal >= _impactThreshold &&
            !_impactDataDisplayed) {
          _handleImpactDetected(now);
        }
      }
    } catch (e) {
      print('Error sending data to Supabase: $e');
    }
  }

  // Limpar exibição de impacto
  void resetImpactDisplay() {
    _impactDataDisplayed = false;
  }

  // Limpar recursos
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
