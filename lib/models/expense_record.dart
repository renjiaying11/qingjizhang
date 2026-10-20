import 'package:intl/intl.dart';

/// 一笔支出记录
///
/// 金额以「整数分」存储（¥12.50 → 1250），避免浮点精度问题。
class ExpenseRecord {
  final int? id;
  final int amountCents;
  final int categoryId;
  final DateTime date; // 记账日期（只关心年月日）
  final String note;
  final DateTime createdAt;

  const ExpenseRecord({
    this.id,
    required this.amountCents,
    required this.categoryId,
    required this.date,
    this.note = '',
    required this.createdAt,
  });

  double get amountYuan => amountCents / 100;

  /// yyyy-MM-dd，用于数据库存储与分组
  String get dateKey => DateFormat('yyyy-MM-dd').format(date);

  /// yyyy-MM，用于按月筛选
  String get monthKey => DateFormat('yyyy-MM').format(date);

  ExpenseRecord copyWith({
    int? amountCents,
    int? categoryId,
    DateTime? date,
    String? note,
  }) {
    return ExpenseRecord(
      id: id,
      amountCents: amountCents ?? this.amountCents,
      categoryId: categoryId ?? this.categoryId,
      date: date ?? this.date,
      note: note ?? this.note,
      createdAt: createdAt,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'amount_cents': amountCents,
      'category_id': categoryId,
      'date': dateKey,
      'note': note,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  factory ExpenseRecord.fromMap(Map<String, Object?> map) {
    return ExpenseRecord(
      id: map['id'] as int?,
      amountCents: (map['amount_cents'] as int?) ?? 0,
      categoryId: (map['category_id'] as int?) ?? 0,
      date: DateFormat('yyyy-MM-dd').parse(map['date'] as String? ?? ''),
      note: map['note'] as String? ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (map['created_at'] as int?) ?? 0,
      ),
    );
  }
}

/// 金额格式化：1250 → "12.50"，整元省略小数（1200 → "12"）
String formatYuan(int cents) {
  final text = (cents / 100).toStringAsFixed(2);
  return text.endsWith('.00') ? text.substring(0, text.length - 3) : text;
}
