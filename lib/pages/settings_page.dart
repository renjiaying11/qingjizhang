import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../db/database_helper.dart';
import '../providers/app_data.dart';
import '../utils/date_util.dart';
import 'category_manage_page.dart';

/// 我的：分类管理、CSV 导出、备份恢复、关于
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Future<void> _shareBytes(
    ScaffoldMessengerState messenger,
    Uint8List bytes,
    String fileName,
    String mimeType,
  ) async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(bytes, name: fileName, mimeType: mimeType)],
          text: fileName,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('导出失败：$e')));
    }
  }

  Future<void> _exportCsv(BuildContext context, {String? month}) async {
    final messenger = ScaffoldMessenger.of(context);
    final csv = await DatabaseHelper.instance.buildCsv(month: month);
    final name = month == null ? '轻记账_全部.csv' : '轻记账_$month.csv';
    await _shareBytes(messenger, utf8.encode(csv), name, 'text/csv');
  }

  Future<void> _exportBackup(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final json = await DatabaseHelper.instance.buildBackupJson();
    await _shareBytes(
      messenger,
      utf8.encode(json),
      '轻记账_备份.json',
      'application/json',
    );
  }

  Future<void> _restoreBackup(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!context.mounted) return;

      var text = utf8.decode(bytes);
      // 剥掉可能存在的 UTF-8 BOM（0xFEFF）
      if (text.isNotEmpty && text.codeUnitAt(0) == 0xFEFF) {
        text = text.substring(1);
      }

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('恢复备份'),
          content: const Text('恢复将替换当前全部数据，且不可撤销。确定继续吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('恢复'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;

      await DatabaseHelper.instance.restoreBackupJson(text);
      if (context.mounted) {
        await context.read<AppData>().dataChanged();
        messenger.showSnackBar(const SnackBar(content: Text('恢复成功')));
      }
    } on FormatException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('恢复失败：$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    return Scaffold(
      appBar: AppBar(title: const Text('我的'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _sectionCard(theme, [
            ListTile(
              leading: const Icon(Icons.category_outlined),
              title: const Text('分类管理'),
              subtitle: const Text('增删改、拖动排序'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CategoryManagePage()),
              ),
            ),
          ]),
          _sectionCard(theme, [
            ListTile(
              leading: const Icon(Icons.table_view_outlined),
              title: const Text('导出 CSV'),
              subtitle: Text(monthLabel(now)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _exportCsv(context, month: monthKey(now)),
            ),
            ListTile(
              leading: const Icon(Icons.table_view_outlined),
              title: const Text('导出 CSV'),
              subtitle: const Text('全部记录'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _exportCsv(context),
            ),
            ListTile(
              leading: const Icon(Icons.backup_outlined),
              title: const Text('导出备份'),
              subtitle: const Text('JSON 全量备份，用于迁移或恢复数据'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _exportBackup(context),
            ),
            ListTile(
              leading: const Icon(Icons.restore),
              title: const Text('恢复备份'),
              subtitle: const Text('选择备份文件，替换当前数据'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _restoreBackup(context),
            ),
          ]),
          _sectionCard(theme, [
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('关于轻记账'),
              subtitle: const Text('v1.0.0 · 数据仅存本机，不出手机'),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _sectionCard(ThemeData theme, List<Widget> children) {
    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}
