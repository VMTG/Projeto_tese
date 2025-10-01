import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:Sensor/main.dart';

class LineChartSample7 extends StatelessWidget {
  final String title;
  final List<SensorData> data;
  final Color lineColor;
  final double? threshold;
  final bool showDots;

  const LineChartSample7({
    super.key,
    required this.title,
    required this.data,
    this.lineColor = Colors.blue,
    this.threshold,
    this.showDots = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(
          height: 200,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: data.isEmpty
                ? const Center(child: Text('No data available'))
                : LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: true,
                        horizontalInterval: 1,
                        verticalInterval: 1,
                        getDrawingHorizontalLine: (value) {
                          return FlLine(
                            color: Colors.grey.withOpacity(0.3),
                            strokeWidth: 1,
                          );
                        },
                        getDrawingVerticalLine: (value) {
                          return FlLine(
                            color: Colors.grey.withOpacity(0.3),
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
                            interval: _calculateTimeInterval(),
                            getTitlesWidget: (value, meta) {
                              if (value.toInt() >= 0 &&
                                  value.toInt() < data.length) {
                                final date = data[value.toInt()].time;
                                return SideTitleWidget(
                                  axisSide: meta.axisSide,
                                  child: Text(
                                    '${date.hour}:${date.minute.toString().padLeft(2, '0')}',
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                );
                              }
                              return const SizedBox();
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: _calculateValueInterval(),
                            getTitlesWidget: (value, meta) {
                              return SideTitleWidget(
                                axisSide: meta.axisSide,
                                child: Text(
                                  value.toStringAsFixed(1),
                                  style: const TextStyle(fontSize: 10),
                                ),
                              );
                            },
                            reservedSize: 42,
                          ),
                        ),
                      ),
                      borderData: FlBorderData(
                        show: true,
                        border: Border.all(
                            color: const Color(0xff37434d), width: 1),
                      ),
                      minX: 0,
                      maxX: (data.length - 1).toDouble(),
                      minY: _getMinY(),
                      maxY: _getMaxY(),
                      lineBarsData: [
                        LineChartBarData(
                          spots: _createSpots(),
                          isCurved: true,
                          color: lineColor,
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: FlDotData(
                            show: showDots,
                            getDotPainter: (spot, percent, barData, index) {
                              return FlDotCirclePainter(
                                radius: 4,
                                color: lineColor,
                                strokeWidth: 2,
                                strokeColor: Colors.white,
                              );
                            },
                          ),
                          belowBarData: BarAreaData(
                            show: true,
                            color: lineColor.withOpacity(0.2),
                          ),
                        ),
                      ],
                      extraLinesData: threshold != null
                          ? ExtraLinesData(
                              horizontalLines: [
                                HorizontalLine(
                                  y: threshold!,
                                  color: Colors.red,
                                  strokeWidth: 2,
                                  dashArray: [5, 5],
                                  label: HorizontalLineLabel(
                                    show: true,
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    labelResolver: (line) =>
                                        'Threshold: ${threshold!.toStringAsFixed(1)}',
                                    alignment: Alignment.topRight,
                                  ),
                                ),
                              ],
                            )
                          : null,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  List<FlSpot> _createSpots() {
    final spots = <FlSpot>[];
    for (int i = 0; i < data.length; i++) {
      spots.add(FlSpot(i.toDouble(), data[i].value));
    }
    return spots;
  }

  double _getMinY() {
    if (data.isEmpty) return 0;
    double minValue = data.map((e) => e.value).reduce((a, b) => a < b ? a : b);
    // Add some padding below the minimum value
    return (minValue < 0) ? minValue * 1.1 : minValue * 0.9;
  }

  double _getMaxY() {
    if (data.isEmpty) return 10;
    double maxValue = data.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    // If we have a threshold and it's higher than the max value, use it instead
    if (threshold != null && threshold! > maxValue) {
      maxValue = threshold!;
    }
    // Add some padding above the maximum value
    return maxValue * 1.1;
  }

  double _calculateValueInterval() {
    if (data.isEmpty) return 1;
    double minValue = _getMinY();
    double maxValue = _getMaxY();
    double range = maxValue - minValue;

    // Calculate a suitable interval (aim for 4-6 divisions)
    if (range <= 5) return 1;
    if (range <= 10) return 2;
    if (range <= 20) return 5;
    if (range <= 50) return 10;
    if (range <= 100) return 20;
    return range / 5; // fallback to divide range into 5 parts
  }

  double _calculateTimeInterval() {
    // Calculate time interval based on data length
    if (data.length <= 10) return 1;
    if (data.length <= 30) return 2;
    if (data.length <= 60) return 5;
    if (data.length <= 100) return 10;
    return data.length / 10; // Display approximately 10 time labels
  }
}
