import 'package:sqflite_common/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

/// Web 仅用于本地预览，数据落在浏览器 IndexedDB
Future<DatabaseFactory> resolveDatabaseFactory() async => databaseFactoryFfiWeb;

Future<String> resolveDbPath() async => 'qingjizhang.db';
