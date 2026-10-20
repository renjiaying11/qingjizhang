import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../db/database_helper.dart';
import '../models/expense_record.dart';
import '../providers/app_data.dart';
import '../utils/date_util.dart';
import 'category_picker.dart';

/// 编辑/删除已有记录的底部弹层
class EditRecordSheet extends StatefulWidget {
  const EditRecordSheet({super.key, required this.record});

  final ExpenseRecord record;

  /// 返回是否发生了变更（保存或删除）
  static Future<bool?> show(BuildContext context, ExpenseRecord record) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: EditRecordSheet(record: record),
      ),
    );
  }

  @override
  State<EditRecordSheet> createState() => _EditRecordSheetState();
}

class _EditRecordSheetState extends State<EditRecordSheet> {
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;
  late int _categoryId;
  late DateTime _date;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: formatYuan(widget.record.amountCents),
    );
    _noteController = TextEditingController(text: widget.record.note);
    _categoryId = widget.record.categoryId;
    _date = widget.record.date;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
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
    final yuan = double.tryParse(_amountController.text.trim());
    if (yuan == null || yuan <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请输入有效金额')));
      return;
    }
    setState(() => _saving = true);
    final updated = widget.record.copyWith(
      amountCents: (yuan * 100).round(),
      categoryId: _categoryId,
      date: _date,
      note: _noteController.text.trim(),
    );
    await DatabaseHelper.instance.updateRecord(updated);
    if (!mounted) return;
    await context.read<AppData>().dataChanged();
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  Future<void> _delete() async {
    if (widget.record.id == null || _saving) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除记录'),
        content: Text('确定删除这笔 ¥${formatYuan(widget.record.amountCents)} 的支出吗？'),
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
    setState(() => _saving = true);
    await DatabaseHelper.instance.deleteRecord(widget.record.id!);
    if (!mounted) return;
    await context.read<AppData>().dataChanged();
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final appData = context.watch<AppData>();
    final theme = Theme.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(
                '编辑记录',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: '金额（元）',
                prefixText: '¥ ',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 16),
            CategoryPicker(
              categories: appData.categories,
              selectedId: _categoryId,
              onSelected: (c) =>
                  setState(() => _categoryId = c.id ?? _categoryId),
            ),
            const SizedBox(height: 12),
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
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${formatMonthDay(_date)} ${weekdayName(_date)}',
                      style: theme.textTheme.labelMedium,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _noteController,
                    maxLength: 30,
                    decoration: const InputDecoration(
                      hintText: '备注',
                      counterText: '',
                      isDense: true,
                      border: UnderlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _saving ? null : _delete,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('删除'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                      minimumSize: const Size.fromHeight(46),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(46),
                    ),
                    child: Text(_saving ? '保存中…' : '保存修改'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
