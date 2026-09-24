import 'dart:ffi';

import 'package:ffi/ffi.dart';

import '../ffi/fff.g.dart';
import 'types/result.dart';
import 'types/string.dart';

void _checkLimit(int value, String name) {
  if (value < 0) throw RangeError.value(value, name, 'Must be nonnegative');
}

int createInstanceWith(
  String basePath, {
  required String? frecencyDbPath,
  required String? historyDbPath,
  required bool enableMmapCache,
  required bool enableContentIndexing,
  required bool watch,
  required bool aiMode,
  required String? logFilePath,
  required String? logLevel,
  required int cacheBudgetMaxFiles,
  required int cacheBudgetMaxBytes,
  required int cacheBudgetMaxFileSize,
  required bool enableFsRootScanning,
  required bool enableHomeDirScanning,
  required bool followSymlinks,
}) {
  if (basePath.isEmpty) {
    throw ArgumentError.value(basePath, 'basePath', 'Must not be empty');
  }
  _checkLimit(cacheBudgetMaxFiles, 'cacheBudgetMaxFiles');
  _checkLimit(cacheBudgetMaxBytes, 'cacheBudgetMaxBytes');
  _checkLimit(cacheBudgetMaxFileSize, 'cacheBudgetMaxFileSize');

  return using((arena) {
    final options = arena<FffCreateOptions>();
    options.ref
      ..version = FFF_CREATE_OPTIONS_VERSION
      ..base_path = basePath.toNativeChar(arena, 'basePath')
      ..frecency_db_path = frecencyDbPath.toNativeChar(arena, 'frecencyDbPath')
      ..history_db_path = historyDbPath.toNativeChar(arena, 'historyDbPath')
      ..enable_mmap_cache = enableMmapCache
      ..enable_content_indexing = enableContentIndexing
      ..watch = watch
      ..ai_mode = aiMode
      ..log_file_path = logFilePath.toNativeChar(arena, 'logFilePath')
      ..log_level = logLevel.toNativeChar(arena, 'logLevel')
      ..cache_budget_max_files = cacheBudgetMaxFiles
      ..cache_budget_max_bytes = cacheBudgetMaxBytes
      ..cache_budget_max_file_size = cacheBudgetMaxFileSize
      ..enable_fs_root_scanning = enableFsRootScanning
      ..enable_home_dir_scanning = enableHomeDirScanning
      ..follow_symlinks = followSymlinks;

    return decodeFffResult(
      () => fff_create_instance_with(options),
      operationName: 'FileFinder.open',
      decodeSuccess: (envelope) {
        final handle = envelope.handle;
        if (handle == nullptr) {
          throw StateError('FFF created an index without a handle');
        }
        return handle.address;
      },
    );
  });
}

void destroy(int handle) {
  fff_destroy(Pointer<Void>.fromAddress(handle));
}

String getBasePath(int handle) {
  return decodeFffResult(
    () => fff_get_base_path(Pointer<Void>.fromAddress(handle)),
    operationName: 'FileFinder.basePath',
    decodeSuccess: (envelope) {
      final path = envelope.handle.cast<Char>();
      if (path == nullptr) {
        throw StateError('FFF returned a null base path');
      }

      try {
        return path.toDartString();
      } finally {
        fff_free_string(path);
      }
    },
  );
}

({
  int scannedFilesCount,
  bool isScanning,
  bool isWatcherReady,
  bool isWarmupComplete,
})
getScanProgress(int handle) {
  return decodeFffResult(
    () => fff_get_scan_progress(Pointer<Void>.fromAddress(handle)),
    operationName: 'FileFinder.scanProgress',
    decodeSuccess: (envelope) {
      final progress = envelope.handle.cast<FffScanProgress>();
      if (progress == nullptr) {
        throw StateError('FFF returned null scan progress');
      }
      try {
        final value = progress.ref;
        return (
          scannedFilesCount: value.scanned_files_count,
          isScanning: value.is_scanning,
          isWatcherReady: value.is_watcher_ready,
          isWarmupComplete: value.is_warmup_complete,
        );
      } finally {
        fff_free_scan_progress(progress);
      }
    },
  );
}

bool isScanning(int handle) {
  return fff_is_scanning(Pointer<Void>.fromAddress(handle));
}

void scanFiles(int handle) {
  decodeFffResult<void>(
    () => fff_scan_files(Pointer<Void>.fromAddress(handle)),
    operationName: 'FileFinder.rescan',
    decodeSuccess: ignoreResult,
  );
}

int refreshGitStatus(int handle) {
  return decodeFffResult(
    () => fff_refresh_git_status(Pointer<Void>.fromAddress(handle)),
    operationName: 'FileFinder.refreshGitStatus',
    decodeSuccess: (envelope) {
      final count = envelope.int_value;
      if (count < 0) {
        throw StateError('FFF returned a negative Git status count: $count');
      }
      return count;
    },
  );
}

void restartIndex(int handle, String newPath) {
  if (newPath.isEmpty) {
    throw ArgumentError.value(newPath, 'newPath', 'Must not be empty');
  }
  using((arena) {
    decodeFffResult<void>(
      () => fff_restart_index(
        Pointer<Void>.fromAddress(handle),
        newPath.toNativeChar(arena, 'newPath'),
      ),
      operationName: 'FileFinder.restartIndex',
      decodeSuccess: ignoreResult,
    );
  });
}

bool trackQuery(int handle, String query, String filePath) {
  return using((arena) {
    return decodeFffResult(
      () => fff_track_query(
        Pointer<Void>.fromAddress(handle),
        query.toNativeChar(arena, 'query'),
        filePath.toNativeChar(arena, 'filePath'),
      ),
      operationName: 'FileFinder.trackQuery',
      decodeSuccess: (envelope) => switch (envelope.int_value) {
        0 => false,
        1 => true,
        final value => throw StateError(
          'FFF returned an invalid query tracking value: $value',
        ),
      },
    );
  });
}

String? getHistoricalQuery(int handle, int offset) {
  if (offset < 0 || offset > 0x7fffffffffffffff) {
    throw RangeError.range(offset, 0, 0x7fffffffffffffff, 'offset');
  }

  return decodeFffResult(
    () => fff_get_historical_query(Pointer<Void>.fromAddress(handle), offset),
    operationName: 'FileFinder.getHistoricalQuery',
    decodeSuccess: (envelope) {
      final query = envelope.handle.cast<Char>();
      if (query == nullptr) return null;
      try {
        return query.toDartString();
      } finally {
        fff_free_string(query);
      }
    },
  );
}

bool _decodeWaitResult(FffResult result) => switch (result.int_value) {
  0 => false,
  1 => true,
  final value => throw StateError(
    'FFF returned an invalid wait value: '
    '$value',
  ),
};

bool waitForScan(int handle, int timeoutMilliseconds) {
  return decodeFffResult(
    () => fff_wait_for_scan(
      Pointer<Void>.fromAddress(handle),
      timeoutMilliseconds,
    ),
    operationName: 'FileFinder.waitForScan',
    decodeSuccess: _decodeWaitResult,
  );
}

bool waitForWatcher(int handle, int timeoutMilliseconds) {
  return decodeFffResult(
    () => fff_wait_for_watcher(
      Pointer<Void>.fromAddress(handle),
      timeoutMilliseconds,
    ),
    operationName: 'FileFinder.waitForWatcher',
    decodeSuccess: _decodeWaitResult,
  );
}
