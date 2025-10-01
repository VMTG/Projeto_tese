// ******************************************************************************
// * IMPORTS SECTION
// ******************************************************************************
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For SystemNavigator.pop()
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart'; // For resetting the app

import 'detailed_graphs_page.dart';
import 'start_page.dart';
import 'package:Sensor/main.dart';
import 'package:Sensor/services/bluetooth_service.dart';
import 'package:Sensor/services/supabase_service.dart';
import 'package:Sensor/theme/app_theme.dart';

// ******************************************************************************
// * MAIN DEVICE SCREEN
// * Handles primary sensor data display
// ******************************************************************************
class DeviceScreen extends StatefulWidget {
  final OperationMode mode;

  const DeviceScreen({
    super.key,
    required this.mode,
  });

  @override
  State<DeviceScreen> createState() => _DeviceScreenState();
}

class _DeviceScreenState extends State<DeviceScreen>
    with WidgetsBindingObserver {
  // ----------------------
  // Basic sensor data storage
  // ----------------------
  final List<SensorData> _temperatureData = [];
  final List<SensorData> _pressureData = [];
  final List<SensorData> _accelTotalData = [];
  final List<SensorData> _gyroTotalData = [];

  // ----------------------
  // Individual axis sensor data storage
  // ----------------------
  final List<SensorData> _accelXData = [];
  final List<SensorData> _accelYData = [];
  final List<SensorData> _accelZData = [];
  final List<SensorData> _gyroXData = [];
  final List<SensorData> _gyroYData = [];
  final List<SensorData> _gyroZData = [];

  // ----------------------
  // Subscriptions para os streams do Supabase
  // ----------------------
  List<StreamSubscription> _subscriptions = [];

  // ----------------------
  // Services
  // ----------------------
  final BluetoothService _bluetoothService = BluetoothService();
  final SupabaseService _supabaseService = SupabaseService();

  // ----------------------
  // Impact detection variables
  // ----------------------
  bool _impactDetected = false;
  DateTime? _lastImpactTime;

  // ----------------------
  // Interface state management
  // ----------------------
  bool _isInitialized = false;
  bool _isLoading = true;
  String _statusMessage = "Inicializando...";
  bool _isReconnecting = false;

  // ******************************************************************************
  // * LIFECYCLE METHODS
  // ******************************************************************************
  @override
  void initState() {
    super.initState();

    // Registrar este widget como observador do app lifecycle
    WidgetsBinding.instance.addObserver(this);

    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    setState(() {
      _isLoading = true;
      _statusMessage = "Verificando conexão...";
    });

    // Verificar se já estamos conectados
    if (_bluetoothService.isConnected) {
      try {
        // Atualizar modo de operação no Supabase
        _supabaseService.currentMode = widget.mode;

        setState(() {
          _statusMessage = "Configurando modo...";
        });

        // Usar os métodos robustos para enviar o comando apropriado
        bool commandSuccess = false;
        if (widget.mode == OperationMode.continuous) {
          commandSuccess = await _bluetoothService.sendContinuousModeRobust();
          print("Modo contínuo " + (commandSuccess ? "ativado" : "falhou"));
        } else if (widget.mode == OperationMode.impact) {
          commandSuccess = await _bluetoothService.sendImpactModeRobust();
          print("Modo de impacto " + (commandSuccess ? "ativado" : "falhou"));
        } else {
          // Modo neutro ou fallback
          commandSuccess = await _bluetoothService.sendNeutralModeRobust();
          print("Modo neutro " + (commandSuccess ? "ativado" : "falhou"));
        }

        if (!commandSuccess) {
          print("ALERTA: Falha ao configurar modo no ESP32");
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Falha ao configurar modo, tentando novamente...'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );

          // Tentar novamente com método simples
          await _bluetoothService
              .sendControlCommand(widget.mode == OperationMode.continuous
                  ? "1"
                  : widget.mode == OperationMode.impact
                      ? "0"
                      : "2");
        }

        // Inicializar streams para dados
        setState(() {
          _statusMessage = "Configurando streams de dados...";
        });

        await _setupStreams();

        setState(() {
          _isLoading = false;
          _isInitialized = true;
        });
      } catch (e) {
        print("Erro durante inicialização: $e");
        setState(() {
          _statusMessage = "Erro ao inicializar: $e";
          _isLoading = false;
        });
      }
    } else {
      print("ALERTA: Bluetooth não conectado ao iniciar DeviceScreen");
      setState(() {
        _statusMessage = "Sem conexão Bluetooth";
        _isLoading = false;
      });
    }
  }

  Future<void> _setupStreams() async {
    // Streams principais (mais importantes para UI)
    _subscriptions.add(_supabaseService.temperatureStream.listen((data) {
      if (mounted) {
        setState(() {
          _temperatureData.clear();
          _temperatureData.addAll(data);
        });
      }
    }));

    _subscriptions.add(_supabaseService.accelTotalStream.listen((data) {
      if (mounted) {
        setState(() {
          _accelTotalData.clear();
          _accelTotalData.addAll(data);
        });
      }
    }));

    // Pequeno delay antes de configurar os streams secundários
    await Future.delayed(Duration(milliseconds: 100));
    if (!mounted) return;

    // Streams secundários
    _subscriptions.add(_supabaseService.pressureStream.listen((data) {
      if (mounted) {
        setState(() {
          _pressureData.clear();
          _pressureData.addAll(data);
        });
      }
    }));

    _subscriptions.add(_supabaseService.gyroTotalStream.listen((data) {
      if (mounted) {
        setState(() {
          _gyroTotalData.clear();
          _gyroTotalData.addAll(data);
        });
      }
    }));

    // Streams de eixos individuais
    _subscriptions.add(_supabaseService.accelXStream.listen((data) {
      if (mounted) {
        setState(() {
          _accelXData.clear();
          _accelXData.addAll(data);
        });
      }
    }));

    _subscriptions.add(_supabaseService.accelYStream.listen((data) {
      if (mounted) {
        setState(() {
          _accelYData.clear();
          _accelYData.addAll(data);
        });
      }
    }));

    _subscriptions.add(_supabaseService.accelZStream.listen((data) {
      if (mounted) {
        setState(() {
          _accelZData.clear();
          _accelZData.addAll(data);
        });
      }
    }));

    _subscriptions.add(_supabaseService.gyroXStream.listen((data) {
      if (mounted) {
        setState(() {
          _gyroXData.clear();
          _gyroXData.addAll(data);
        });
      }
    }));

    _subscriptions.add(_supabaseService.gyroYStream.listen((data) {
      if (mounted) {
        setState(() {
          _gyroYData.clear();
          _gyroYData.addAll(data);
        });
      }
    }));

    _subscriptions.add(_supabaseService.gyroZStream.listen((data) {
      if (mounted) {
        setState(() {
          _gyroZData.clear();
          _gyroZData.addAll(data);
        });
      }
    }));

    // Stream de impacto
    _subscriptions
        .add(_supabaseService.impactDetectedStream.listen((timestamp) {
      if (mounted) {
        setState(() {
          _impactDetected = true;
          _lastImpactTime = timestamp;

          // Resetar após 5 segundos
          Timer(Duration(seconds: 5), () {
            if (mounted) {
              setState(() {
                _impactDetected = false;
              });
            }
          });
        });
      }
    }));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Reagir a mudanças de estado do app lifecycle
    print("App lifecycle state changed to: $state");

    switch (state) {
      case AppLifecycleState.resumed:
        // App voltou ao primeiro plano - verificar conexão
        if (!_bluetoothService.isConnected) {
          print("Conexão perdida durante pausa do app. Tentando reconectar...");
          _handleConnectionLoss();
        } else {
          print("App retomado com conexão Bluetooth intacta");
          // Reenviar modo atual para garantir sincronia
          _resendCurrentMode();
        }
        break;
      case AppLifecycleState.paused:
        // App foi para segundo plano
        print("App em segundo plano, marcando estado");
        break;
      default:
        break;
    }
  }

  @override
  void dispose() {
    // Remover este widget como observador
    WidgetsBinding.instance.removeObserver(this);

    // Cancelar todas as assinaturas de streams
    for (var subscription in _subscriptions) {
      subscription.cancel();
    }

    // Não desconectar o bluetooth para manter a conexão entre telas
    super.dispose();
  }

  // Reenviar comando de modo atual para garantir sincronia
  Future<void> _resendCurrentMode() async {
    if (!_bluetoothService.isConnected) return;

    try {
      String command = "2"; // Default: neutro

      if (widget.mode == OperationMode.continuous) {
        command = "1";
      } else if (widget.mode == OperationMode.impact) {
        command = "0";
      }

      await _bluetoothService.sendControlCommand(command);
      print("Modo $command reenviado após retomada do app");
    } catch (e) {
      print("Erro ao reenviar modo: $e");
    }
  }

  // ******************************************************************************
  // * BLUETOOTH CONNECTION METHODS
  // ******************************************************************************
  void _handleConnectionLoss() {
    if (_isReconnecting) return;

    setState(() {
      _isReconnecting = true;
    });

    // Tentar fazer scan e reconectar
    _startBluetoothConnection();
  }

  void _startBluetoothConnection() {
    setState(() {
      _statusMessage = "Procurando dispositivo...";
    });

    _bluetoothService
        .startScan(
      targetDeviceName: "ESP32_GY91",
      onDeviceFound: (device) {
        _connectToDevice(device);
      },
      context: context,
    )
        .then((_) {
      // Scan concluído sem encontrar dispositivo
      if (!_bluetoothService.isConnected && _isReconnecting) {
        setState(() {
          _statusMessage = "Dispositivo não encontrado";
          _isReconnecting = false;
        });
      }
    });

    // Timeout para caso não encontre o dispositivo
    Future.delayed(Duration(seconds: 6), () {
      if (!_bluetoothService.isConnected && _isReconnecting) {
        setState(() {
          _statusMessage = "Tempo esgotado na busca";
          _isReconnecting = false;
        });
      }
    });
  }

  void _connectToDevice(fbp.BluetoothDevice device) {
    setState(() {
      _statusMessage = "Conectando ao dispositivo...";
    });

    _bluetoothService
        .connectToDevice(
      device: device,
      context: context,
    )
        .then((success) async {
      if (success) {
        setState(() {
          _statusMessage = "Configurando modo...";
        });

        // Enviar comando com base no modo selecionado
        String command;
        if (widget.mode == OperationMode.continuous) {
          command = "1";
          await _bluetoothService.sendContinuousModeRobust();
        } else if (widget.mode == OperationMode.impact) {
          command = "0";
          await _bluetoothService.sendImpactModeRobust();
        } else {
          command = "2";
          await _bluetoothService.setNeutralMode();
        }

        // Configurar streams se necessário
        if (!_isInitialized) {
          await _setupStreams();
        }

        setState(() {
          _isReconnecting = false;
          _isInitialized = true;
        });
      } else {
        setState(() {
          _statusMessage = "Falha ao conectar";
          _isReconnecting = false;
        });
      }
    });
  }

  // ******************************************************************************
  // * UI BUILDING METHODS
  // ******************************************************************************
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await _safelyReturnToStartPage();
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.mode == OperationMode.continuous
              ? 'Continuous Mode'
              : 'Impact Mode'),
          actions: [
            // Current mode indicator
            Chip(
              backgroundColor: widget.mode == OperationMode.continuous
                  ? Colors.blue
                  : Colors.orange,
              label: Text(
                widget.mode == OperationMode.continuous
                    ? 'Continuous'
                    : 'Impact',
                style: const TextStyle(color: Colors.white),
              ),
            ),
            const SizedBox(width: 8),

            // Reset app button using flutter_phoenix
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Reset App',
              onPressed: () {
                _sendNeutralBeforeAction(() {
                  Phoenix.rebirth(context);
                });
              },
            ),

            // Navigate to detailed graphs page
            IconButton(
              icon: const Icon(Icons.graphic_eq),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DetailedGraphsPage(
                      mode: widget.mode,
                      impactThreshold: _supabaseService.impactThreshold,
                      accelXData: _accelXData,
                      accelYData: _accelYData,
                      accelZData: _accelZData,
                      accelTotalData: _accelTotalData,
                      gyroXData: _gyroXData,
                      gyroYData: _gyroYData,
                      gyroZData: _gyroZData,
                      gyroTotalData: _gyroTotalData,
                    ),
                  ),
                );
              },
              tooltip: 'View Detailed Graphs',
            ),

            // Close app button
            IconButton(
              icon: const Icon(Icons.exit_to_app),
              tooltip: 'Close App',
              onPressed: () {
                _sendNeutralBeforeAction(() {
                  SystemNavigator.pop();
                });
              },
            ),
          ],
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    // Verificar se estamos em estado de carregamento ou erro
    if (_isLoading) {
      return _buildLoadingView();
    }

    // Verificar se temos conexão Bluetooth
    if (!_bluetoothService.isConnected) {
      return _buildConnectionView();
    }

    // Tela normal de dados
    return _buildConnectedView();
  }

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 20),
          Text(
            _statusMessage,
            style: TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }

  // View when connecting to device
  Widget _buildConnectionView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Mostrar progresso se estiver tentando reconectar
          if (_isReconnecting)
            CircularProgressIndicator()
          else
            Icon(
              Icons.bluetooth_disabled,
              size: 60,
              color: Colors.grey,
            ),
          SizedBox(height: 20),
          Text(
            _isReconnecting ? _statusMessage : 'Conexão Bluetooth perdida',
            style: TextStyle(fontSize: 16),
          ),
          SizedBox(height: 40),
          ElevatedButton(
            onPressed: _isReconnecting ? null : _handleConnectionLoss,
            child: Text('Tentar reconectar'),
          ),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed:
                _isReconnecting ? null : () => _safelyReturnToStartPage(),
            child: Text('Voltar para a página inicial'),
          ),
        ],
      ),
    );
  }

  // View when connected to device
  Widget _buildConnectedView() {
    // Mostrar os gráficos imediatamente, independente da existência de dados
    return SingleChildScrollView(
      child: Column(
        children: [
          // Mode info banner
          Container(
            decoration: AppTheme.cardDecoration,
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(
                  widget.mode == OperationMode.continuous
                      ? Icons.play_circle_outline
                      : Icons.flash_on,
                  color: widget.mode == OperationMode.continuous
                      ? Colors.blue
                      : Colors.orange,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.mode == OperationMode.continuous
                        ? 'Data is displayed continuously'
                        : 'Data is only displayed when an impact is detected (Threshold: ${_supabaseService.impactThreshold} g)',
                    style: TextStyle(
                      color: widget.mode == OperationMode.continuous
                          ? Colors.blue.shade800
                          : Colors.orange.shade800,
                    ),
                  ),
                ),
                if (widget.mode == OperationMode.impact && _impactDetected)
                  const Chip(
                    backgroundColor: Colors.red,
                    label: Text(
                      'IMPACT!',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Sempre criar gráficos, mesmo sem dados
          _buildChart('Temperature (°C)', _temperatureData),
          _buildChart('Pressure (hPa)', _pressureData),
          _buildChart(
            'Acceleration Total (g)',
            _accelTotalData,
            additionalAnnotation:
                _buildThresholdAnnotation(_supabaseService.impactThreshold),
          ),
          _buildChart('Gyro Total (dps)', _gyroTotalData),

          // Change mode button
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.swap_horiz),
              label: const Text(
                'Change Mode',
                style: TextStyle(
                  fontSize: 18,
                ),
              ),
              onPressed: _safelyReturnToStartPage,
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to build a simple chart widget
  Widget _buildChart(String title, List<SensorData> data,
      {CartesianChartAnnotation? additionalAnnotation}) {
    // Criar lista vazia de dados se necessário
    final List<SensorData> displayData = data.isEmpty
        ? [
            SensorData(DateTime.now(), 0)
          ] // Dado fictício para inicializar o gráfico
        : data;

    return SizedBox(
      height: 200,
      child: SfCartesianChart(
        title: ChartTitle(text: title),
        annotations: additionalAnnotation != null
            ? <CartesianChartAnnotation>[additionalAnnotation]
            : null,
        series: <LineSeries<SensorData, DateTime>>[
          LineSeries<SensorData, DateTime>(
            dataSource: displayData,
            xValueMapper: (SensorData data, _) => data.time,
            yValueMapper: (SensorData data, _) => data.value,
            // Desativar animação para melhor desempenho
            animationDuration: 0,
            // Mostrar marcadores apenas quando há dados reais
            markerSettings: MarkerSettings(
              isVisible: data.isNotEmpty,
              shape: DataMarkerType.circle,
              width: 6,
              height: 6,
            ),
          ),
        ],
        primaryXAxis: DateTimeAxis(
          intervalType: DateTimeIntervalType.seconds,
          interval: 2,
          autoScrollingDelta: 50,
          autoScrollingDeltaType: DateTimeIntervalType.seconds,
          // Definir um intervalo inicial para gráficos vazios
          minimum: data.isEmpty
              ? DateTime.now().subtract(Duration(minutes: 1))
              : null,
          maximum: data.isEmpty ? DateTime.now() : null,
        ),
        primaryYAxis: NumericAxis(
          enableAutoIntervalOnZooming: true,
          // Definir um intervalo padrão para gráficos vazios
          minimum: data.isEmpty ? -1 : null,
          maximum: data.isEmpty ? 1 : null,
        ),
        zoomPanBehavior: ZoomPanBehavior(
          enablePanning: true,
          enablePinching: true,
        ),
      ),
    );
  }

  // Create a threshold annotation for impact detection visualization
  CartesianChartAnnotation _buildThresholdAnnotation(double threshold) {
    return CartesianChartAnnotation(
      widget: Container(
        child: Text(
          'Threshold: $threshold',
          style: const TextStyle(color: Colors.red),
        ),
      ),
      coordinateUnit: CoordinateUnit.point,
      x: DateTime.now(),
      y: threshold,
    );
  }

  // Método seguro para retornar à página inicial
  Future<void> _safelyReturnToStartPage() async {
    // Impedir múltiplas chamadas simultâneas
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _statusMessage = "Finalizando modo...";
    });

    // Mostrar feedback visual rápido
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Voltando para página inicial...'),
        duration: Duration(milliseconds: 500),
      ),
    );

    // Tratar diferentemente dependendo do modo atual
    if (widget.mode == OperationMode.continuous) {
      // Para modo contínuo, é crucial parar o streaming primeiro
      try {
        await _bluetoothService.stopContinuousMode();
      } catch (e) {
        print("Erro ao parar modo contínuo: $e");
        // Tentar método alternativo
        await _bluetoothService.sendNeutralModeRobust();
      }
    } else {
      // Para outros modos, simplesmente definir modo neutro
      await _bluetoothService.setNeutralMode();
    }

    // Atualizar o Supabase
    _supabaseService.currentMode = OperationMode.neutral;

    // Navegar para a página inicial
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => const StartPage(),
        ),
        (Route<dynamic> route) => false,
      );
    }
  }

  // Enviar comando neutro antes de executar uma ação
  Future<void> _sendNeutralBeforeAction(VoidCallback action) async {
    if (_bluetoothService.isConnected) {
      // Para modo contínuo, usar modo stop + neutro
      if (widget.mode == OperationMode.continuous) {
        _bluetoothService.stopContinuousMode().then((_) {
          action();
        });
      } else {
        // Para outros modos, apenas neutro
        _bluetoothService.setNeutralMode().then((_) {
          action();
        });
      }
    } else {
      // Se não estiver conectado, apenas executar a ação
      action();
    }
  }
}
