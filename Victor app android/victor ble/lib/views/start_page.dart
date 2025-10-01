import 'package:flutter/material.dart';
import 'package:Sensor/services/bluetooth_service.dart';
import 'package:Sensor/main.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;

import 'device_screen.dart';

// ******************************************************************************
// * NOVA PÁGINA INICIAL COM CONEXÃO BLUETOOTH E BOTÕES DE MODO
// ******************************************************************************
class StartPage extends StatefulWidget {
  const StartPage({super.key});

  @override
  State<StartPage> createState() => _StartPageState();
}

class _StartPageState extends State<StartPage> {
  final BluetoothService _bluetoothService = BluetoothService();
  bool _isConnecting = false;
  bool _isConnected = false;
  String _connectionStatus = 'Não conectado';

  @override
  void initState() {
    super.initState();

    // Verificar se já estamos conectados
    _checkConnectionStatus();
  }

// Método para verificar o status da conexão Bluetooth e atualizar a UI
  void _checkConnectionStatus() {
    if (_bluetoothService.isConnected) {
      print("Conexão Bluetooth estabelecida. Definindo modo neutro...");

      // Atualizar a UI imediatamente para mostrar conectado
      setState(() {
        _isConnected = true;
        _isConnecting = false;
        _connectionStatus = 'Conectado! Selecione um modo de operação.';
      });

      // Tentar definir o modo neutro em segundo plano, sem afetar a UI
      Future.microtask(() async {
        try {
          // Primeiro tentar a parada emergencial para o modo contínuo
          await _bluetoothService.stopContinuousMode();
          print("Parada emergencial executada com sucesso");
        } catch (e) {
          print("Erro na parada emergencial: $e");
          // Mesmo com erro, continuar para tentar o modo neutro normal
        }

        // Aguardar um momento para estabilizar
        await Future.delayed(Duration(milliseconds: 300));

        // Agora tentar definir o modo neutro
        bool success = await _bluetoothService.setNeutralMode();

        if (!success) {
          print("Falha ao definir modo neutro - tentando novamente após delay");
          // Tentar novamente após um delay mais longo
          await Future.delayed(Duration(milliseconds: 500));
          await _bluetoothService.setNeutralMode();
        }
      });
    } else {
      print("Sem conexão Bluetooth. Iniciando escaneamento...");
      _startBluetoothConnection();
    }
  }

  // Iniciar procura de dispositivos Bluetooth
  void _startBluetoothConnection() {
    setState(() {
      _isConnecting = true;
      _connectionStatus = 'Procurando dispositivo...';
    });

    _bluetoothService.startScan(
      targetDeviceName: "ESP32_GY91",
      onDeviceFound: (device) {
        _connectToDevice(device);
      },
      context: context,
    );

    // Timeout para caso não encontre o dispositivo
    Future.delayed(Duration(seconds: 5), () {
      if (_isConnecting && !_isConnected) {
        setState(() {
          _isConnecting = false;
          _connectionStatus = 'Dispositivo não encontrado';
        });
      }
    });
  }

  // Conectar ao dispositivo encontrado
  void _connectToDevice(fbp.BluetoothDevice device) {
    setState(() {
      _connectionStatus = 'Conectando ao ESP32_GY91...';
    });

    _bluetoothService
        .connectToDevice(
      device: device,
      context: context,
    )
        .then((success) async {
      if (success) {
        try {
          // Definir explicitamente o modo neutro após a conexão
          await _bluetoothService.setNeutralMode();

          setState(() {
            _isConnecting = false;
            _isConnected = true;
            _connectionStatus = 'Conectado! Selecione um modo de operação.';
          });
        } catch (e) {
          print("Erro ao definir modo neutro: $e");
          setState(() {
            _isConnecting = false;
            _isConnected = true; // Ainda está conectado, mesmo com erro
            _connectionStatus = 'Conectado, mas erro ao definir modo neutro.';
          });
        }
      } else {
        setState(() {
          _isConnecting = false;
          _isConnected = false;
          _connectionStatus = 'Falha na conexão';
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sensor App'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo ou ícone
            const Icon(
              Icons.sensors,
              size: 100,
              color: Colors.blue,
            ),
            const SizedBox(height: 20),

            // Application title
            const Text(
              'Sensor Data Visualizer',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),

            // Application description
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'View real-time sensor data through interactive graphs',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            ),
            const SizedBox(height: 30),

            // Status da conexão
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color:
                    _isConnected ? Colors.green.shade100 : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isConnected
                        ? Icons.bluetooth_connected
                        : Icons.bluetooth_searching,
                    color: _isConnected ? Colors.green : Colors.grey,
                  ),
                  SizedBox(width: 10),
                  Text(
                    _connectionStatus,
                    style: TextStyle(
                      color: _isConnected
                          ? Colors.green.shade800
                          : Colors.grey.shade700,
                    ),
                  ),
                  if (_isConnecting)
                    Padding(
                      padding: EdgeInsets.only(left: 10),
                      child: SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                ],
              ),
            ),

            SizedBox(height: 10),

            // Botão de reconexão
            if (!_isConnected && !_isConnecting)
              ElevatedButton(
                onPressed: _startBluetoothConnection,
                child: Text('Tentar novamente'),
              ),

            const SizedBox(height: 40),

            // Operation modes section
            const Text(
              'Select operating mode:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),

            // Continuous mode button
            ElevatedButton.icon(
              icon: const Icon(Icons.play_circle_outline),
              label: const Text(
                'Continuous Mode',
                style: TextStyle(
                  fontSize: 18,
                ),
              ),
              onPressed: _isConnected
                  ? () {
                      // Enviar comando para o modo contínuo e navegar imediatamente
                      // para reduzir a percepção de latência
                      _bluetoothService.sendControlCommand("1");

                      // Navegar para a tela do dispositivo imediatamente
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (context) => DeviceScreen(
                            mode: OperationMode.continuous,
                          ),
                        ),
                      );
                    }
                  : null, // Desabilita o botão se não estiver conectado
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                minimumSize: const Size(240, 50),
              ),
            ),

            const SizedBox(height: 20),

            // Impact mode button
            ElevatedButton.icon(
              icon: const Icon(Icons.flash_on),
              label: const Text(
                'Impact Mode',
                style: TextStyle(
                  fontSize: 18,
                ),
              ),
              onPressed: _isConnected
                  ? () async {
                      // Mostrar indicador de progresso
                      setState(() {
                        _connectionStatus = 'Mudando para modo de impacto...';
                      });

                      // Enviar comando para o modo de impacto
                      bool success =
                          await _bluetoothService.sendControlCommand("0");

                      if (success) {
                        // Navegar para a tela do dispositivo no modo de impacto
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (context) => DeviceScreen(
                              mode: OperationMode.impact,
                            ),
                          ),
                        );
                      } else {
                        // Mostrar erro e oferecer nova tentativa
                        setState(() {
                          _connectionStatus =
                              'Falha ao mudar para modo de impacto';
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content:
                                const Text('Falha ao enviar comando de modo'),
                            backgroundColor: Colors.red,
                            action: SnackBarAction(
                              label: 'Tentar Novamente',
                              onPressed: () =>
                                  _bluetoothService.sendControlCommand("0"),
                            ),
                          ),
                        );
                      }
                    }
                  : null, // Desabilita o botão se não estiver conectado
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                minimumSize: const Size(240, 50),
                backgroundColor: Colors.orange,
              ),
            ),

            // Application version
            const SizedBox(height: 40),
            const Text(
              'Versão 1.0.0',
              style: TextStyle(
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
