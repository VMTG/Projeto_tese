// ******************************************************************************
// * BLUETOOTH SERVICE
// * Handles Bluetooth device scanning, connection and data processing
// ******************************************************************************
import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;
import 'package:flutter/material.dart';
import 'package:Sensor/services/supabase_service.dart'; // Adicione esta importação

// Callback typedefs for data processing (mantido para compatibilidade com código existente)
typedef DataProcessor = void Function(String data);

class BluetoothService {
  // Singleton pattern implementation
  static final BluetoothService _instance = BluetoothService._internal();

  factory BluetoothService() {
    return _instance;
  }

  BluetoothService._internal();

  // Bluetooth connection variables
  fbp.BluetoothCharacteristic? _characteristic;
  StreamSubscription<List<int>>? _valueSubscription;
  bool _isConnected = false;

  // Serviço Supabase
  final SupabaseService _supabaseService = SupabaseService();

  // Public getters
  bool get isConnected => _isConnected;

  // Start scanning for Bluetooth devices
  void startScan(
      {required String targetDeviceName,
      required Function(fbp.BluetoothDevice) onDeviceFound,
      required BuildContext context}) {
    fbp.FlutterBluePlus.startScan(timeout: const Duration(seconds: 4));
    fbp.FlutterBluePlus.scanResults.listen((results) {
      for (fbp.ScanResult result in results) {
        if (result.device.name == targetDeviceName) {
          onDeviceFound(result.device);
          break;
        }
      }
    });
  }

  // Connect to a specific Bluetooth device and set up service/characteristic
  Future<bool> connectToDevice(
      {required fbp.BluetoothDevice device,
      DataProcessor? dataProcessor, // Opcional agora
      required BuildContext context}) async {
    try {
      await device.connect();

      _isConnected = true;

      List<fbp.BluetoothService> services = await device.discoverServices();
      for (fbp.BluetoothService service in services) {
        if (service.uuid.toString() == "4fafc201-1fb5-459e-8fcc-c5c9c331914b") {
          for (fbp.BluetoothCharacteristic characteristic
              in service.characteristics) {
            if (characteristic.uuid.toString() ==
                "beb5483e-36e1-4688-b7f5-ea07361b26a8") {
              _characteristic = characteristic;
              await characteristic.setNotifyValue(true);
              _valueSubscription = characteristic.value.listen((value) {
                String rawData = ascii.decode(value);

                // Enviar dados para o Supabase
                _sendDataToSupabase(rawData);

                // Se um processador de dados foi fornecido, também o chame
                if (dataProcessor != null) {
                  dataProcessor(rawData);
                }
              });
              return true;
            }
          }
        }
      }

      // If we get here, we didn't find the expected service or characteristic
      _showErrorMessage(
          context, 'Required service or characteristic not found');
      return false;
    } catch (e) {
      _showErrorMessage(context, 'Error connecting to device: $e');
      _isConnected = false;
      return false;
    }
  }

  // Enviar dados para o Supabase
  void _sendDataToSupabase(String data) {
    try {
      _supabaseService.sendSensorData(data);
    } catch (e) {
      print('Error sending data to Supabase: $e');
    }
  }

  // Disconnect from the current device
  Future<void> disconnect() async {
    await _valueSubscription?.cancel();
    _valueSubscription = null;
    _characteristic = null;
    _isConnected = false;
  }

  // Clean up resources
  void dispose() {
    disconnect();
  }

  // Helper method to show error messages
  void _showErrorMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
}
