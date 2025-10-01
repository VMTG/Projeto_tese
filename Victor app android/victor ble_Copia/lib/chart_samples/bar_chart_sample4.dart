import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:Sensor/main.dart';

/// A bar chart implementation for comparing multiple sensor data series
/// This can be used in the Combined Charts section
class BarChartSample4 extends StatelessWidget {
  final String title;
  final List<List<SensorData>> dataSeries;
  final List<String> seriesNames;
  final List<Color> seriesColors;

  const BarChartSample4({
    super.key,
    required this.title,
    required this.dataSeries,
    required this.seriesNames,
    required this.seriesColors,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            _buildLegend(),
            const SizedBox(height: 8),
            SizedBox(
              height: 250,
              child: _buildBarChart(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        seriesNames.length,
        (index) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                color: seriesColors[index],
              ),
              const SizedBox(width: 4),
              Text(seriesNames[index]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBarChart() {
    // Process data to get the most recent readings (last 10 points)
    List<List<SensorData>> processedData = dataSeries.map((series) {
      // Take the most recent 10 points or fewer if not available
      final count = series.length;
      return series.sublist(count > 10 ? count - 10 : 0);
    }).toList();

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: _calculateMaxY(),
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            tooltipBgColor: Colors.blueGrey.shade200,
            tooltipPadding: const EdgeInsets.all(8),
            tooltipMargin: 8,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                '${seriesNames[rodIndex]}\n${rod.toY.toStringAsFixed(2)}',
                const TextStyle(color: Colors.black87),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (double value, TitleMeta meta) {
                // Show the last few digits of timestamp as labels
                int index = value.toInt();
                if (index >= 0 && index < processedData[0].length) {
                  final timestamp =
                      processedData[0][index].time.millisecondsSinceEpoch;
                  return Text(
                    (timestamp % 10000).toString(),
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  );
                }
                return const Text('');
              },
              reservedSize: 30,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (double value, TitleMeta meta) {
                String text = '';
                if (value == 0) {
                  text = '0';
                } else if (value == _calculateMaxY() / 2)
                  text = (_calculateMaxY() / 2).toStringAsFixed(1);
                else if (value == _calculateMaxY())
                  text = _calculateMaxY().toStringAsFixed(1);

                return Text(
                  text,
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                );
              },
              reservedSize: 30,
            ),
          ),
          rightTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        gridData: FlGridData(
          show: true,
          horizontalInterval: _calculateMaxY() / 4,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Colors.grey.withOpacity(0.3),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: Colors.grey.withOpacity(0.5)),
        ),
        barGroups: _createBarGroups(processedData),
      ),
    );
  }

  List<BarChartGroupData> _createBarGroups(
      List<List<SensorData>> processedData) {
    List<BarChartGroupData> groups = [];

    // For each time point (x-axis)
    for (int i = 0; i < processedData[0].length; i++) {
      List<BarChartRodData> rods = [];

      // For each data series (bars within a group)
      for (int seriesIndex = 0;
          seriesIndex < processedData.length;
          seriesIndex++) {
        if (i < processedData[seriesIndex].length) {
          rods.add(
            BarChartRodData(
              toY: processedData[seriesIndex][i]
                  .value
                  .abs(), // Use absolute value for better visualization
              color: seriesColors[seriesIndex],
              width: 12 /
                  processedData
                      .length, // Adjust width based on number of series
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
            ),
          );
        }
      }

      groups.add(BarChartGroupData(x: i, barRods: rods));
    }

    return groups;
  }

  double _calculateMaxY() {
    double maxY = 0;
    for (var series in dataSeries) {
      for (var data in series) {
        if (data.value.abs() > maxY) {
          maxY = data.value.abs();
        }
      }
    }
    return (maxY * 1.2).roundToDouble(); // Add 20% padding
  }
}
