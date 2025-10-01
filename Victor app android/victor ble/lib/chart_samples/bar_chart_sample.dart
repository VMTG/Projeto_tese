import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:Sensor/main.dart';

class BarChartSample extends StatelessWidget {
  final String title;
  final List<List<SensorData>> dataSeries;
  final List<String> seriesNames;
  final List<Color> seriesColors;

  const BarChartSample({
    super.key,
    required this.title,
    required this.dataSeries,
    required this.seriesNames,
    required this.seriesColors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
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
          // Legend
          SizedBox(
            height: 25,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: seriesNames.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: seriesColors[index],
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        seriesNames[index],
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          // Chart
          Expanded(
            child: _buildBarChart(),
          ),
        ],
      ),
    );
  }

  Widget _buildBarChart() {
    // Prepare data
    // We'll take the most recent 10 data points for each series for the bar chart
    List<List<SensorData>> trimmedData = [];
    for (var series in dataSeries) {
      if (series.isEmpty) {
        trimmedData.add([]);
        continue;
      }

      // Sort by time
      final sortedSeries = List<SensorData>.from(series)
        ..sort((a, b) => b.time.compareTo(a.time));

      // Take most recent 10 or fewer
      trimmedData.add(sortedSeries.take(10).toList());
    }

    // Find max Y for scaling
    double maxY = 0;
    for (var series in trimmedData) {
      if (series.isEmpty) continue;
      final seriesMax =
          series.map((e) => e.value.abs()).reduce((a, b) => a > b ? a : b);
      if (seriesMax > maxY) maxY = seriesMax;
    }
    maxY = maxY * 1.1; // Add 10% padding

    // Get all timestamps from all series
    final allTimestamps = <DateTime>[];
    for (var series in trimmedData) {
      allTimestamps.addAll(series.map((e) => e.time));
    }

    // Sort timestamps and remove duplicates
    final uniqueTimestamps = allTimestamps.toSet().toList()
      ..sort((a, b) => a.compareTo(b));

    // Get up to 10 timestamps for the x-axis
    final xAxisTimestamps = uniqueTimestamps.length > 10
        ? uniqueTimestamps.sublist(uniqueTimestamps.length - 10)
        : uniqueTimestamps;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.center,
        maxY: maxY,
        minY: 0,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            tooltipBgColor: Colors.blueGrey.withOpacity(0.8),
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final seriesName = seriesNames[rodIndex];
              final series = trimmedData[rodIndex];

              // Find the data point for this group and rod
              SensorData? dataPoint;
              for (var point in series) {
                if (point.time.millisecondsSinceEpoch.toDouble() == group.x) {
                  dataPoint = point;
                  break;
                }
              }

              if (dataPoint == null) return null;

              final dateTime = dataPoint.time;
              final time =
                  '${dateTime.hour}:${dateTime.minute}:${dateTime.second}';

              return BarTooltipItem(
                '$seriesName: ${dataPoint.value.toStringAsFixed(2)}\n$time',
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              );
            },
          ),
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
              getTitlesWidget: (double value, TitleMeta meta) {
                final dateTime =
                    DateTime.fromMillisecondsSinceEpoch(value.toInt());
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    '${dateTime.second}s',
                    style: const TextStyle(
                      color: Colors.black54,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                );
              },
              reservedSize: 30,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toStringAsFixed(1),
                  style: const TextStyle(
                    color: Colors.black54,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                  textAlign: TextAlign.left,
                );
              },
              reservedSize: 42,
            ),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: Colors.grey.withOpacity(0.3)),
        ),
        gridData: FlGridData(
          show: true,
          drawHorizontalLine: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.grey.withOpacity(0.2),
              strokeWidth: 1,
            );
          },
        ),
        barGroups: _createBarGroups(trimmedData, xAxisTimestamps),
      ),
    );
  }

  List<BarChartGroupData> _createBarGroups(
      List<List<SensorData>> trimmedData, List<DateTime> timestamps) {
    List<BarChartGroupData> result = [];

    for (int i = 0; i < timestamps.length; i++) {
      final timestamp = timestamps[i];
      final xValue = timestamp.millisecondsSinceEpoch.toDouble();

      List<BarChartRodData> rods = [];

      for (int seriesIndex = 0;
          seriesIndex < trimmedData.length;
          seriesIndex++) {
        final series = trimmedData[seriesIndex];

        // Find data point with matching timestamp
        SensorData? dataPoint;
        for (var point in series) {
          if (point.time.difference(timestamp).inMilliseconds.abs() < 500) {
            dataPoint = point;
            break;
          }
        }

        if (dataPoint != null) {
          rods.add(
            BarChartRodData(
              toY: dataPoint.value.abs(),
              color: seriesColors[seriesIndex],
              width: 12,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
            ),
          );
        } else {
          // Add a placeholder bar with zero height if no matching data point
          rods.add(
            BarChartRodData(
              toY: 0,
              color: seriesColors[seriesIndex].withOpacity(0.2),
              width: 12,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
            ),
          );
        }
      }

      result.add(
        BarChartGroupData(
          x: xValue.toInt(),
          barRods: rods,
        ),
      );
    }

    return result;
  }
}
