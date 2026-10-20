import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../db/database_helper.dart';
import '../models/expense_record.dart';
import '../providers/app_data.dart';
import '../utils/date_util.dart';
import '../widgets/edit_record_sheet.dart';
import '../widgets/month_switcher.dart';

/// 账单流水：按月筛选、按日分组、左滑删除、点击编辑
class RecordsPage extends StatefulWidget {
  const RecordsPage({super.key});

  @override
  State<RecordsPage> createState() => _RecordsPageState();
}

class _RecordsPageState extends State<RecordsPage> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  Widget build(BuildContext context) {
    final appData = context.watch<AppData>();
    final key = monthKey(_month);
    return Scaffold(
      appBar: AppBar(title: const Text('账单流水'), centerTitle: true),
      body: SafeArea(
        child: Column(
          children: [
            MonthSwitcher(
              month: _month,
              onChanged: (m) => setState(() => _month = m),
            ),
            Expanded(
              // revision 或月份变化 → key 变化 → 重建并重新查询
              child: _MonthRecords(
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

class _MonthRecordsData {
  final List<ExpenseRecord> records;
  final Map<String, int> dailyTotals;

  const _MonthRecordsData(this.records, this.dailyTotals);

  int get totalCents => records.fold(0, (sum, r) => sum + r.amountCents);
}

class _MonthRecords extends StatefulWidget {
  const _MonthRecords({super.key, required this.month});

  final DateTime month;

  @override
  State<_MonthRecords> createState() => _MonthRecordsState();
}

class _MonthRecordsState extends State<_MonthRecords> {
  late Future<_MonthRecordsData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_MonthRecordsData> _load() async {
    final key = monthKey(widget.month);
    final helper = DatabaseHelper.instance;
    final records = await helper.fetchRecords(month: key);
    final daily = await helper.fetchDailyTotals(key);
    return _MonthRecordsData(records, daily);
  }

  Future<bool> _confirmDelete(ExpenseRecord record) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('删除记录'),
            content: Text('确定删除这笔 ¥${formatYuan(record.amountCents)} 的支出吗？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('删除'),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final appData = context.watch<AppData>();
    final theme = Theme.of(context);
    return FutureBuilder<_MonthRecordsData>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data!;
        if (data.records.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🗒️', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 8),
                Text(
                  '本月暂无记录',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        }

        final children = <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '共 ${data.records.length} 笔',
                  style: theme.textTheme.bodySmall,
                ),
                Text(
                  '支出 ¥${formatYuan(data.totalCents)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ];

        String? lastDateKey;
        for (final record in data.records) {
          if (record.dateKey != lastDateKey) {
            lastDateKey = record.dateKey;
            final dayTotal = data.dailyTotals[record.dateKey] ?? 0;
            children.add(
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${formatMonthDay(record.date)} ${weekdayName(record.date)}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      '¥${formatYuan(dayTotal)}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          final category = appData.categoryOf(record.categoryId);
          children.add(
            Dismissible(
              key: ValueKey('record_${record.id}'),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 24),
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.error,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.delete_outline,
                  color: theme.colorScheme.onError,
                ),
              ),
              confirmDismiss: (_) => _confirmDelete(record),
              onDismissed: (_) async {
                await DatabaseHelper.instance.deleteRecord(record.id!);
                await appData.dataChanged();
              },
              child: Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      category?.icon ?? '📦',
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                  title: Text(
                    category?.name ?? '已删分类',
                    style: theme.textTheme.bodyLarge,
                  ),
                  subtitle: record.note.isEmpty
                      ? null
                      : Text(
                          record.note,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                  trailing: Text(
                    '¥${formatYuan(record.amountCents)}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  // 弹层内部保存/删除后会 dataChanged() 使 revision 递增，
                  // 外层 ValueKey 变化自动重建本页，无需手动刷新
                  onTap: () => EditRecordSheet.show(context, record),
                ),
              ),
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.only(bottom: 16),
          children: children,
        );
      },
    );
  }
}
