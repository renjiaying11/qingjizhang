import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../db/database_helper.dart';
import '../models/category.dart';
import '../providers/app_data.dart';

/// 分类管理：新增、编辑、删除、拖动排序。「其他」为兜底分类不可删。
class CategoryManagePage extends StatelessWidget {
  const CategoryManagePage({super.key});

  static const _emojiOptions = [
    '🍜',
    '🍔',
    '🍺',
    '☕',
    '🍰',
    '🚌',
    '🚗',
    '⛽',
    '🛒',
    '👕',
    '📱',
    '🏠',
    '💡',
    '🛋️',
    '🎮',
    '🎬',
    '🎵',
    '⛰️',
    '✈️',
    '💊',
    '🏥',
    '📚',
    '✏️',
    '🎁',
    '💰',
    '🐱',
    '🧻',
    '🧴',
    '💇',
    '🏋️',
    '🌐',
    '📦',
  ];

  Future<void> _showEditDialog(
    BuildContext context, {
    Category? existing,
  }) async {
    final theme = Theme.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final nameController = TextEditingController(text: existing?.name ?? '');
    final emojiController = TextEditingController(text: existing?.icon ?? '');

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existing == null ? '新增分类' : '编辑分类'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  maxLength: 6,
                  decoration: const InputDecoration(
                    labelText: '名称',
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: emojiController,
                  maxLength: 4,
                  decoration: const InputDecoration(
                    labelText: '图标（emoji）',
                    counterText: '',
                  ),
                  onChanged: (_) => setDialogState(() {}),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final emoji in _emojiOptions)
                      InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () =>
                            setDialogState(() => emojiController.text = emoji),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: emojiController.text == emoji
                                  ? theme.colorScheme.primary
                                  : Colors.transparent,
                            ),
                          ),
                          child: Text(
                            emoji,
                            style: const TextStyle(fontSize: 20),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) {
                  messenger.showSnackBar(
                    const SnackBar(content: Text('请输入分类名称')),
                  );
                  return;
                }
                final icon = emojiController.text.trim().isEmpty
                    ? '📦'
                    : emojiController.text.trim();
                final helper = DatabaseHelper.instance;
                final appData = Provider.of<AppData>(
                  dialogContext,
                  listen: false,
                );
                final duplicated = appData.categories.any(
                  (c) => c.name == name && c.id != existing?.id,
                );
                if (duplicated) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('已存在分类「$name」')),
                  );
                  return;
                }
                if (existing == null) {
                  final maxSort = appData.categories.isEmpty
                      ? 0
                      : appData.categories
                                .map((c) => c.sortOrder)
                                .reduce((a, b) => a > b ? a : b) +
                            1;
                  await helper.insertCategory(
                    Category(name: name, icon: icon, sortOrder: maxSort),
                  );
                } else {
                  await helper.updateCategory(
                    existing.copyWith(name: name, icon: icon),
                  );
                }
                await appData.dataChanged();
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
    nameController.dispose();
    emojiController.dispose();
  }

  Future<void> _delete(BuildContext context, Category category) async {
    if (category.id == null) return;
    final helper = DatabaseHelper.instance;
    final appData = context.read<AppData>();
    final messenger = ScaffoldMessenger.of(context);
    final count = await helper.recordCountOfCategory(category.id!);
    if (!context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除分类'),
        content: Text(
          count > 0
              ? '分类「${category.name}」下有 $count 笔记录，删除后将归入「其他」。'
              : '确定删除分类「${category.name}」吗？',
        ),
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
    );
    if (confirmed != true) return;
    final ok = await helper.deleteCategory(category.id!);
    await appData.dataChanged();
    messenger.showSnackBar(SnackBar(content: Text(ok ? '已删除' : '删除失败')));
  }

  @override
  Widget build(BuildContext context) {
    final appData = context.watch<AppData>();
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('分类管理')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showEditDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('新增分类'),
      ),
      body: appData.categories.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ReorderableListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 88),
              itemCount: appData.categories.length,
              // onReorderItem 的 newIndex 已由框架补偿移除项，无需手动调整
              onReorderItem: (oldIndex, newIndex) async {
                final list = [...appData.categories];
                final moved = list.removeAt(oldIndex);
                list.insert(newIndex, moved);
                final helper = DatabaseHelper.instance;
                for (var i = 0; i < list.length; i++) {
                  await helper.updateCategory(list[i].copyWith(sortOrder: i));
                }
                await appData.dataChanged();
              },
              itemBuilder: (context, index) {
                final category = appData.categories[index];
                return Card(
                  key: ValueKey('cat_${category.id}'),
                  margin: const EdgeInsets.symmetric(vertical: 3),
                  elevation: 0,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                      child: Text(
                        category.icon,
                        style: const TextStyle(fontSize: 20),
                      ),
                    ),
                    title: Text(category.name),
                    subtitle: category.isPreset ? const Text('预置') : null,
                    trailing: category.name == '其他'
                        ? null
                        : PopupMenuButton<String>(
                            onSelected: (action) {
                              if (action == 'edit') {
                                _showEditDialog(context, existing: category);
                              } else if (action == 'delete') {
                                _delete(context, category);
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'edit', child: Text('编辑')),
                              PopupMenuItem(value: 'delete', child: Text('删除')),
                            ],
                          ),
                  ),
                );
              },
            ),
    );
  }
}
