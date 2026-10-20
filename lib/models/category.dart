/// 支出分类
class Category {
  final int? id;
  final String name;
  final String icon; // emoji 图标
  final int sortOrder;
  final bool isPreset; // 预设分类（「其他」不可删除）

  const Category({
    this.id,
    required this.name,
    required this.icon,
    this.sortOrder = 0,
    this.isPreset = false,
  });

  Category copyWith({String? name, String? icon, int? sortOrder}) {
    return Category(
      id: id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      sortOrder: sortOrder ?? this.sortOrder,
      isPreset: isPreset,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'sort_order': sortOrder,
      'is_preset': isPreset ? 1 : 0,
    };
  }

  factory Category.fromMap(Map<String, Object?> map) {
    return Category(
      id: map['id'] as int?,
      name: map['name'] as String? ?? '',
      icon: map['icon'] as String? ?? '📦',
      sortOrder: (map['sort_order'] as int?) ?? 0,
      isPreset: ((map['is_preset'] as int?) ?? 0) == 1,
    );
  }
}
