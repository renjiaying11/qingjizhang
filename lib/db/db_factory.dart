// 按平台条件导出数据库工厂：
// - iOS/Android → sqflite 原生实现
// - Windows/Linux/macOS 桌面 → sqflite_common_ffi
// - Web（仅本地预览用）→ sqflite_common_ffi_web
export 'db_factory_stub.dart'
    if (dart.library.io) 'db_factory_io.dart'
    if (dart.library.js_interop) 'db_factory_web.dart';
