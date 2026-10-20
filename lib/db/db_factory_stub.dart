import 'package:sqflite_common/sqflite.dart';

/// 兜底实现：不支持的平台直接报错，避免静默失败
Future<DatabaseFactory> resolveDatabaseFactory() async =>
    throw UnsupportedError('当前平台不支持数据库');

Future<String> resolveDbPath() async => throw UnsupportedError('当前平台不支持数据库');
