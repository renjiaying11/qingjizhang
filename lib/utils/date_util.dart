// 日期显示工具（手动拼接，避免 intl locale 初始化依赖）

const List<String> _weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

String weekdayName(DateTime date) => _weekdays[date.weekday - 1];

/// 10月20日
String formatMonthDay(DateTime date) => '${date.month}月${date.day}日';

/// 2026年10月20日 周一
String formatFullDate(DateTime date) =>
    '${date.year}年${date.month}月${date.day}日 ${weekdayName(date)}';

/// 2026年10月
String monthLabel(DateTime month) => '${month.year}年${month.month}月';

/// yyyy-MM，与数据库 date 字段前缀匹配
String monthKey(DateTime month) =>
    '${month.year.toString().padLeft(4, '0')}-${month.month.toString().padLeft(2, '0')}';
