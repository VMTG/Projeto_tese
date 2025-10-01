import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:Sensor/main.dart';

class HeatmapChartSample extends StatelessWidget {
  final String title;
  final List<SensorData> data;
  final double threshold;

  const HeatmapChartSample({
    super.key,
    required this.title,
    required this.data,
    required this.threshold,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 250,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            'Threshold: $threshold',
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),

          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem(Colors.blue.shade100, 'Low Impact'),
              const SizedBox(width: 16),
              _buildLegendItem(Colors.blue, 'Medium Impact'),
              const SizedBox(width: 16),
              _buildLegendItem(Colors.red, 'High Impact'),
            ],
          ),

          const SizedBox(height: 12),
          // Chart
          Expanded(
            child: _buildHeatmapChart(),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildHeatmapChart() {
    if (data.isEmpty) {
      return const Center(child: Text('No data available'));
    }

    // Sort data by time
    final sortedData = List<SensorData>.from(data)
      ..sort((a, b) => a.time.compareTo(b.time));

    // Calculate min/max values for scaling
    DateTime? minTime, maxTime;
    minTime = sortedData.first.time;
    maxTime = sortedData.last.time;

    // If we have very few data points, expand the time range a bit
    final timeRange = maxTime.difference(minTime).inMilliseconds;
    if (timeRange < 1000) {
      // Less than 1 second
      minTime = minTime.subtract(const Duration(milliseconds: 500));
      maxTime = maxTime.add(const Duration(milliseconds: 500));
    }

    return ScatterChart(
      ScatterChartData(
        scatterSpots: _createScatterSpots(sortedData),
        minX: minTime.millisecondsSinceEpoch.toDouble(),
        maxX: maxTime.millisecondsSinceEpoch.toDouble(),
        minY: 0,
        maxY: sortedData.map((e) => e.value).reduce((a, b) => a > b ? a : b) *
            1.2,
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: Colors.grey.withOpacity(0.3)),
        ),
        gridData: FlGridData(
          show: true,
          horizontalInterval: threshold,
          getDrawingHorizontalLine: (value) {
            // Make the threshold line stand out
            if ((value - threshold).abs() < 0.01) {
              return FlLine(
                color: Colors.red.withOpacity(0.7),
                strokeWidth: 2,
                dashArray: [5, 5],
              );
            }
            return FlLine(
              color: Colors.grey.withOpacity(0.2),
              strokeWidth: 1,
            );
          },
          getDrawingVerticalLine: (value) {
            return FlLine(
              color: Colors.grey.withOpacity(0.2),
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: (maxTime.millisecondsSinceEpoch -
                      minTime.millisecondsSinceEpoch) /
                  5,
              getTitlesWidget: (value, meta) {
                final dateTime =
                    DateTime.fromMillisecondsSinceEpoch(value.toInt());
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    '${dateTime.second}.${(dateTime.millisecond / 100).round()}s',
                    style: const TextStyle(
                      color: Colors.black54,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: threshold,
              getTitlesWidget: (value, meta) {
                // Highlight the threshold value
                final isThreshold = (value - threshold).abs() < 0.01;
                return Text(
                  value.toStringAsFixed(1),
                  style: TextStyle(
                    color: isThreshold ? Colors.red : Colors.black54,
                    fontWeight:
                        isThreshold ? FontWeight.bold : FontWeight.normal,
                    fontSize: 10,
                  ),
                  textAlign: TextAlign.left,
                );
              },
              reservedSize: 42,
            ),
          ),
        ),
        scatterTouchData: ScatterTouchData(
          enabled: true,
          touchTooltipData: ScatterTouchTooltipData(
            tooltipBgColor: Colors.blueGrey.withOpacity(0.8),
            getTooltipItems: (ScatterSpot touchedBarSpot) {
              final dateTime =
                  DateTime.fromMillisecondsSinceEpoch(touchedBarSpot.x.toInt());
              final time =
                  '${dateTime.hour}:${dateTime.minute}:${dateTime.second}.${dateTime.millisecond}';
              final impact = touchedBarSpot.y;
              final impactRatio = impact / threshold;
              String impactLevel = 'Low';
              if (impactRatio >= 2) {
                impactLevel = 'High';
              } else if (impactRatio >= 1) {
                impactLevel = 'Medium';
              }

              return ScatterTooltipItem(
                '$impactLevel Impact: ${impact.toStringAsFixed(2)}\n$time',
                textStyle: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                bottomMargin: 10,
              );
            },
          ),
        ),
      ),
    );
  }

  List<ScatterSpot> _createScatterSpots(List<SensorData> sortedData) {
    return sortedData.map((point) {
      final xValue = point.time.millisecondsSinceEpoch.toDouble();
      final yValue = point.value;

      // Determine color based on intensity relative to threshold
      Color dotColor;
      double dotSize;

      final ratio = yValue / threshold;
      if (ratio >= 2) {
        // High impact
        dotColor = Colors.red;
        dotSize = 16;
      } else if (ratio >= 1) {
        // Medium impact (over threshold)
        dotColor = Colors.blue;
        dotSize = 12;
      } else if (ratio >= 0.5) {
        // Low impact (below threshold)
        dotColor = Colors.blue.shade100;
        dotSize = 8;
      } else {
        // Very low impact
        dotColor = Colors.blue.shade50;
        dotSize = 4;
      }

      return ScatterSpot(
        xValue,
        yValue,
        color: dotColor,
        radius:
            dotSize / 2, // Changed from size: dotSize to radius: dotSize / 2
      );
    }).toList();
  }
}
