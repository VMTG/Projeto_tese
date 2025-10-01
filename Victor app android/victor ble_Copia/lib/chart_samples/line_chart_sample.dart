import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:Sensor/main.dart';

class LineChartSample extends StatelessWidget {
  final String title;
  final List<SensorData> data;
  final Color lineColor;
  final double? threshold;
  final bool showDots;

  const LineChartSample({
    super.key,
    required this.title,
    required this.data,
    this.lineColor = Colors.blue,
    this.threshold,
    this.showDots = false,
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
          const SizedBox(height: 8),
          Expanded(
            child: data.isEmpty
                ? const Center(child: Text('No data available'))
                : LineChart(
                    mainData(),
                  ),
          ),
          if (threshold != null)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 2,
                    color: Colors.red,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Threshold: $threshold',
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 12,
                    ),
                  ),
                ],
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

    if (data.isNotEmpty) {
      minY = data.map((e) => e.value).reduce((a, b) => a < b ? a : b);
      maxY = data.map((e) => e.value).reduce((a, b) => a > b ? a : b);
      minX = data.map((e) => e.time).reduce((a, b) => a.isBefore(b) ? a : b);
      maxX = data.map((e) => e.time).reduce((a, b) => a.isAfter(b) ? a : b);

      // Add some padding to the min/max y values
      final yPadding = (maxY - minY) * 0.1;
      minY = minY - yPadding;
      maxY = maxY + yPadding;

      // Ensure threshold is visible if provided
      if (threshold != null) {
        if (threshold! > maxY) maxY = threshold! * 1.1;
        if (threshold! < minY) minY = threshold! * 0.9;
      }
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
          tooltipBgColor: Colors.blueAccent.withOpacity(0.8),
          getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
            return touchedBarSpots.map((barSpot) {
              final dateTime =
                  DateTime.fromMillisecondsSinceEpoch(barSpot.x.toInt());
              final time =
                  '${dateTime.hour}:${dateTime.minute}:${dateTime.second}';
              return LineTooltipItem(
                '${barSpot.y.toStringAsFixed(2)} at $time',
                const TextStyle(color: Colors.white),
              );
            }).toList();
          },
        ),
      ),
      lineBarsData: [
        LineChartBarData(
          spots: data.map((point) {
            return FlSpot(
              point.time.millisecondsSinceEpoch.toDouble(),
              point.value,
            );
          }).toList(),
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
                strokeWidth: 1,
                strokeColor: Colors.white,
              );
            },
          ),
          belowBarData: BarAreaData(
            show: true,
            color: lineColor.withOpacity(0.15),
          ),
        ),
        // Add threshold line if provided
        if (threshold != null)
          LineChartBarData(
            spots: [
              FlSpot(
                minX?.millisecondsSinceEpoch.toDouble() ?? 0,
                threshold!,
              ),
              FlSpot(
                maxX?.millisecondsSinceEpoch.toDouble() ?? 10,
                threshold!,
              ),
            ],
            isCurved: false,
            color: Colors.red,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: FlDotData(show: false),
            dashArray: [5, 5],
          ),
      ],
    );
  }
}
