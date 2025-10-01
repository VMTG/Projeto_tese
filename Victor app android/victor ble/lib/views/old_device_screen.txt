// ******************************************************************************
// * IMPORTS SECTION
// ******************************************************************************
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For SystemNavigator.pop()
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart'; // For resetting the app

import 'detailed_graphs_page.dart';
import 'start_page.dart';
import 'package:Sensor/main.dart';
import 'package:Sensor/services/bluetooth_service.dart'; // Import the new Bluetooth service
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

class _DeviceScreenState extends State<DeviceScreen> {
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
  // Configuration parameters
  // ----------------------
  final double _impactThreshold = 5.0; // Threshold for impact detection (in g)

  // ----------------------
  // Impact detection variables
  // ----------------------
  bool _impactDetected = false;
  DateTime? _lastImpactTime;

  // ----------------------
  // Bluetooth service
  // ----------------------
  final BluetoothService _bluetoothService = BluetoothService();

  // Add these variables to the _DeviceScreenState class
  final int _bufferSize = 50; // Size of pre-impact data buffer
  final List<SensorData> _preImpactBuffer =
      []; // Buffer lists for each sensor type
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

  bool _impactDataDisplayed =
      false; // Flag to track if impact data is being displayed

  // ******************************************************************************
  // * LIFECYCLE METHODS
  // ******************************************************************************
  @override
  void initState() {
    super.initState();

    // Start with empty charts if in impact mode
    if (widget.mode == OperationMode.impact) {
      _clearSensorData();
      _impactDataDisplayed = false;
    }

    // Start scanning for Bluetooth devices with the service
    _startBluetoothConnection();
  }

  @override
  void dispose() {
    _bluetoothService.dispose(); // Clean up Bluetooth resources
    super.dispose();
  }

  // ******************************************************************************
  // * BLUETOOTH CONNECTION METHODS
  // ******************************************************************************
  void _startBluetoothConnection() {
    _bluetoothService.startScan(
      targetDeviceName: "ESP32_GY91",
      onDeviceFound: (device) {
        _connectToDevice(device);
      },
      context: context,
    );
  }

  void _connectToDevice(fbp.BluetoothDevice device) {
    _bluetoothService
        .connectToDevice(
      device: device,
      dataProcessor: _processData, // Pass the data processing function
      context: context,
    )
        .then((success) {
      if (success) {
        setState(() {
          // Update UI to reflect connected state
        });
      }
    });
  }

  // ******************************************************************************
  // * DATA PROCESSING METHODS
  // ******************************************************************************

  void _processContinuousMode(
      DateTime now,
      double temp,
      double pressure,
      double ax,
      double ay,
      double az,
      double computedAccelTotal,
      double gx,
      double gy,
      double gz,
      double computedGyroTotal) {
    // Em modo contínuo, sempre atualizamos os dados sem limpar os anteriores
    if (mounted) {
      setState(() {
        // Verificamos se já temos muitos pontos - se sim, removemos os mais antigos
        // para garantir que sempre temos espaço para novos dados
        if (_temperatureData.length >= 50) _temperatureData.removeAt(0);
        if (_pressureData.length >= 50) _pressureData.removeAt(0);
        if (_accelTotalData.length >= 50) _accelTotalData.removeAt(0);
        if (_gyroTotalData.length >= 50) _gyroTotalData.removeAt(0);
        if (_accelXData.length >= 50) _accelXData.removeAt(0);
        if (_accelYData.length >= 50) _accelYData.removeAt(0);
        if (_accelZData.length >= 50) _accelZData.removeAt(0);
        if (_gyroXData.length >= 50) _gyroXData.removeAt(0);
        if (_gyroYData.length >= 50) _gyroYData.removeAt(0);
        if (_gyroZData.length >= 50) _gyroZData.removeAt(0);

        // Agora adicionamos os novos dados
        _temperatureData.add(SensorData(now, temp));
        _pressureData.add(SensorData(now, pressure));
        _accelTotalData.add(SensorData(now, computedAccelTotal));
        _gyroTotalData.add(SensorData(now, computedGyroTotal));
        _accelXData.add(SensorData(now, ax));
        _accelYData.add(SensorData(now, ay));
        _accelZData.add(SensorData(now, az));
        _gyroXData.add(SensorData(now, gx));
        _gyroYData.add(SensorData(now, gy));
        _gyroZData.add(SensorData(now, gz));
      });
    }
  }

  // Modificação no método _processData para melhorar a detecção de impacto
  void _processData(String data) {
    try {
      // Expected data format:
      // T:<temp>, P:<pressure>, A:<ax>,<ay>,<az>, At:<total_acceleration>,
      // G:<gx>,<gy>,<gz>, Gt:<total_rotation>
      final RegExp regExp = RegExp(
        r'T:([\d.]+), P:([\d.]+), A:([\d.-]+),([\d.-]+),([\d.-]+), At:([\d.]+), G:([\d.-]+),([\d.-]+),([\d.-]+), Gt:([\d.]+)',
      );
      final Match? match = regExp.firstMatch(data);

      if (match != null) {
        final DateTime now = DateTime.now();
        final double temp = double.parse(match.group(1)!);
        final double pressure = double.parse(match.group(2)!);
        final double ax = double.parse(match.group(3)!);
        final double ay = double.parse(match.group(4)!);
        final double az = double.parse(match.group(5)!);
        // Compute total acceleration using the formula √(ax²+ay²+az²)
        final double computedAccelTotal = sqrt(ax * ax + ay * ay + az * az);

        final double gx = double.parse(match.group(7)!);
        final double gy = double.parse(match.group(8)!);
        final double gz = double.parse(match.group(9)!);
        // Compute total rotation using the formula √(gx²+gy²+gz²)
        final double computedGyroTotal = sqrt(gx * gx + gy * gy + gz * gz);

        // Check for impact regardless of mode
        bool newImpact = false;
        if (computedAccelTotal >= _impactThreshold) {
          _impactDetected = true;
          _lastImpactTime = now;
          newImpact = true;
        }

        // Different processing based on current mode
        if (widget.mode == OperationMode.continuous) {
          _processContinuousMode(now, temp, pressure, ax, ay, az,
              computedAccelTotal, gx, gy, gz, computedGyroTotal);
        } else {
          _processImpactMode(now, temp, pressure, ax, ay, az,
              computedAccelTotal, gx, gy, gz, computedGyroTotal, newImpact);
        }
      }
    } catch (e) {
      print('Error parsing data: $e');
    }
  }

  // Replace the _processImpactMode method with this updated version
  void _processImpactMode(
      DateTime now,
      double temp,
      double pressure,
      double ax,
      double ay,
      double az,
      double computedAccelTotal,
      double gx,
      double gy,
      double gz,
      double computedGyroTotal,
      bool newImpact) {
    // Always add data to the pre-impact buffer
    _updatePreImpactBuffer(now, temp, pressure, ax, ay, az, computedAccelTotal,
        gx, gy, gz, computedGyroTotal);

    // If a new impact was just detected
    if (newImpact) {
      if (mounted) {
        setState(() {
          // Clear previous data and copy the pre-impact buffer
          _clearSensorData();

          // Copy all pre-impact buffer data to the main display data
          _temperatureData.addAll(_preImpactTempBuffer);
          _pressureData.addAll(_preImpactPressureBuffer);
          _accelXData.addAll(_preImpactAccelXBuffer);
          _accelYData.addAll(_preImpactAccelYBuffer);
          _accelZData.addAll(_preImpactAccelZBuffer);
          _accelTotalData.addAll(_preImpactAccelTotalBuffer);
          _gyroXData.addAll(_preImpactGyroXBuffer);
          _gyroYData.addAll(_preImpactGyroYBuffer);
          _gyroZData.addAll(_preImpactGyroZBuffer);
          _gyroTotalData.addAll(_preImpactGyroTotalBuffer);

          // Add the current impact data point
          _temperatureData.add(SensorData(now, temp));
          _pressureData.add(SensorData(now, pressure));
          _accelXData.add(SensorData(now, ax));
          _accelYData.add(SensorData(now, ay));
          _accelZData.add(SensorData(now, az));
          _accelTotalData.add(SensorData(now, computedAccelTotal));
          _gyroXData.add(SensorData(now, gx));
          _gyroYData.add(SensorData(now, gy));
          _gyroZData.add(SensorData(now, gz));
          _gyroTotalData.add(SensorData(now, computedGyroTotal));

          _impactDataDisplayed = true;
        });
      }
    }
    // If we're already displaying impact data, continue to update it
    else if (_impactDataDisplayed &&
        _impactDetected &&
        _lastImpactTime != null) {
      final Duration timeSinceImpact = now.difference(_lastImpactTime!);

      // Continue showing data for 5 seconds after impact
      if (timeSinceImpact.inSeconds <= 5) {
        if (mounted) {
          setState(() {
            // Add the current data point
            _temperatureData.add(SensorData(now, temp));
            _pressureData.add(SensorData(now, pressure));
            _accelXData.add(SensorData(now, ax));
            _accelYData.add(SensorData(now, ay));
            _accelZData.add(SensorData(now, az));
            _accelTotalData.add(SensorData(now, computedAccelTotal));
            _gyroXData.add(SensorData(now, gx));
            _gyroYData.add(SensorData(now, gy));
            _gyroZData.add(SensorData(now, gz));
            _gyroTotalData.add(SensorData(now, computedGyroTotal));

            // Limit the size to prevent memory issues
            _limitDisplayDataSize();
          });
        }
      } else {
        // After 5 seconds, stop updating the display but keep the impact data
        _impactDetected = false;
      }
    }
  }

  // Add this new method to update pre-impact buffer
  void _updatePreImpactBuffer(
      DateTime now,
      double temp,
      double pressure,
      double ax,
      double ay,
      double az,
      double computedAccelTotal,
      double gx,
      double gy,
      double gz,
      double computedGyroTotal) {
    // Add data to pre-impact buffers
    _preImpactTempBuffer.add(SensorData(now, temp));
    _preImpactPressureBuffer.add(SensorData(now, pressure));
    _preImpactAccelXBuffer.add(SensorData(now, ax));
    _preImpactAccelYBuffer.add(SensorData(now, ay));
    _preImpactAccelZBuffer.add(SensorData(now, az));
    _preImpactAccelTotalBuffer.add(SensorData(now, computedAccelTotal));
    _preImpactGyroXBuffer.add(SensorData(now, gx));
    _preImpactGyroYBuffer.add(SensorData(now, gy));
    _preImpactGyroZBuffer.add(SensorData(now, gz));
    _preImpactGyroTotalBuffer.add(SensorData(now, computedGyroTotal));

    // Keep pre-impact buffers at defined size by removing oldest data
    if (_preImpactTempBuffer.length > _bufferSize) {
      _preImpactTempBuffer.removeAt(0);
    }
    if (_preImpactPressureBuffer.length > _bufferSize) {
      _preImpactPressureBuffer.removeAt(0);
    }
    if (_preImpactAccelXBuffer.length > _bufferSize) {
      _preImpactAccelXBuffer.removeAt(0);
    }
    if (_preImpactAccelYBuffer.length > _bufferSize) {
      _preImpactAccelYBuffer.removeAt(0);
    }
    if (_preImpactAccelZBuffer.length > _bufferSize) {
      _preImpactAccelZBuffer.removeAt(0);
    }
    if (_preImpactAccelTotalBuffer.length > _bufferSize) {
      _preImpactAccelTotalBuffer.removeAt(0);
    }
    if (_preImpactGyroXBuffer.length > _bufferSize) {
      _preImpactGyroXBuffer.removeAt(0);
    }
    if (_preImpactGyroYBuffer.length > _bufferSize) {
      _preImpactGyroYBuffer.removeAt(0);
    }
    if (_preImpactGyroZBuffer.length > _bufferSize) {
      _preImpactGyroZBuffer.removeAt(0);
    }
    if (_preImpactGyroTotalBuffer.length > _bufferSize) {
      _preImpactGyroTotalBuffer.removeAt(0);
    }
  }

  // Add this method to limit the size of display data
  void _limitDisplayDataSize() {
    final int maxDisplaySize = 150; // Maximum size for display data

    if (_temperatureData.length > maxDisplaySize) _temperatureData.removeAt(0);
    if (_pressureData.length > maxDisplaySize) _pressureData.removeAt(0);
    if (_accelXData.length > maxDisplaySize) _accelXData.removeAt(0);
    if (_accelYData.length > maxDisplaySize) _accelYData.removeAt(0);
    if (_accelZData.length > maxDisplaySize) _accelZData.removeAt(0);
    if (_accelTotalData.length > maxDisplaySize) _accelTotalData.removeAt(0);
    if (_gyroXData.length > maxDisplaySize) _gyroXData.removeAt(0);
    if (_gyroYData.length > maxDisplaySize) _gyroYData.removeAt(0);
    if (_gyroZData.length > maxDisplaySize) _gyroZData.removeAt(0);
    if (_gyroTotalData.length > maxDisplaySize) _gyroTotalData.removeAt(0);
  }

  // Clear all sensor data
  void _clearSensorData() {
    _temperatureData.clear();
    _pressureData.clear();
    _accelTotalData.clear();
    _gyroTotalData.clear();
    _accelXData.clear();
    _accelYData.clear();
    _accelZData.clear();
    _gyroXData.clear();
    _gyroYData.clear();
    _gyroZData.clear();
  }

  // ******************************************************************************
  // * UI BUILDING METHODS
  // ******************************************************************************

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
              widget.mode == OperationMode.continuous ? 'Continuous' : 'Impact',
              style: const TextStyle(color: Colors.white),
            ),
          ),
          const SizedBox(width: 8),

          // Reset app button using flutter_phoenix
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reset App',
            onPressed: () {
              Phoenix.rebirth(context);
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
                    impactThreshold: _impactThreshold,
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
              SystemNavigator.pop();
            },
          ),
        ],
      ),
      body: _bluetoothService.isConnected
          ? _buildConnectedView()
          : _buildConnectingView(),
    );
  }

  // View when connecting to device
  Widget _buildConnectingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 20),
          const Text(
            'Connecting to the device ESP32_GY91...',
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: () {
              _startBluetoothConnection();
            },
            child: const Text('Try again'),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => const StartPage(),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey,
            ),
            child: const Text('Back'),
          ),
        ],
      ),
    );
  }

  // View when connected to device
  Widget _buildConnectedView() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Mode info banner
          Container(
            decoration: AppTheme.cardDecoration,
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            // color: widget.mode == OperationMode.continuous
            //     ? Colors.blue.shade100
            //     : Colors.orange.shade100,
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
                        : 'Data is only displayed when an impact is detected (Threshold: $_impactThreshold g)',
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

          // Charts
          _buildChart('Temperature (°C)', _temperatureData),
          _buildChart('Pressure (hPa)', _pressureData),
          _buildChart(
            'Acceleration Total (g)',
            _accelTotalData,
            additionalAnnotation: _buildThresholdAnnotation(_impactThreshold),
          ),
          _buildChart('Gyro Total (dps)', _gyroTotalData),

          // Change mode button
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (context) => const StartPage(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              ),
              child: const Text(
                'Change Mode',
                style: TextStyle(
                  fontSize: 18,
                ),
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
    return SizedBox(
      height: 200,
      child: SfCartesianChart(
        title: ChartTitle(text: title),
        annotations: additionalAnnotation != null
            ? <CartesianChartAnnotation>[additionalAnnotation]
            : null,
        series: <LineSeries<SensorData, DateTime>>[
          LineSeries<SensorData, DateTime>(
            dataSource: data,
            xValueMapper: (SensorData data, _) => data.time,
            yValueMapper: (SensorData data, _) => data.value,
          ),
        ],
        primaryXAxis: DateTimeAxis(
          // Configurando o eixo X para mostrar um intervalo adequado
          intervalType: DateTimeIntervalType.seconds,
          interval: 2, // Ajuste conforme necessário
          // Ajusta automaticamente o intervalo visível com base nos dados
          autoScrollingDelta: 50, // Mostra os últimos 20 pontos
          autoScrollingDeltaType: DateTimeIntervalType.seconds,
        ),
        primaryYAxis: NumericAxis(
          // Permite que o eixo Y ajuste automaticamente com base nos valores recentes
          enableAutoIntervalOnZooming: true,
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
      x: DateTime.now(), // Places the annotation at the current time.
      y: threshold,
    );
  }
}
