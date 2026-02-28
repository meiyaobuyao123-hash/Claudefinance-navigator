import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

/// 30日持仓市值走势图（简洁折线 Sparkline 风格）
class PortfolioChart extends StatelessWidget {
  /// 每个元素代表一天的总市值（按时间升序，最多30条）
  final List<double> values;
  final double height;

  const PortfolioChart({
    super.key,
    required this.values,
    this.height = 100,
  });

  @override
  Widget build(BuildContext context) {
    if (values.length < 2) {
      return SizedBox(
        height: height,
        child: const Center(
          child: Text(
            '数据积累中，明日起可查看走势',
            style: TextStyle(fontSize: 12, color: AppColors.textHint),
          ),
        ),
      );
    }

    final spots = values
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value))
        .toList();

    final minY = values.reduce((a, b) => a < b ? a : b);
    final maxY = values.reduce((a, b) => a > b ? a : b);
    final padding = (maxY - minY) * 0.15;
    final isUp = values.last >= values.first;
    final lineColor = isUp ? AppColors.error : AppColors.success;

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.3,
              color: lineColor,
              barWidth: 2,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    lineColor.withOpacity(0.15),
                    lineColor.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ],
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: const FlTitlesData(show: false),
          minX: 0,
          maxX: (values.length - 1).toDouble(),
          minY: minY - padding,
          maxY: maxY + padding,
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => AppColors.textPrimary.withOpacity(0.85),
              getTooltipItems: (spots) => spots
                  .map(
                    (s) => LineTooltipItem(
                      '¥${_fmt(s.y)}',
                      const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      ),
    );
  }

  static String _fmt(double v) {
    if (v.abs() >= 10000) return '${(v / 10000).toStringAsFixed(2)}万';
    return v.toStringAsFixed(2);
  }
}
