import 'dart:convert';
import 'dart:ffi';

import 'package:ffi/ffi.dart';

import '../ffi/fff.g.dart';
import 'types/health_check.dart';
import 'types/result.dart';
import 'types/string.dart';

HealthCheck healthCheck(int? handle, String? testPath) {
  return using((arena) {
    return decodeFffResult(
      () => fff_health_check(
        handle == null ? nullptr : Pointer<Void>.fromAddress(handle),
        testPath.toNativeChar(arena, 'testPath'),
      ),
      operationName: 'FileFinder.healthCheck',
      decodeSuccess: (envelope) {
        final json = envelope.handle.cast<Char>();
        if (json == nullptr) {
          throw StateError('FFF returned a null health-check payload');
        }
        try {
          return _decodeHealthCheck(json.toDartString());
        } finally {
          fff_free_string(json);
        }
      },
    );
  });
}

DatabaseHealth _decodeDatabaseHealth(_JsonObject value, String name) {
  final details = value.field<Map<String, Object?>?>(
    'db_healthcheck',
    path: name,
  );
  return DatabaseHealth(
    initialized: value.field<bool>('initialized', path: name),
    details: details == null
        ? null
        : _decodeDatabaseHealthDetails(
            _JsonObject(details),
            '$name.db_healthcheck',
          ),
    error: value.field<String?>('error', path: name),
  );
}

DatabaseHealthDetails _decodeDatabaseHealthDetails(
  _JsonObject value,
  String name,
) {
  return DatabaseHealthDetails(
    value.field<String>('path', path: name),
    value.field<int>('disk_size', path: name),
  );
}

HealthCheck _decodeHealthCheck(String json) {
  final root = _healthJsonObject(jsonDecode(json), 'health check');
  final git = root.object('git', path: 'health check');
  final picker = root.object('file_picker', path: 'health check');
  final frecency = root.object('frecency', path: 'health check');
  final queryTracker = root.object('query_tracker', path: 'health check');

  return HealthCheck(
    root.field<String>('version', path: 'health check'),
    git: GitHealth(
      available: git.field<bool>('available', path: 'health check.git'),
      repositoryFound: git.field<bool>(
        'repository_found',
        path: 'health check.git',
      ),
      libgit2Version: git.field<String>(
        'libgit2_version',
        path: 'health check.git',
      ),
      workdir: git.field<String?>('workdir', path: 'health check.git'),
      error: git.field<String?>('error', path: 'health check.git'),
    ),
    filePicker: FilePickerHealth(
      initialized: picker.field<bool>(
        'initialized',
        path: 'health check.file_picker',
      ),
      basePath: picker.field<String?>(
        'base_path',
        path: 'health check.file_picker',
      ),
      isScanning: picker.field<bool?>(
        'is_scanning',
        path: 'health check.file_picker',
      ),
      indexedFiles: picker.field<int?>(
        'indexed_files',
        path: 'health check.file_picker',
      ),
      error: picker.field<String?>('error', path: 'health check.file_picker'),
    ),
    frecency: _decodeDatabaseHealth(frecency, 'health check.frecency'),
    queryTracker: _decodeDatabaseHealth(
      queryTracker,
      'health check.query_tracker',
    ),
  );
}

_JsonObject _healthJsonObject(Object? value, String name) {
  if (value is Map<String, Object?>) return _JsonObject(value);
  throw StateError('FFF returned invalid $name JSON data');
}

extension type _JsonObject(Map<String, Object?> _value) {
  // Nullability in T distinguishes nullable JSON fields from required fields.
  T field<T>(String key, {required String path}) {
    final value = _value[key];
    if (value == null && null is T) return value as T;
    if (value is T) return value;
    throw StateError('FFF returned invalid $path.$key JSON data');
  }

  _JsonObject object(String key, {required String path}) {
    return _JsonObject(field(key, path: path));
  }
}
