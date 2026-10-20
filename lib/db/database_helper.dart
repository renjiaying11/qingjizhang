import 'dart:convert';

import 'package:sqflite_common/sqflite.dart';

import '../models/category.dart';
import '../models/expense_record.dart';
import 'db_factory.dart';

/// 分类聚合结果
class CategoryTotal {
  final int categoryId;
  final int totalCents;
  final int count;

  const CategoryTotal({
    required this.categoryId,
    required this.totalCents,
    required this.count,
  });
}

/// 本地数据库封装（单例）
///
/// 两张表：categories（分类）、expense_records（支出记录）。
/// 金额一律以整数分存储，聚合用 SQL SUM 精确计算。
class DatabaseHelper {
  DatabaseHelper._();

  static final DatabaseHelper instance = DatabaseHelper._();

  Database? _db;

  Future<Database> get database async => _db ??= await _open();

  Future<Database> _open() async {
    final factory = await resolveDatabaseFactory();
    final path = await resolveDbPath();
    return factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: _onCreate,
      ),
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        icon TEXT NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0,
        is_preset INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE expense_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount_cents INTEGER NOT NULL,
        category_id INTEGER NOT NULL,
        date TEXT NOT NULL,
        note TEXT NOT NULL DEFAULT '',
        created_at INTEGER NOT NULL,
        FOREIGN KEY (category_id) REFERENCES categories (id)
      )
    ''');
    await db.execute('CREATE INDEX idx_records_date ON expense_records (date)');
    await db.execute(
      'CREATE INDEX idx_records_category ON expense_records (category_id)',
    );

    // 预置默认分类
    const defaults = [
      ('餐饮', '🍜'),
      ('交通', '🚌'),
      ('购物', '🛒'),
      ('居住', '🏠'),
      ('娱乐', '🎮'),
      ('医疗', '💊'),
      ('学习', '📚'),
      ('人情', '🎁'),
      ('日用', '🧻'),
      ('其他', '📦'),
    ];
    final batch = db.batch();
    for (var i = 0; i < defaults.length; i++) {
      final map = Category(
        name: defaults[i].$1,
        icon: defaults[i].$2,
        sortOrder: i,
        isPreset: true,
      ).toMap()..remove('id');
      batch.insert('categories', map);
    }
    await batch.commit(noResult: true);
  }

  // ---------- 分类 ----------

  Future<List<Category>> fetchCategories() async {
    final db = await database;
    final rows = await db.query(
      'categories',
      orderBy: 'sort_order ASC, id ASC',
    );
    return rows.map(Category.fromMap).toList();
  }

  Future<int> insertCategory(Category category) async {
    final db = await database;
    final map = category.toMap()..remove('id');
    return db.insert('categories', map);
  }

  Future<void> updateCategory(Category category) async {
    if (category.id == null) return;
    final db = await database;
    await db.update(
      'categories',
      category.toMap(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  /// 删除分类；其下记录自动归入「其他」。
  /// 「其他」本身不可删除。返回是否删除成功。
  Future<bool> deleteCategory(int id) async {
    final db = await database;
    final rows = await db.query('categories', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return false;
    final target = Category.fromMap(rows.first);
    if (target.name == '其他') return false;

    final otherRows = await db.query(
      'categories',
      where: "name = '其他'",
      limit: 1,
    );
    if (otherRows.isEmpty) return false;
    final otherId = otherRows.first['id'] as int;

    await db.transaction((txn) async {
      await txn.update(
        'expense_records',
        {'category_id': otherId},
        where: 'category_id = ?',
        whereArgs: [id],
      );
      await txn.delete('categories', where: 'id = ?', whereArgs: [id]);
    });
    return true;
  }

  Future<int> recordCountOfCategory(int categoryId) async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS cnt FROM expense_records WHERE category_id = ?',
      [categoryId],
    );
    return (rows.first['cnt'] as int?) ?? 0;
  }

  // ---------- 支出记录 ----------

  Future<int> insertRecord(ExpenseRecord record) async {
    final db = await database;
    final map = record.toMap()..remove('id');
    return db.insert('expense_records', map);
  }

  Future<void> updateRecord(ExpenseRecord record) async {
    if (record.id == null) return;
    final db = await database;
    await db.update(
      'expense_records',
      record.toMap(),
      where: 'id = ?',
      whereArgs: [record.id],
    );
  }

  Future<void> deleteRecord(int id) async {
    final db = await database;
    await db.delete('expense_records', where: 'id = ?', whereArgs: [id]);
  }

  /// 查询记录（日期倒序）。month 格式 yyyy-MM，categoryId 可选。
  Future<List<ExpenseRecord>> fetchRecords({
    String? month,
    int? categoryId,
  }) async {
    final db = await database;
    final conditions = <String>[];
    final args = <Object?>[];
    if (month != null && month.isNotEmpty) {
      conditions.add('date LIKE ?');
      args.add('$month-%');
    }
    if (categoryId != null) {
      conditions.add('category_id = ?');
      args.add(categoryId);
    }
    final rows = await db.query(
      'expense_records',
      where: conditions.isEmpty ? null : conditions.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'date DESC, id DESC',
    );
    return rows.map(ExpenseRecord.fromMap).toList();
  }

  /// 某月每日合计：{'2026-10-19': 3500, ...}
  Future<Map<String, int>> fetchDailyTotals(String month) async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT date, SUM(amount_cents) AS total FROM expense_records '
      'WHERE date LIKE ? GROUP BY date',
      ['$month-%'],
    );
    return {
      for (final r in rows) r['date'] as String: (r['total'] as int?) ?? 0,
    };
  }

  /// 有记录的月份合计（倒序，最多 limit 个月）：{'2026-10': 12000, ...}
  Future<Map<String, int>> fetchMonthTotals(int limit) async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT substr(date, 1, 7) AS ym, SUM(amount_cents) AS total '
      'FROM expense_records GROUP BY ym ORDER BY ym DESC LIMIT ?',
      [limit],
    );
    return {for (final r in rows) r['ym'] as String: (r['total'] as int?) ?? 0};
  }

  /// 某月分类合计（金额降序）
  Future<List<CategoryTotal>> fetchCategoryTotals(String month) async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT category_id, SUM(amount_cents) AS total, COUNT(*) AS cnt '
      'FROM expense_records WHERE date LIKE ? '
      'GROUP BY category_id ORDER BY total DESC',
      ['$month-%'],
    );
    return rows
        .map(
          (r) => CategoryTotal(
            categoryId: (r['category_id'] as int?) ?? 0,
            totalCents: (r['total'] as int?) ?? 0,
            count: (r['cnt'] as int?) ?? 0,
          ),
        )
        .toList();
  }

  // ---------- 导出 / 备份 ----------

  /// 生成 CSV 内容（带 BOM，Excel 可直接打开中文）
  Future<String> buildCsv({String? month}) async {
    final records = await fetchRecords(month: month);
    final categories = {for (final c in await fetchCategories()) c.id: c};
    // 0xFEFF 即 UTF-8 BOM，保证 Excel 直接打开中文不乱码
    final buffer = StringBuffer(String.fromCharCode(0xFEFF));
    buffer.writeln('日期,分类,金额(元),备注');
    for (final r in records) {
      final catName = categories[r.categoryId]?.name ?? '未知';
      buffer.writeln(
        '${r.dateKey},${_csvEscape(catName)},${r.amountCents / 100},${_csvEscape(r.note)}',
      );
    }
    return buffer.toString();
  }

  static String _csvEscape(String field) {
    if (field.contains(',') || field.contains('"') || field.contains('\n')) {
      return '"${field.replaceAll('"', '""')}"';
    }
    return field;
  }

  /// 全量 JSON 备份
  Future<String> buildBackupJson() async {
    final db = await database;
    final categories = await db.query(
      'categories',
      orderBy: 'sort_order ASC, id ASC',
    );
    final records = await db.query(
      'expense_records',
      orderBy: 'date ASC, id ASC',
    );
    return jsonEncode({
      'app': 'qingjizhang',
      'version': 1,
      'exported_at': DateTime.now().toIso8601String(),
      'categories': categories,
      'records': records,
    });
  }

  /// 从 JSON 备份恢复（全量替换现有数据）
  Future<void> restoreBackupJson(String jsonStr) async {
    final data = jsonDecode(jsonStr);
    if (data is! Map || data['app'] != 'qingjizhang') {
      throw const FormatException('不是有效的轻记账备份文件');
    }
    final categories = data['categories'];
    final records = data['records'];
    if (categories is! List || records is! List) {
      throw const FormatException('备份文件结构不完整');
    }
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('expense_records');
      await txn.delete('categories');
      final batch = txn.batch();
      for (final c in categories) {
        if (c is Map) batch.insert('categories', Map<String, Object?>.from(c));
      }
      for (final r in records) {
        if (r is Map) {
          batch.insert('expense_records', Map<String, Object?>.from(r));
        }
      }
      await batch.commit(noResult: true);
    });
  }
}
