import 'package:flutter_test/flutter_test.dart';
import 'package:qingjizhang/models/category.dart';
import 'package:qingjizhang/models/expense_record.dart';

void main() {
  group('formatYuan', () {
    test('两位小数正常显示', () {
      expect(formatYuan(1250), '12.50');
      expect(formatYuan(5), '0.05');
    });

    test('整元省略小数部分', () {
      expect(formatYuan(1200), '12');
      expect(formatYuan(0), '0');
    });
  });

  group('ExpenseRecord', () {
    test('序列化往返一致', () {
      final record = ExpenseRecord(
        id: 1,
        amountCents: 3050,
        categoryId: 2,
        date: DateTime(2026, 10, 20),
        note: '午饭',
        createdAt: DateTime(2026, 10, 20, 12, 30),
      );
      final restored = ExpenseRecord.fromMap(record.toMap());
      expect(restored.id, 1);
      expect(restored.amountCents, 3050);
      expect(restored.categoryId, 2);
      expect(restored.dateKey, '2026-10-20');
      expect(restored.monthKey, '2026-10');
      expect(restored.note, '午饭');
    });

    test('copyWith 只覆盖指定字段', () {
      final record = ExpenseRecord(
        id: 1,
        amountCents: 100,
        categoryId: 2,
        date: DateTime(2026, 10, 20),
        note: '原备注',
        createdAt: DateTime(2026, 10, 20),
      );
      final updated = record.copyWith(amountCents: 200);
      expect(updated.amountCents, 200);
      expect(updated.note, '原备注');
      expect(updated.categoryId, 2);
    });
  });

  group('Category', () {
    test('序列化往返一致', () {
      const category = Category(
          id: 3, name: '餐饮', icon: '🍜', sortOrder: 1, isPreset: true);
      final restored = Category.fromMap(category.toMap());
      expect(restored.id, 3);
      expect(restored.name, '餐饮');
      expect(restored.icon, '🍜');
      expect(restored.sortOrder, 1);
      expect(restored.isPreset, true);
    });
  });
}
