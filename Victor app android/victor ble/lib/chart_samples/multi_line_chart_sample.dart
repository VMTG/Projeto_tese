import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:Sensor/main.dart';

class MultiLineChartSample extends StatelessWidget {
  final String title;
  final List<List<SensorData>> dataSeries;
  final List<String> seriesNames;
  final List<Color> seriesColors;

  const MultiLineChartSample({
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
            child: LineChart(
              mainData(),
            ),
          ),
        ],
      ),
    );
  }

  LineChartData mainData() {
    // Find min and max values for better scaling
    double? minY, maxY;
    DateTime? minX, maxX;

    // Find global min/max across all series
    for (var series in dataSeries) {
      if (series.isEmpty) continue;

      final seriesMinY =
          series.map((e) => e.value).reduce((a, b) => a < b ? a : b);
      final seriesMaxY =
          series.map((e) => e.value).reduce((a, b) => a > b ? a : b);
      final seriesMinX =
          series.map((e) => e.time).reduce((a, b) => a.isBefore(b) ? a : b);
      final seriesMaxX =
          series.map((e) => e.time).reduce((a, b) => a.isAfter(b) ? a : b);

      minY =
          minY == null ? seriesMinY : (seriesMinY < minY ? seriesMinY : minY);
      maxY =
          maxY == null ? seriesMaxY : (seriesMaxY > maxY ? seriesMaxY : maxY);
      minX = minX == null
          ? seriesMinX
          : (seriesMinX.isBefore(minX) ? seriesMinX : minX);
      maxX = maxX == null
          ? seriesMaxX
          : (seriesMaxX.isAfter(maxX) ? seriesMaxX : maxX);
    }

    // Add some padding to the min/max y values
    if (minY != null && maxY != null) {
      final yPadding = (maxY - minY) * 0.1;
      minY = minY - yPadding;
      maxY = maxY + yPadding;
    }

    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: true,
        horizontalInterval: 1,
        verticalInterval: 1,
        getDrawingHorizontalLine: (value) {
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
            interval: 1,
            // interval: (maxX?.difference(minX ?? maxX).inSeconds ?? 10) / 5,
            getTitlesWidget: (value, meta) {
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
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: 1,
            //interval: ((maxY ?? 10) - (minY ?? 0)) / 5,
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
      minX: minX?.millisecondsSinceEpoch.toDouble() ?? 0,
      maxX: maxX?.millisecondsSinceEpoch.toDouble() ?? 10,
      minY: minY ?? 0,
      maxY: maxY ?? 10,
      lineTouchData: LineTouchData(
        enabled: true,
        touchTooltipData: LineTouchTooltipData(
          tooltipBgColor: Colors.blueGrey.withOpacity(0.8),
          getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
            return touchedBarSpots.map((barSpot) {
              final dateTime =
                  DateTime.fromMillisecondsSinceEpoch(barSpot.x.toInt());
              final time =
                  '${dateTime.hour}:${dateTime.minute}:${dateTime.second}';
              final seriesIndex = barSpot.barIndex;
              return LineTooltipItem(
                '${seriesNames[seriesIndex]}: ${barSpot.y.toStringAsFixed(2)} at $time',
                TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              );
            }).toList();
          },
        ),
      ),
      lineBarsData: _createLineBarsData(),
    );
  }

  List<LineChartBarData> _createLineBarsData() {
    List<LineChartBarData> result = [];

    for (int i = 0; i < dataSeries.length; i++) {
      if (i >= seriesColors.length) break;

      final data = dataSeries[i];
      final color = seriesColors[i];

      result.add(
        LineChartBarData(
          spots: data.map((point) {
            return FlSpot(
              point.time.millisecondsSinceEpoch.toDouble(),
              point.value,
            );
          }).toList(),
          isCurved: true,
          color: color,
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: FlDotData(
            show: data.length < 30, // Show dots only for shorter series
            getDotPainter: (spot, percent, barData, index) {
              return FlDotCirclePainter(
                radius: 3,
                color: color,
                strokeWidth: 1,
                strokeColor: Colors.white,
              );
            },
          ),
          belowBarData: BarAreaData(
            show: true,
            color: color.withOpacity(0.1),
          ),
        ),
      );
    }

    return result;
  }
}
