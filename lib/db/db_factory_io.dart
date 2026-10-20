import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const String _dbName = 'qingjizhang.db';

Future<DatabaseFactory> resolveDatabaseFactory() async {
  // iOS 真机走 sqflite 原生实现
  if (Platform.isIOS || Platform.isAndroid || Platform.isMacOS) {
    return sqflite.databaseFactory;
  }
  // 桌面平台走 FFI（便于本地开发调试）
  sqfliteFfiInit();
  return databaseFactoryFfi;
}

Future<String> resolveDbPath() async {
  if (Platform.isIOS || Platform.isAndroid || Platform.isMacOS) {
    final dir = await sqflite.getDatabasesPath();
    return p.join(dir, _dbName);
  }
  final dir = await getApplicationDocumentsDirectory();
  return p.join(dir.path, _dbName);
}
