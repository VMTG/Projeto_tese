import 'dart:async';
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

  // Device ID
  String _deviceId = '';
  String get deviceId => _deviceId;

  // Operation mode
  OperationMode _currentMode = OperationMode.continuous;
  OperationMode get currentMode => _currentMode;
  set currentMode(OperationMode mode) {
    _currentMode = mode;
    if (_initialized && _deviceId.isNotEmpty) {
      try {
        _supabase.from('devices').update({
          'operation_mode':
              mode == OperationMode.continuous ? 'continuous' : 'impact'
        }).eq('id', _deviceId);
      } catch (e) {
        print('Error updating operation mode: $e');
      }
    }
  }

  // Stream controllers para dados do sensor
  final _temperatureStreamController =
      StreamController<List<SensorData>>.broadcast();
  final _pressureStreamController =
      StreamController<List<SensorData>>.broadcast();
  final _accelTotalStreamController =
      StreamController<List<SensorData>>.broadcast();
  final _gyroTotalStreamController =
      StreamController<List<SensorData>>.broadcast();

  // Getters para streams
  Stream<List<SensorData>> get temperatureStream =>
      _temperatureStreamController.stream;
  Stream<List<SensorData>> get pressureStream =>
      _pressureStreamController.stream;
  Stream<List<SensorData>> get accelTotalStream =>
      _accelTotalStreamController.stream;
  Stream<List<SensorData>> get gyroTotalStream =>
      _gyroTotalStreamController.stream;

  // Timer para polling
  Timer? _pollingTimer;

  // Variáveis para processamento de impacto
  String? _currentImpactTimestamp;
  int _expectedSamples = 0;
  List<Map<String, dynamic>> _impactDataBuffer = [];

  // Inicializar o serviço Supabase com as credenciais fornecidas
  Future<void> initialize(String supabaseUrl, String supabaseKey) async {
    if (_initialized) return;

    try {
      // Criar cliente Supabase
      _supabase = SupabaseClient(supabaseUrl, supabaseKey);
      _initialized = true;

      // Gerar ID de dispositivo
      await _initializeDevice();

      // Configurar polling periódico
      _setupDataPolling();

      print('Supabase service initialized with device ID: $_deviceId');
    } catch (e) {
      print('Error initializing Supabase service: $e');
    }
  }

  // Testar conexão com o Supabase
  Future<void> testConnection() async {
    if (!_initialized) {
      print('Supabase not initialized yet');
      return;
    }

    try {
      final response = await _supabase.from('devices').select().limit(1);
      print('Connection test successful: $response');
    } catch (e) {
      print('Connection test failed: $e');
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
            _currentMode == OperationMode.continuous ? 'continuous' : 'impact'
      });

      print('Device registered with ID: $_deviceId');
    } catch (e) {
      print('Error initializing device: $e');
    }
  }

  // Configurar polling periódico para simular Realtime
  void _setupDataPolling() {
    // Polling a cada 2 segundos
    _pollingTimer = Timer.periodic(Duration(seconds: 2), (timer) {
      _pollSensorData();
    });
  }

  // Buscar dados periodicamente
  Future<void> _pollSensorData() async {
    if (!_initialized || _deviceId.isEmpty) return;

    try {
      // Buscar dados de temperatura
      final tempData = await _supabase
          .from('processed_sensor_data')
          .select()
          .eq('device_id', _deviceId)
          .eq('data_type', 'temperature')
          .order('timestamp', ascending: false)
          .limit(50);

      if (tempData != null) {
        List<SensorData> sensorData = [];
        for (var item in tempData) {
          try {
            sensorData.add(SensorData(
                DateTime.parse(item['timestamp'] as String),
                (item['value'] as num).toDouble()));
          } catch (e) {
            print('Error parsing temperature data: $e');
          }
        }

        _temperatureStreamController.add(sensorData);
      }

      // Implemente o mesmo padrão para os outros tipos de dados...
    } catch (e) {
      print('Error during data polling: $e');
    }
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
          'timestamp': DateTime.now().toIso8601String(),
        });

        print('Sent sensor data to Supabase');
      }
    } catch (e) {
      print('Error sending data to Supabase: $e');
    }
  }

  // Limpar recursos
  void dispose() {
    _pollingTimer?.cancel();
    _temperatureStreamController.close();
    _pressureStreamController.close();
    _accelTotalStreamController.close();
    _gyroTotalStreamController.close();
  }
}
