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

  /// Searches indexed files using FFF's fuzzy query parser and ranking.
  ///
  /// Wait for the initial scan with [waitForScan] when results must include
  /// every file. This synchronous call may block while FFF searches. [options]
  /// controls threading, current-file scoring, combo boosts, and the result
  /// range. [SearchOptions.offset] is the number of results to skip, and a
  /// zero [SearchOptions.pageSize] uses FFF's default limit of 100. FFF also
  /// chooses defaults when [SearchOptions.maxThreads],
  /// [SearchOptions.comboBoostMultiplier], or [SearchOptions.minComboCount]
  /// are zero.
  ///
  /// The returned items, scores, and optional query location are detached
  /// values and remain usable after this finder is disposed. The item and
  /// score lists are unmodifiable. A NUL-containing query or current file
  /// throws [ArgumentError]. Options outside the native integer ranges throw
  /// [RangeError]. A native failure throws [FffException].
  SearchResult searchFile(
    String query, {
    SearchOptions options = const SearchOptions(),
  }) {
    return search_bindings.search(
      _liveHandle,
      query,
      currentFile: options.currentFile,
      maxThreads: options.maxThreads,
      offset: options.offset,
      pageSize: options.pageSize,
      comboBoostMultiplier: options.comboBoostMultiplier,
      minComboCount: options.minComboCount,
    );
  }

  /// Searches file contents with literal, regular-expression, or fuzzy
  /// matching.
  ///
  /// Wait for [waitForScan] before searching when results should include every
  /// indexed file. This synchronous operation may block while FFF searches.
  /// [GrepOptions.fileOffset] resumes within the filtered candidate-file order;
  /// pass [GrepResult.nextFileOffset] with the same query and options to
  /// continue. A zero [GrepOptions.pageLimit] uses FFF's default of 50, and
  /// the limit may be exceeded to finish the current file. A zero
  /// [GrepOptions.maxFileSizeBytes] uses 10 MiB; zero
  /// [GrepOptions.maxMatchesPerFile] allows all matches.
  ///
  /// The query is parsed according to [FffOptions.aiMode]. If parsed
  /// constraints produce no matches, FFF may retry the query as literal text
  /// while retaining only explicit path constraints. Invalid regular
  /// expressions fall back to literal matching and populate
  /// [GrepResult.regexFallbackError]. Regex uses multiline byte matching with
  /// Unicode mode disabled; `\n` is treated as a newline. Plain-text smart
  /// case folding is ASCII-only. A constrained no-match retry as literal text
  /// is not reported separately in [GrepResult].
  /// [GrepResult.candidateFilesConsumed] counts positions advanced within the
  /// filtered candidate list, including candidates without matches or with
  /// read failures; files removed during filtering are not counted. Time
  /// budgets are best effort, checked periodically, and can be exceeded. For
  /// plain-text and regex searches,
  /// [GrepOptions.enforceTimeBudget] applies the budget from the start; when
  /// false, FFF delays it until more than one match has accumulated, so a
  /// nonzero budget need not bound zero- or one-match searches. Fuzzy matching
  /// uses any nonzero budget regardless of that flag. Context is not returned
  /// in fuzzy mode.
  ///
  /// Match columns, highlight spans, and [GrepMatch.lineByteOffset] are source
  /// byte offsets, not Dart string indices. They align with displayed text
  /// when the original line is valid UTF-8; invalid bytes become replacement
  /// characters and can shift displayed positions. Displayed and context lines
  /// may be truncated to 512 bytes. Fuzzy scores are null outside fuzzy mode.
  /// Matches and all nested lists are detached, unmodifiable values that
  /// remain usable after this finder is disposed. Definition classification is
  /// heuristic and is available in source builds. Empty queries are allowed;
  /// a NUL-containing query throws [ArgumentError]. Values outside native
  /// integer ranges throw [RangeError]. Native failures throw [FffException].
  GrepResult grep(String query, {GrepOptions options = const GrepOptions()}) =>
      grep_bindings.liveGrepEx(_liveHandle, query, options: options);

  /// Searches for lines containing any of [patterns] using literal matching.
  ///
  /// Wait for [waitForScan] before searching when results should include every
  /// indexed file. This synchronous operation may block while FFF searches.
  /// A line matching multiple patterns is returned once with non-overlapping
  /// highlight ranges; the result does not identify which pattern produced a
  /// range. Pattern order is not significant. Empty patterns and patterns
  /// containing NUL or newline characters throw [ArgumentError].
  ///
  /// [MultiGrepOptions.constraints] is parsed separately from patterns using
  /// FFF's fixed AI grep constraint parser, regardless of [FffOptions.aiMode].
  /// Constraints are split on whitespace; unrecognized tokens are ignored.
  /// A NUL character in [MultiGrepOptions.constraints] throws
  /// [ArgumentError].
  /// A constraint miss returns no matches and does not retry without the
  /// constraint. [MultiGrepOptions.fileOffset] resumes within the filtered
  /// candidate-file order. Continue by passing [GrepResult.nextFileOffset] as
  /// [MultiGrepOptions.fileOffset] with the same patterns and other options.
  /// A zero [MultiGrepOptions.pageLimit] uses FFF's default of 50 and may be
  /// exceeded to finish the current file.
  ///
  /// When [MultiGrepOptions.smartCase] is true, FFF checks all patterns for
  /// uppercase characters using Unicode-aware detection. If any pattern has
  /// uppercase characters, the entire pattern set is case-sensitive; otherwise
  /// FFF applies ASCII-only case folding. False is always case-sensitive.
  /// Time budgets are best effort, checked periodically, and can be exceeded.
  /// With [MultiGrepOptions.enforceTimeBudget] false, FFF delays the budget
  /// until more than one match has accumulated, so it may not bound a
  /// zero- or one-match search.
  ///
  /// Result fields are detached and immutable. Fuzzy scores and regex fallback
  /// errors are always null for this literal search. Match byte coordinates
  /// share the behavior described for [grep], including lossy UTF-8 display.
  /// Values outside native integer ranges throw [RangeError]. Native failures
  /// throw [FffException].
  GrepResult multiGrep(
    Iterable<String> patterns, {
    MultiGrepOptions options = const MultiGrepOptions(),
  }) => grep_bindings.multiGrepEx(_liveHandle, patterns, options: options);

  /// Filters indexed files with one glob pattern, without parsing a query.
  ///
  /// The pattern is matched against each file's root-relative path. FFF's
  /// glob backend determines the supported pattern details. Matching files
  /// use FFF's frecency-mode ranking, including Git status and recency boosts
  /// and the optional current-file penalty; equal scores are ordered by
  /// modification time, with remaining ties unspecified. [options] forwards
  /// the worker-thread setting and controls current-file ranking and the
  /// result range. FFF uses a zero [GlobOptions.maxThreads] as its automatic
  /// default sentinel. A zero [GlobOptions.pageSize] uses FFF's default limit
  /// of 100. [GlobOptions.offset] is the number of matches to skip.
  ///
  /// Results have no query location. The returned items and scores are
  /// detached, unmodifiable values and remain usable after this finder is
  /// disposed. Empty or NUL-containing patterns and NUL-containing current
  /// files throw [ArgumentError]. Malformed glob syntax produces no matches.
  /// Options outside the native integer ranges throw [RangeError]. Native
  /// failures throw [FffException]. This synchronous operation may block
  /// while FFF searches; wait for [waitForScan] when results should include
  /// every indexed file.
  SearchResult glob(
    String pattern, {
    GlobOptions options = const GlobOptions(),
  }) {
    return glob_bindings.glob(
      _liveHandle,
      pattern,
      currentFile: options.currentFile,
      maxThreads: options.maxThreads,
      offset: options.offset,
      pageSize: options.pageSize,
    );
  }

  /// Searches indexed directories by fuzzy path and directory-name matching.
  ///
  /// Call [waitForScan] first when results should include every indexed
  /// directory; the initial scan runs asynchronously. This synchronous
  /// operation may block while FFF searches. An empty query
  /// returns directories ranked by access frecency. A location suffix such as
  /// `:12` is removed from the search text; directory results do not include
  /// location data. [options] controls worker threads, current-file scoring,
  /// and the result range. [DirectorySearchOptions.offset] counts matching
  /// directories to skip. A zero [DirectorySearchOptions.pageSize] uses FFF's
  /// default limit of 100; zero [DirectorySearchOptions.maxThreads] lets FFF
  /// choose its parallelism. Returned items and scores are detached,
  /// unmodifiable values that remain usable after this finder is disposed.
  /// A NUL-containing query or current file throws [ArgumentError]. Options
  /// outside the native integer ranges throw [RangeError]. Native failures
  /// throw [FffException].
  DirectorySearchResult searchDirectories(
    String query, {
    DirectorySearchOptions options = const DirectorySearchOptions(),
  }) {
    return directory_search_bindings.searchDirectories(
      _liveHandle,
      query,
      currentFile: options.currentFile,
      maxThreads: options.maxThreads,
      offset: options.offset,
      pageSize: options.pageSize,
    );
  }

  /// Searches indexed files and directories together by fuzzy match score.
  ///
  /// Wait for the initial scan with [waitForScan] when results must include
  /// every indexed entry. This synchronous call may block while FFF searches.
  /// Results are ordered by descending total score; the order of equal-score
  /// entries is unspecified. A query ending in `/` (or `\\` on Windows)
  /// searches directories only.
  /// [options] controls worker threads, current-file scoring, combo boosts,
  /// and the result range. [SearchOptions.offset] counts mixed results to
  /// skip, and a zero [SearchOptions.pageSize] uses FFF's default limit of
  /// 100. FFF selects defaults when [SearchOptions.maxThreads],
  /// [SearchOptions.comboBoostMultiplier], or
  /// [SearchOptions.minComboCount] are zero.
  ///
  /// The returned files, directories, scores, and optional query location are
  /// detached values and remain usable after this finder is disposed. Items
  /// can be exhaustively matched as [FileItem] or [DirectoryItem]. The item
  /// and score lists are unmodifiable and aligned by index.
  /// [MixedSearchResult.totalMatched] counts matches before pagination. A
  /// NUL-containing query or current file
  /// throws [ArgumentError]. Options outside the native integer ranges throw
  /// [RangeError]. A native failure throws [FffException].
  MixedSearchResult searchMixed(
    String query, {
    SearchOptions options = const SearchOptions(),
  }) {
    return mixed_search_bindings.searchMixed(
      _liveHandle,
      query,
      currentFile: options.currentFile,
      maxThreads: options.maxThreads,
      offset: options.offset,
      pageSize: options.pageSize,
      comboBoostMultiplier: options.comboBoostMultiplier,
      minComboCount: options.minComboCount,
    );
  }

  /// Schedules a full filesystem rescan and returns before it completes.
  ///
  /// FFF can queue this request behind ongoing work. [waitForScan] observes
  /// the current scan signal and cannot confirm that this specific request
  /// has finished. Throws [FffException] if FFF cannot schedule the rescan.
  void rescan() => bindings.scanFiles(_liveHandle);

  /// Refreshes Git status and recency data for the indexed directory.
  ///
  /// This synchronous operation may block while FFF reads repository status.
  /// Returns the number of Git status entries returned by FFF. Zero may mean
  /// there are no entries, no repository, an unavailable status read, or a
  /// concurrent index change; it does not confirm a successful status read.
  /// Native failures throw [FffException].
  int refreshGitStatus() => bindings.refreshGitStatus(_liveHandle);

  /// Records that [filePath] was selected for [query] in query history.
  ///
  /// Configure [FffOptions.historyDbPath] when opening this finder to persist
  /// history. Returns FFF's tracking flag. When history storage is not
  /// configured, FFF can return true without persisting a record; internal
  /// lock or picker failures can return false as a successful native result.
  /// Both strings must be NUL-free. FFF canonicalizes [filePath], so it must
  /// identify an existing path. Native failures throw [FffException].
  bool trackQuery(String query, String filePath) =>
      bindings.trackQuery(_liveHandle, query, filePath);

  /// Gets a recorded query by recency offset, where zero is the newest query.
  ///
  /// Returns null when the offset is not recorded or history is unavailable.
  /// [offset] must fit the native unsigned 64-bit range supported by Dart.
  /// Native failures throw [FffException].
  String? getHistoricalQuery(int offset) =>
      bindings.getHistoricalQuery(_liveHandle, offset);

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
