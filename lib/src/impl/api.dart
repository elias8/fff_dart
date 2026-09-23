/// Internal library for FFF's idiomatic Dart API.
///
/// Feature parts share private native handles without exposing them publicly.
library;

import 'dart:ffi' show Finalizable;
import 'dart:io' show FileSystemEntity;

import '../bindings/file_finder.dart' as bindings;
import '../bindings/types/result.dart' show FffException;

export '../bindings/types/result.dart' show FffException;

part 'file_finder.dart';
