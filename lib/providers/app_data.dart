import 'package:flutter/foundation.dart' hide Category;

import '../db/database_helper.dart';
import '../models/category.dart';

/// 全局应用数据：分类列表 + 数据版本号（驱动各页面刷新）
class AppData extends ChangeNotifier {
  AppData() {
    loadCategories();
  }

  List<Category> categories = [];

  /// 数据版本号：任何写操作后自增，数据页以此作为重建 key 触发重新查询
  int revision = 0;

  Map<int, Category> get categoryMap => {
    for (final c in categories)
      if (c.id != null) c.id!: c,
  };

  Category? categoryOf(int id) => categoryMap[id];

  Future<void> loadCategories() async {
    categories = await DatabaseHelper.instance.fetchCategories();
    notifyListeners();
  }

  /// 增删改记录/分类后调用
  Future<void> dataChanged() async {
    categories = await DatabaseHelper.instance.fetchCategories();
    revision++;
    notifyListeners();
  }
}
