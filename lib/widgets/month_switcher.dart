import 'package:flutter/material.dart';

import '../utils/date_util.dart';

/// 月份切换器：‹ 2026年10月 ›（不可切到未来月份）
class MonthSwitcher extends StatelessWidget {
  const MonthSwitcher({
    super.key,
    required this.month,
    required this.onChanged,
  });

  final DateTime month; // 当月 1 号
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final canNext = !DateTime(
      month.year,
      month.month + 1,
    ).isAfter(DateTime(now.year, now.month));
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => onChanged(DateTime(month.year, month.month - 1)),
        ),
        Text(
          monthLabel(month),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: canNext
              ? () => onChanged(DateTime(month.year, month.month + 1))
              : null,
        ),
      ],
    );
  }
}
