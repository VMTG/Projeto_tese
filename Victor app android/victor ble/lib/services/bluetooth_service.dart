import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;
import 'package:flutter/material.dart';
import 'package:Sensor/services/supabase_service.dart';
import 'package:Sensor/main.dart';

typedef DataProcessor = void Function(String data);

class BluetoothService {
  static final BluetoothService _instance = BluetoothService._internal();
  factory BluetoothService() => _instance;
  BluetoothService._internal();

  fbp.BluetoothDevice? _device;
  List<fbp.BluetoothService> _services = [];
  fbp.BluetoothCharacteristic? _characteristic;
  fbp.BluetoothCharacteristic? _controlCharacteristic;
  StreamSubscription<List<int>>? _valueSubscription;
  bool _isConnected = false;
  bool _operationInProgress = false;

  final SupabaseService _supabaseService = SupabaseService();

  bool get isConnected => _isConnected;
  bool get isBusy => _operationInProgress;

  Future<void> startScan(
      {required String targetDeviceName,
      required Function(fbp.BluetoothDevice) onDeviceFound,
      required BuildContext context}) async {
    try {
      var state = await fbp.FlutterBluePlus.adapterState.first;
      if (state != fbp.BluetoothAdapterState.on) {
        _showErrorMessage(
            context, 'Por favor, ative o Bluetooth para continuar');
        return;
      }

      print("Iniciando scan por dispositivo: $targetDeviceName");
      await fbp.FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));

      StreamSubscription? scanSubscription;
      scanSubscription = fbp.FlutterBluePlus.scanResults.listen((results) {
        for (fbp.ScanResult result in results) {
          if (result.device.name == targetDeviceName) {
            print("Dispositivo encontrado: ${result.device.name}");
            scanSubscription?.cancel();
            onDeviceFound(result.device);
            break;
          }
        }
      }, onError: (e) {
        print("Erro no scan Bluetooth: $e");
        _showErrorMessage(context, 'Erro ao buscar dispositivos: $e');
      });

      Future.delayed(const Duration(seconds: 6), () {
        scanSubscription?.cancel();
        print("Timeout do scan - verificando se dispositivo foi encontrado");
      });
    } catch (e) {
      print("Erro ao iniciar scan Bluetooth: $e");
      _showErrorMessage(context, 'Erro ao iniciar busca por dispositivos: $e');
    }
  }

  Future<bool> connectToDevice(
      {required fbp.BluetoothDevice device,
      DataProcessor? dataProcessor,
      required BuildContext context}) async {
    if (_operationInProgress) {
      print("Operação de conexão já em andamento. Aguarde...");
      return false;
    }

    _operationInProgress = true;

    try {
      print("Conectando ao dispositivo: ${device.name}");

      if (_isConnected && _device?.id == device.id) {
        print("Já conectado ao dispositivo");
        _operationInProgress = false;
        return true;
      }

      if (_isConnected) {
        print(
            "Desconectando de dispositivo existente antes de conectar ao novo");
        await disconnect();
      }

      bool connected = false;
      try {
        await device.connect(timeout: const Duration(seconds: 15));
        connected = true;
      } catch (e) {
        print("Erro ao conectar: $e");
        try {
          connected = device.isConnected;
        } catch (_) {
          connected = false;
        }
      }

      if (!connected) {
        _showErrorMessage(context, 'Não foi possível conectar ao dispositivo');
        _operationInProgress = false;
        return false;
      }

      _device = device;
      _isConnected = true;
      print("Dispositivo conectado, descobrindo serviços...");

      int maxRetries = 3;
      for (int i = 0; i < maxRetries; i++) {
        try {
          _services = await device.discoverServices();
          break;
        } catch (e) {
          print("Erro ao descobrir serviços (tentativa ${i + 1}): $e");
          if (i == maxRetries - 1) {
            _showErrorMessage(context, 'Erro ao descobrir serviços Bluetooth');
            await device.disconnect();
            _isConnected = false;
            _operationInProgress = false;
            return false;
          }
          await Future.delayed(Duration(milliseconds: 500 * (i + 1)));
        }
      }

      print("Serviços descobertos: ${_services.length}");

      bool foundService = false;
      for (fbp.BluetoothService service in _services) {
        if (service.uuid.toString() == "4fafc201-1fb5-459e-8fcc-c5c9c331914b") {
          foundService = true;
          print("Serviço encontrado, configurando características...");

          for (fbp.BluetoothCharacteristic characteristic
              in service.characteristics) {
            if (characteristic.uuid.toString() ==
                "beb5483e-36e1-4688-b7f5-ea07361b26a8") {
              _characteristic = characteristic;
              print("Característica de dados encontrada");

              try {
                await characteristic.setNotifyValue(true);
                _valueSubscription?.cancel();
                _valueSubscription = characteristic.value.listen(
                  (value) {
                    try {
                      String rawData = ascii.decode(value);
                      print("BLE → $rawData");

                      // IMPORTANTE: Enviar TODOS os dados para o SupabaseService
                      // Ele vai processar IMPACT_START, IMPACT_DATA, IMPACT_END
                      _supabaseService.sendSensorData(rawData);

                      // Processar também com callback customizado se fornecido
                      if (dataProcessor != null) {
                        dataProcessor(rawData);
                      }
                    } catch (e) {
                      print("Erro ao processar dados recebidos: $e");
                    }
                  },
                  onError: (e) {
                    print("Erro na subscription do characteristic: $e");
                  },
                );
                print("Notificações configuradas");
              } catch (e) {
                print("Erro ao configurar notificações: $e");
              }
            } else if (characteristic.uuid.toString() ==
                "beb5483e-36e1-4688-b7f5-ea07361b26a9") {
              _controlCharacteristic = characteristic;
              print("Característica de controle encontrada");
            }
          }
        }
      }

      if (!foundService) {
        print("Serviço não encontrado");
        _showErrorMessage(
            context, 'Serviço Bluetooth necessário não encontrado');
        await device.disconnect();
        _isConnected = false;
        _operationInProgress = false;
        return false;
      }

      if (_characteristic == null || _controlCharacteristic == null) {
        print("Características necessárias não encontradas");
        _showErrorMessage(
            context, 'Características Bluetooth necessárias não encontradas');
        await device.disconnect();
        _isConnected = false;
        _operationInProgress = false;
        return false;
      }

      print("Dispositivo conectado e configurado com sucesso");
      _operationInProgress = false;
      return true;
    } catch (e) {
      print("Erro durante processo de conexão: $e");
      _showErrorMessage(context, 'Erro ao conectar ao dispositivo: $e');
      try {
        if (_device != null) {
          await _device!.disconnect();
        }
      } catch (_) {}
      _isConnected = false;
      _operationInProgress = false;
      return false;
    }
  }

  // Enviar comando de modo de impacto (modo 0)
  Future<bool> sendImpactModeRobust() async {
    if (!_isConnected || _controlCharacteristic == null) {
      print("Não conectado ou característica de controle não disponível");
      return false;
    }

    print("Configurando modo de impacto...");

    // Atualizar o SupabaseService também
    _supabaseService.currentMode = OperationMode.impact;

    bool success = false;
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        await _controlCharacteristic!.write(utf8.encode("0"));
        print("Tentativa $attempt: Comando de modo impacto enviado");

        await Future.delayed(Duration(milliseconds: 100));
        await _controlCharacteristic!.write(utf8.encode("0"));

        success = true;
        print("Modo impacto ativado com sucesso na tentativa $attempt");
        break;
      } catch (e) {
        print("Erro na tentativa $attempt: $e");
        await Future.delayed(Duration(milliseconds: 300 * attempt));
      }
    }

    return success;
  }

  // Enviar comando de modo contínuo (modo 1)
  Future<bool> sendContinuousModeRobust() async {
    if (!_isConnected || _controlCharacteristic == null) {
      print("Não conectado ou característica de controle não disponível");
      return false;
    }

    print("Configurando modo contínuo...");

    // Atualizar o SupabaseService também
    _supabaseService.currentMode = OperationMode.continuous;

    bool success = false;
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        await _controlCharacteristic!.write(utf8.encode("1"));
        print("Tentativa $attempt: Comando de modo contínuo enviado");

        await Future.delayed(Duration(milliseconds: 100));
        await _controlCharacteristic!.write(utf8.encode("1"));

        success = true;
        print("Modo contínuo ativado com sucesso na tentativa $attempt");
        break;
      } catch (e) {
        print("Erro na tentativa $attempt: $e");
        await Future.delayed(Duration(milliseconds: 300 * attempt));
      }
    }

    return success;
  }

  // Enviar comando de modo neutro (modo 2)
  Future<bool> sendNeutralModeRobust() async {
    if (!_isConnected || _controlCharacteristic == null) {
      print("Não conectado ou característica de controle não disponível");
      return false;
    }

    print("Configurando modo neutro...");

    // Atualizar o SupabaseService também
    _supabaseService.currentMode = OperationMode.neutral;

    bool success = false;
    for (int attempt = 1; attempt <= 5; attempt++) {
      try {
        if (attempt == 1) {
          await _controlCharacteristic!.write(utf8.encode("9"));
          print("Comando de parada enviado");
          await Future.delayed(Duration(milliseconds: 100));
        }

        await _controlCharacteristic!.write(utf8.encode("2"));
        print("Tentativa $attempt: Comando de modo neutro enviado");

        if (attempt < 3) {
          await Future.delayed(Duration(milliseconds: 100));
          await _controlCharacteristic!.write(utf8.encode("2"));
          print("Tentativa $attempt: Comando de modo neutro enviado (reforço)");
        }

        success = true;
        print("Modo neutro ativado com sucesso na tentativa $attempt");
        break;
      } catch (e) {
        print("Erro na tentativa $attempt: $e");
        int delayMs = 200 * attempt;
        await Future.delayed(Duration(milliseconds: delayMs));
      }
    }

    return success;
  }

  // Método simplificado para enviar comando de controle
  Future<bool> sendControlCommand(String command) async {
    if (!_isConnected || _controlCharacteristic == null) {
      print("Não conectado ou característica de controle não disponível");
      return false;
    }

    try {
      await _controlCharacteristic!.write(utf8.encode(command));
      await Future.delayed(Duration(milliseconds: 100));
      await _controlCharacteristic!.write(utf8.encode(command));

      print("Comando $command enviado com sucesso (2x)");
      return true;
    } catch (e) {
      print("Erro ao enviar comando: $e");

      try {
        await Future.delayed(Duration(milliseconds: 200));
        await _controlCharacteristic!.write(utf8.encode(command));
        print("Comando $command enviado na segunda tentativa");
        return true;
      } catch (e2) {
        print("Erro persistente ao enviar comando: $e2");
        return false;
      }
    }
  }

  // Parar o modo contínuo e mudar para modo neutro
  Future<bool> stopContinuousMode() async {
    if (!_isConnected || _controlCharacteristic == null) {
      print("Não conectado ou característica de controle não disponível");
      return false;
    }

    try {
      await _controlCharacteristic!.write(utf8.encode("9"));
      print("Comando de parada emergencial enviado");

      await Future.delayed(Duration(milliseconds: 150));

      await _controlCharacteristic!.write(utf8.encode("2"));
      print("Comando para modo neutro enviado");

      await Future.delayed(Duration(milliseconds: 100));
      await _controlCharacteristic!.write(utf8.encode("2"));
      print("Comando para modo neutro reenviado");

      // Atualizar SupabaseService
      _supabaseService.currentMode = OperationMode.neutral;

      return true;
    } catch (e) {
      print("Erro ao interromper modo contínuo: $e");

      try {
        await Future.delayed(Duration(milliseconds: 300));
        await _controlCharacteristic!.write(utf8.encode("2"));
        print("Modo neutro definido em tentativa de recuperação");
        _supabaseService.currentMode = OperationMode.neutral;
        return true;
      } catch (e2) {
        print("Erro persistente: $e2");
        return false;
      }
    }
  }

  // Configurar modo neutro
  Future<bool> setNeutralMode() async {
    if (!_isConnected || _controlCharacteristic == null) {
      print("Não conectado ou característica de controle não disponível");
      return false;
    }

    try {
      await _controlCharacteristic!.write(utf8.encode("2"));
      await Future.delayed(Duration(milliseconds: 100));
      await _controlCharacteristic!.write(utf8.encode("2"));

      print("Comando para modo neutro enviado com sucesso (2x)");
      _supabaseService.currentMode = OperationMode.neutral;
      return true;
    } catch (e) {
      print("Erro ao definir modo neutro: $e");
      return false;
    }
  }

  // Enviar comando sem esperar resposta
  Future<void> sendCommandNoWait(String command) async {
    if (!_isConnected || _controlCharacteristic == null) {
      print("Não conectado ou característica de controle não disponível");
      return;
    }

    try {
      _controlCharacteristic!.write(utf8.encode(command));
      print("Comando $command enviado (sem aguardar)");
    } catch (e) {
      print("Erro ao enviar comando sem aguardar: $e");
    }
  }

  // Desconectar do dispositivo atual
  Future<void> disconnect({bool keepConnection = false}) async {
    if (_operationInProgress) {
      print("Operação em andamento. Não é possível desconectar agora.");
      return;
    }

    _operationInProgress = true;

    if (!keepConnection && _device != null) {
      try {
        if (_isConnected && _controlCharacteristic != null) {
          try {
            await _controlCharacteristic!.write(utf8.encode("2"));
            print("Modo neutro definido antes de desconectar");
            _supabaseService.currentMode = OperationMode.neutral;
          } catch (e) {
            print("Erro ao definir modo neutro antes de desconectar: $e");
          }
        }

        await _valueSubscription?.cancel();
        _valueSubscription = null;

        print("Desconectando do dispositivo...");
        await _device!.disconnect();
        print("Dispositivo desconectado");

        _characteristic = null;
        _controlCharacteristic = null;
        _isConnected = false;
      } catch (e) {
        print("Erro ao desconectar: $e");
      }
    } else if (keepConnection) {
      print("Mantendo conexão Bluetooth ativa conforme solicitado");
    }

    _operationInProgress = false;
  }

  void dispose({bool keepConnection = false}) {
    if (!keepConnection) {
      disconnect();
    } else {
      print("Recursos Bluetooth mantidos ativos");
    }
  }

  void _showErrorMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
}
