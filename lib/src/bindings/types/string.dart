import 'dart:ffi';

import 'package:ffi/ffi.dart';

/// Copies native UTF-8 text into Dart; the caller retains pointer ownership.
extension DartString on Pointer<Char> {
  String toDartString() => cast<Utf8>().toDartString();
}

/// Converts Dart strings into UTF-8 pointers owned by [arena].
extension NativeString on String? {
  Pointer<Char> toNativeChar(Arena arena, String name) {
    final value = this;
    if (value == null) return nullptr.cast<Char>();
    if (value.contains('\u0000')) {
      throw ArgumentError.value(value, name, 'Must not contain a NUL byte');
    }
    return value.toNativeUtf8(allocator: arena).cast<Char>();
  }
}
