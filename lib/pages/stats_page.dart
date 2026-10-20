import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../db/database_helper.dart';
import '../models/expense_record.dart' show formatYuan;
import '../providers/app_data.dart';
import '../utils/date_util.dart';
import '../widgets/month_switcher.dart';

/// 图表配色（绿色系为主，与主题一致）
const List<Color> chartColors = [
  Color(0xFF2E7D5B),
  Color(0xFF66BB6A),
  Color(0xFF9CCC65),
  Color(0xFF26A69A),
  Color(0xFF42A5F5),
  Color(0xFF7986CB),
  Color(0xFFAB47BC),
  Color(0xFFEC407A),
  Color(0xFFFF7043),
  Color(0xFFFFA726),
  Color(0xFF8D6E63),
  Color(0xFF78909C),
];

/// 统计报表：月度趋势柱状图 + 分类占比环形图 + 上月对比
class StatsPage extends StatefulWidget {
  const StatsPage({super.key});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  Widget build(BuildContext context) {
    final appData = context.watch<AppData>();
    final key = monthKey(_month);
    return Scaffold(
      appBar: AppBar(title: const Text('统计'), centerTitle: true),
      body: SafeArea(
        child: Column(
          children: [
            MonthSwitcher(
              month: _month,
              onChanged: (m) => setState(() => _month = m),
            ),
            Expanded(
              child: _StatsBody(
                key: ValueKey('${appData.revision}_$key'),
                month: _month,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsData {
  final int currentTotal;
  final int prevTotal;
  final List<String> recentMonths; // 近 6 个月 key（升序）
  final List<int> recentTotals;
  final List<CategoryTotal> categoryTotals;

  const _StatsData({
    required this.currentTotal,
    required this.prevTotal,
    required this.recentMonths,
    required this.recentTotals,
    required this.categoryTotals,
  });
}

class _StatsBody extends StatefulWidget {
  const _StatsBody({super.key, required this.month});

  final DateTime month;

  @override
  State<_StatsBody> createState() => _StatsBodyState();
}

class _StatsBodyState extends State<_StatsBody> {
  late Future<_StatsData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_StatsData> _load() async {
    final helper = DatabaseHelper.instance;
    final key = monthKey(widget.month);
    final prevKey = monthKey(
      DateTime(widget.month.year, widget.month.month - 1),
    );
    final monthTotals = await helper.fetchMonthTotals(24);
    final catTotals = await helper.fetchCategoryTotals(key);
    final months = <String>[];
    final totals = <int>[];
    for (var i = 5; i >= 0; i--) {
      final m = monthKey(DateTime(widget.month.year, widget.month.month - i));
      months.add(m);
      totals.add(monthTotals[m] ?? 0);
    }
    return _StatsData(
      currentTotal: monthTotals[key] ?? 0,
      prevTotal: monthTotals[prevKey] ?? 0,
      recentMonths: months,
      recentTotals: totals,
      categoryTotals: catTotals,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<_StatsData>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
          children: [
            _summaryCard(theme, data),
            const SizedBox(height: 12),
            _card(theme, '近 6 个月趋势', _barChart(theme, data)),
            const SizedBox(height: 12),
            _card(theme, '分类占比', _pieSection(theme, data)),
          ],
        );
      },
    );
  }

  Widget _summaryCard(ThemeData theme, _StatsData data) {
    Widget compare;
    if (data.currentTotal == 0 && data.prevTotal == 0) {
      compare = Text(
        '暂无支出',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    } else if (data.prevTotal == 0) {
      compare = Text(
        '上月无支出',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    } else {
      final diff = data.currentTotal - data.prevTotal;
      final percent = diff * 100.0 / data.prevTotal;
      final rising = diff > 0;
      final color = diff == 0
          ? theme.colorScheme.onSurfaceVariant
          : (rising ? theme.colorScheme.error : const Color(0xFF2E7D5B));
      compare = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (diff != 0)
            Icon(
              rising ? Icons.arrow_upward : Icons.arrow_downward,
              size: 16,
              color: color,
            ),
          const SizedBox(width: 2),
          Text(
            diff == 0
                ? '与上月持平'
                : '较上月 ${rising ? '+' : ''}${percent.toStringAsFixed(1)}%',
            style: theme.textTheme.bodySmall?.copyWith(color: color),
          ),
        ],
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '本月支出',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '¥${formatYuan(data.currentTotal)}',
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: theme.colorScheme.onPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '上月 ¥${formatYuan(data.prevTotal)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Theme(
                data: theme.copyWith(
                  textTheme: theme.textTheme.apply(
                    bodyColor: theme.colorScheme.onPrimary,
                  ),
                ),
                child: compare,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _card(ThemeData theme, String title, Widget child) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _barChart(ThemeData theme, _StatsData data) {
    final maxTotal = data.recentTotals.fold<int>(0, (a, b) => a > b ? a : b);
    final interval = _niceInterval(maxTotal);
    return SizedBox(
      height: 190,
      child: BarChart(
        BarChartData(
          maxY: maxTotal * 1.2 + 100,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: interval,
          ),
          borderData: FlBorderData(show: false),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
                '${data.recentMonths[group.x]}\n¥${formatYuan(rod.toY.round())}',
                const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 46,
                interval: interval,
                getTitlesWidget: (value, meta) => Text(
                  formatYuan(value.round()),
                  style: const TextStyle(fontSize: 10),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= data.recentMonths.length) {
                    return const SizedBox.shrink();
                  }
                  final m = data.recentMonths[i]; // 'yyyy-MM'
                  final monthNum = int.tryParse(m.substring(5)) ?? 0;
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '$monthNum月',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: i == data.recentMonths.length - 1
                            ? FontWeight.w700
                            : FontWeight.normal,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < data.recentTotals.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: data.recentTotals[i].toDouble(),
                    width: 18,
                    color: i == data.recentTotals.length - 1
                        ? theme.colorScheme.primary
                        : theme.colorScheme.primary.withValues(alpha: 0.35),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  /// y 轴刻度间隔：取一个不超过最大值/4 的整数（分）
  double _niceInterval(int maxTotal) {
    if (maxTotal <= 0) return 100;
    final rough = maxTotal / 4;
    final magnitude = 10.0;
    var interval = (rough / magnitude).ceil() * magnitude;
    if (interval <= 0) interval = magnitude;
    return interval.toDouble();
  }

  Widget _pieSection(ThemeData theme, _StatsData data) {
    final appData = context.watch<AppData>();
    if (data.currentTotal == 0 || data.categoryTotals.isEmpty) {
      return SizedBox(
        height: 100,
        child: Center(
          child: Text(
            '本月暂无支出',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
    return Column(
      children: [
        SizedBox(
          height: 180,
          child: Stack(
            children: [
              PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 52,
                  sections: [
                    for (var i = 0; i < data.categoryTotals.length; i++)
                      PieChartSectionData(
                        value: data.categoryTotals[i].totalCents.toDouble(),
                        color: chartColors[i % chartColors.length],
                        radius: 46,
                        showTitle: false,
                      ),
                  ],
                ),
              ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '合计',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      '¥${formatYuan(data.currentTotal)}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < data.categoryTotals.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: chartColors[i % chartColors.length],
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  appData.categoryOf(data.categoryTotals[i].categoryId)?.icon ??
                      '📦',
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    appData
                            .categoryOf(data.categoryTotals[i].categoryId)
                            ?.name ??
                        '已删分类',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                Text(
                  '${data.categoryTotals[i].count}笔',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '¥${formatYuan(data.categoryTotals[i].totalCents)}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 44,
                  child: Text(
                    '${(data.categoryTotals[i].totalCents * 100.0 / data.currentTotal).toStringAsFixed(1)}%',
                    textAlign: TextAlign.right,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
