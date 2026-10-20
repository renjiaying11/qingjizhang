import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../db/database_helper.dart';
import '../models/category.dart';
import '../models/expense_record.dart';
import '../providers/app_data.dart';
import '../utils/date_util.dart';
import '../widgets/category_picker.dart';
import '../widgets/number_pad.dart';

/// 记一笔：数字键盘 + 分类九宫格 + 日期/备注，3 秒完成一笔记账
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _input = '0';
  int? _categoryId;
  DateTime _date = DateTime.now();
  final TextEditingController _noteController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  int get _amountCents => ((double.tryParse(_input) ?? 0) * 100).round();

  void _onKey(String key) {
    setState(() {
      if (key == '.') {
        if (!_input.contains('.')) _input += '.';
        return;
      }
      if (_input == '0') {
        _input = key;
        return;
      }
      final dotIndex = _input.indexOf('.');
      if (dotIndex >= 0) {
        if (_input.length - dotIndex - 1 >= 2) return; // 小数最多 2 位
      } else if (_input.length >= 9) {
        return; // 整数最多 9 位
      }
      _input += key;
    });
  }

  void _onDelete() {
    setState(() {
      _input = _input.length <= 1
          ? '0'
          : _input.substring(0, _input.length - 1);
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (_saving) return;
    final appData = context.read<AppData>();
    final messenger = ScaffoldMessenger.of(context);
    final cents = _amountCents;
    if (cents <= 0) {
      messenger.showSnackBar(const SnackBar(content: Text('请先输入金额')));
      return;
    }
    Category? category = appData.categoryOf(_categoryId ?? -1);
    category ??= appData.categories.isNotEmpty
        ? appData.categories.first
        : null;
    if (category?.id == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('暂无可用分类，请先在「我的-分类管理」中添加')),
      );
      return;
    }
    setState(() => _saving = true);
    await DatabaseHelper.instance.insertRecord(
      ExpenseRecord(
        amountCents: cents,
        categoryId: category!.id!,
        date: _date,
        note: _noteController.text.trim(),
        createdAt: DateTime.now(),
      ),
    );
    await appData.dataChanged();
    if (!mounted) return;
    setState(() {
      _saving = false;
      _input = '0';
      _date = DateTime.now();
      _noteController.clear();
    });
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          '已记录：${category.icon} ${category.name}  ¥${formatYuan(cents)}',
        ),
        duration: const Duration(milliseconds: 900),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appData = context.watch<AppData>();
    final theme = Theme.of(context);
    final selected =
        appData.categoryOf(_categoryId ?? -1) ??
        (appData.categories.isNotEmpty ? appData.categories.first : null);

    return Scaffold(
      appBar: AppBar(title: const Text('记一笔'), centerTitle: true),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            children: [
              // 上部内容区：空间不足（小屏/横屏）时可整体滚动
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // 金额展示卡片
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer,
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                selected?.icon ?? '📦',
                                style: const TextStyle(fontSize: 24),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    selected?.name ?? '未选分类',
                                    style: theme.textTheme.labelMedium
                                        ?.copyWith(
                                          color: theme
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                  ),
                                  Text(
                                    '¥ $_input',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.headlineMedium
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      // 日期 + 备注
                      Row(
                        children: [
                          InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: _pickDate,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    theme.colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.calendar_today,
                                    size: 14,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${formatMonthDay(_date)} ${weekdayName(_date)}',
                                    style: theme.textTheme.labelMedium,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _noteController,
                              maxLength: 30,
                              decoration: const InputDecoration(
                                hintText: '备注（可选）',
                                counterText: '',
                                isDense: true,
                                border: UnderlineInputBorder(),
                              ),
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // 分类九宫格
                      CategoryPicker(
                        categories: appData.categories,
                        selectedId: selected?.id,
                        onSelected: (c) => setState(() => _categoryId = c.id),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // 数字键盘
              Expanded(
                child: NumberPad(
                  onKey: _onKey,
                  onDelete: _onDelete,
                  onSave: _saving ? () {} : _save,
                  saveText: _saving ? '保存中…' : '保存',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
