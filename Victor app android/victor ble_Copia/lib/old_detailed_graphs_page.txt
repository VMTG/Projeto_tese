import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:Sensor/main.dart';
//import 'package:Sensor/bar_chart_sample4.dart';
//import 'package:Sensor/line_chart_sample7.dart';

// ******************************************************************************
// * DETAILED GRAPHS PAGE
// * Shows extended visualization of sensor data with multiple chart types
// ******************************************************************************
class DetailedGraphsPage extends StatelessWidget {
  // ----------------------
  // Operation mode
  // ----------------------
  final OperationMode mode;
  final double impactThreshold;

  // ----------------------
  // Data lists passed from main screen
  // ----------------------
  final List<SensorData> accelXData;
  final List<SensorData> accelYData;
  final List<SensorData> accelZData;
  final List<SensorData> accelTotalData;
  final List<SensorData> gyroXData;
  final List<SensorData> gyroYData;
  final List<SensorData> gyroZData;
  final List<SensorData> gyroTotalData;

  const DetailedGraphsPage({
    super.key,
    required this.mode,
    required this.impactThreshold,
    required this.accelXData,
    required this.accelYData,
    required this.accelZData,
    required this.accelTotalData,
    required this.gyroXData,
    required this.gyroYData,
    required this.gyroZData,
    required this.gyroTotalData,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
            'Detailed Graphs - ${mode == OperationMode.continuous ? 'Continuous Mode' : 'Impact Mode'}'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              // Mode info banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: mode == OperationMode.continuous
                    ? Colors.blue.shade100
                    : Colors.orange.shade100,
                child: Row(
                  children: [
                    Icon(
                      mode == OperationMode.continuous
                          ? Icons.play_circle_outline
                          : Icons.flash_on,
                      color: mode == OperationMode.continuous
                          ? Colors.blue
                          : Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        mode == OperationMode.continuous
                            ? 'Continuous Mode: Data is displayed continuously'
                            : 'Impact Mode: Data is only displayed when an impact is detected (Threshold: $impactThreshold g)',
                        style: TextStyle(
                          color: mode == OperationMode.continuous
                              ? Colors.blue.shade800
                              : Colors.orange.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ----------------------
              // Accelerometer Data Section
              // ----------------------
              const Text('Accelerometer Data',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              _buildChart('Ax vs. Time', accelXData),
              _buildChart('Ay vs. Time', accelYData),
              _buildChart('Az vs. Time', accelZData),
              _buildChart('Total Acceleration vs. Time', accelTotalData,
                  additionalAnnotation:
                      _buildThresholdAnnotation(impactThreshold)),
              const SizedBox(height: 20),

              // ----------------------
              // Gyroscope Data Section
              // ----------------------
              const Text('Gyroscope Data',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              _buildChart('Gx vs. Time', gyroXData),
              _buildChart('Gy vs. Time', gyroYData),
              _buildChart('Gz vs. Time', gyroZData),
              _buildChart('Total Rotation vs. Time', gyroTotalData),
              const SizedBox(height: 20),

              // Inside the children list of the Column widget in the build method
              // Add after your existing Combined Graphs section

              // ----------------------
              // Combined Graphs Section
              // ----------------------
              // const Text('Combined Graphs',
              //     style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              // _buildCombinedChart('Total Acceleration & Rotation',
              //     accelTotalData, gyroTotalData),
              // BarChartSample4(
              //   title: 'Acceleration & Rotation Comparison (Bar)',
              //   dataSeries: [accelTotalData, gyroTotalData],
              //   seriesNames: ['Acceleration', 'Rotation'],
              //   seriesColors: [Colors.blue, Colors.red],
              // ),
              // _buildMultiSeriesChart('X, Y, Z Accelerations',
              //     [accelXData, accelYData, accelZData], ['Ax', 'Ay', 'Az']),
              // BarChartSample4(
              //   title: 'X, Y, Z Accelerations (Bar)',
              //   dataSeries: [accelXData, accelYData, accelZData],
              //   seriesNames: ['Ax', 'Ay', 'Az'],
              //   seriesColors: [Colors.blue, Colors.green, Colors.orange],
              // ),
              // _buildMultiSeriesChart('X, Y, Z Rotations',
              //     [gyroXData, gyroYData, gyroZData], ['Gx', 'Gy', 'Gz']),
              // BarChartSample4(
              //   title: 'X, Y, Z Rotations (Bar)',
              //   dataSeries: [gyroXData, gyroYData, gyroZData],
              //   seriesNames: ['Gx', 'Gy', 'Gz'],
              //   seriesColors: [Colors.purple, Colors.teal, Colors.amber],
              // ),
              const Text('Combined Graphs',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              _buildCombinedChart('Total Acceleration & Rotation',
                  accelTotalData, gyroTotalData),
              _buildMultiSeriesChart('X, Y, Z Accelerations',
                  [accelXData, accelYData, accelZData], ['Ax', 'Ay', 'Az']),
              _buildMultiSeriesChart('X, Y, Z Rotations',
                  [gyroXData, gyroYData, gyroZData], ['Gx', 'Gy', 'Gz']),
              // ----------------------
              // Impact Detection Section
              // ----------------------
              const Text('Impact Detection (Acceleration Threshold)',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              _buildChart(
                  'Acceleration vs. Time (Threshold Marked)', accelTotalData,
                  additionalAnnotation:
                      _buildThresholdAnnotation(impactThreshold)),
            ],
          ),
        ),
      ),
    );
  }

  // ******************************************************************************
  // * CHART BUILDING HELPER METHODS
  // ******************************************************************************

  // Build a basic single-series chart
  // Replace _buildChart method with this implementation
  // Widget _buildChart(String title, List<SensorData> data,
  //     {CartesianChartAnnotation? additionalAnnotation}) {
  //   // Check if this is a threshold chart
  //   double? threshold;
  //   if (additionalAnnotation != null) {
  //     threshold = impactThreshold;
  //   }

  //   return LineChartSample7(
  //     title: title,
  //     data: data,
  //     lineColor: Colors.blue,
  //     threshold: threshold,
  //     showDots: data.length < 50, // Only show dots if we have fewer data points
  //   );
  // }

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
        primaryXAxis: DateTimeAxis(),
        primaryYAxis: NumericAxis(),
      ),
    );
  }

  // Build a chart with two data series (for comparing two metrics)
  Widget _buildCombinedChart(
      String title, List<SensorData> series1, List<SensorData> series2) {
    return SizedBox(
      height: 200,
      child: SfCartesianChart(
        title: ChartTitle(text: title),
        legend: Legend(isVisible: true),
        series: <LineSeries<SensorData, DateTime>>[
          LineSeries<SensorData, DateTime>(
            name: 'Total Acceleration',
            dataSource: series1,
            xValueMapper: (SensorData data, _) => data.time,
            yValueMapper: (SensorData data, _) => data.value,
          ),
          LineSeries<SensorData, DateTime>(
            name: 'Total Rotation',
            dataSource: series2,
            xValueMapper: (SensorData data, _) => data.time,
            yValueMapper: (SensorData data, _) => data.value,
          ),
        ],
        primaryXAxis: DateTimeAxis(),
        primaryYAxis: NumericAxis(),
      ),
    );
  }

  // Build a chart with multiple data series
  Widget _buildMultiSeriesChart(String title, List<List<SensorData>> seriesData,
      List<String> seriesNames) {
    List<LineSeries<SensorData, DateTime>> seriesList = [];
    for (int i = 0; i < seriesData.length; i++) {
      seriesList.add(
        LineSeries<SensorData, DateTime>(
          name: seriesNames[i],
          dataSource: seriesData[i],
          xValueMapper: (SensorData data, _) => data.time,
          yValueMapper: (SensorData data, _) => data.value,
        ),
      );
    }
    return SizedBox(
      height: 200,
      child: SfCartesianChart(
        title: ChartTitle(text: title),
        legend: Legend(isVisible: true),
        series: seriesList,
        primaryXAxis: DateTimeAxis(),
        primaryYAxis: NumericAxis(),
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
