part of 'api.dart';

/// Options used when opening a [FileFinder].
///
/// Paths are passed as UTF-8. Null or empty optional paths disable their
/// associated native feature. Cache limits of zero let FFF choose a value after
/// its initial scan.
final class const FffOptions({
  /// Path to a frecency database, or null to disable frecency tracking.
  final String? frecencyDbPath,

  /// Path to a query history database, or null to disable query tracking.
  final String? historyDbPath,

  /// Prepopulates mmap caches for frequently used files after the scan.
  final bool enableMmapCache = true,

  /// Builds a content index after the filesystem scan.
  final bool enableContentIndexing = true,

  /// Starts a background filesystem watcher.
  final bool watch = true,

  /// Enables FFF's AI agent optimizations.
  final bool aiMode = false,

  /// Path for a tracing log, or null to skip tracing initialization.
  final String? logFilePath,

  /// Tracing level when [logFilePath] is set: trace, debug, info, warn,
  /// or error. Null uses info.
  final String? logLevel,

  /// Maximum number of files in the content cache; zero selects automatic.
  final int cacheBudgetMaxFiles = 0,

  /// Maximum content cache size in bytes; zero selects automatic.
  final int cacheBudgetMaxBytes = 0,

  /// Maximum cached size per file in bytes; zero selects automatic.
  final int cacheBudgetMaxFileSize = 0,

  /// Allows indexing the filesystem root. Disabled by default.
  final bool enableFsRootScanning = false,

  /// Allows indexing the user's home directory. Disabled by default.
  final bool enableHomeDirScanning = false,

  /// Follows symlinks while scanning and watching. Disabled by default.
  final bool followSymlinks = false,
});

/// A snapshot of filesystem scan and background readiness state.
final class const FffScanProgress({
  /// Number of files observed by the current or latest scan.
  required final int scannedFilesCount,

  /// Whether a filesystem scan is active.
  required final bool isScanning,

  /// Whether the background watcher is ready.
  required final bool isWatcherReady,

  /// Whether content indexing is ready, or was disabled.
  required final bool isWarmupComplete,
});

/// An FFF index of a directory.
///
/// [open] starts the initial scan and optional background work. Call [dispose]
/// when finished. Operations are synchronous and may block the calling isolate;
/// [waitForScan], [waitForWatcher], and [dispose] can wait for native work.
///
/// Every operation except [dispose] throws [StateError] after disposal. Do not
/// dispose an instance concurrently with another call on that instance.
///
/// ```dart
/// final index = FileFinder.open('/path/to/project');
/// try {
///   final scanned = index.waitForScan(const Duration(seconds: 30));
///   if (scanned) {
///     final progress = index.scanProgress;
///     // Inspect progress.isWarmupComplete if content indexing is enabled.
///   }
/// } finally {
///   index.dispose();
/// }
/// ```
final class FileFinder._(var int _handle) implements Finalizable {
  static final _finalizer = Finalizer<int>(bindings.destroy);

  this {
    _finalizer.attach(this, _handle, detach: this);
  }

  /// Opens [basePath] and starts its initial scan.
  ///
  /// [basePath] must be a nonempty directory path. [options] controls storage,
  /// caching, watching, and scanning. Creation returns before scanning and
  /// content warmup finish. Throws [ArgumentError] for empty or NUL-containing
  /// paths, [RangeError] for negative cache limits, and [FffException] when FFF
  /// rejects the path or fails to initialize a native resource.
  factory open(String basePath, {FffOptions options = const FffOptions()}) {
    if (basePath.isEmpty || basePath.contains('\u0000')) {
      throw ArgumentError.value(
        basePath,
        'basePath',
        'Must be a directory path',
      );
    }
    final type = FileSystemEntity.typeSync(basePath);
    if (type != .directory && type != .notFound) {
      throw ArgumentError.value(basePath, 'basePath', 'Must be a directory');
    }
    final handle = bindings.createInstanceWith(
      basePath,
      frecencyDbPath: options.frecencyDbPath,
      historyDbPath: options.historyDbPath,
      enableMmapCache: options.enableMmapCache,
      enableContentIndexing: options.enableContentIndexing,
      watch: options.watch,
      aiMode: options.aiMode,
      logFilePath: options.logFilePath,
      logLevel: options.logLevel,
      cacheBudgetMaxFiles: options.cacheBudgetMaxFiles,
      cacheBudgetMaxBytes: options.cacheBudgetMaxBytes,
      cacheBudgetMaxFileSize: options.cacheBudgetMaxFileSize,
      enableFsRootScanning: options.enableFsRootScanning,
      enableHomeDirScanning: options.enableHomeDirScanning,
      followSymlinks: options.followSymlinks,
    );
    return FileFinder._(handle);
  }

  /// The index's base path as reported by FFF.
  ///
  /// Throws [FffException] if FFF cannot read its picker state.
  String get basePath => bindings.getBasePath(_liveHandle);

  /// Whether a filesystem scan is active at the instant of the call.
  bool get isScanning => bindings.isScanning(_liveHandle);

  /// A detached snapshot of scan and watcher progress.
  ///
  /// The snapshot remains usable after [dispose]. Throws [FffException] if FFF
  /// cannot read its picker state.
  FffScanProgress get scanProgress {
    final progress = bindings.getScanProgress(_liveHandle);
    return FffScanProgress(
      scannedFilesCount: progress.scannedFilesCount,
      isScanning: progress.isScanning,
      isWatcherReady: progress.isWatcherReady,
      isWarmupComplete: progress.isWarmupComplete,
    );
  }

  int get _liveHandle {
    if (_handle == 0) throw StateError('FileFinder has been disposed');
    return _handle;
  }

  /// Releases native resources. Repeated calls have no effect.
  ///
  /// Shutdown can block while a native watcher finishes. A finalizer is a
  /// fallback when [dispose] is omitted; call this method for timely release.
  void dispose() {
    final handle = _handle;
    if (handle == 0) return;
    _handle = 0;
    _finalizer.detach(this);
    bindings.destroy(handle);
  }

  /// Schedules a full filesystem rescan and returns before it completes.
  ///
  /// FFF can queue this request behind ongoing work. [waitForScan] observes
  /// the current scan signal and cannot confirm that this specific request
  /// has finished. Throws [FffException] if FFF cannot schedule the rescan.
  void rescan() => bindings.scanFiles(_liveHandle);

  /// Blocks until the filesystem scan ends or [timeout] elapses.
  ///
  /// Returns true when the current scan signal clears, false on timeout. A
  /// queued [rescan] can begin later, so true does not confirm its completion.
  /// This does not wait for content warmup or watcher installation; inspect
  /// [scanProgress] for those states. A zero timeout checks immediately.
  /// Positive durations below one millisecond round up. A negative timeout
  /// throws [RangeError]; a native failure throws [FffException].
  bool waitForScan(Duration timeout) {
    return bindings.waitForScan(_liveHandle, _timeoutMilliseconds(timeout));
  }

  /// Blocks until the background watcher is ready or [timeout] elapses.
  ///
  /// Returns false on timeout, including when [FffOptions.watch] is false.
  /// A zero timeout checks immediately. Positive submillisecond durations
  /// round up to one millisecond. Throws [RangeError] for a negative timeout
  /// and [FffException] for a native failure.
  bool waitForWatcher(Duration timeout) {
    return bindings.waitForWatcher(_liveHandle, _timeoutMilliseconds(timeout));
  }

  int _timeoutMilliseconds(Duration timeout) {
    final micros = timeout.inMicroseconds;
    if (micros < 0) {
      throw RangeError.range(micros, 0, null, 'timeout');
    }
    return micros ~/ 1000 + (micros % 1000 == 0 ? 0 : 1);
  }
}
