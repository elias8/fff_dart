/// The kind of filesystem change reported by a watch.
enum WatchEventKind {
  /// An entry was created.
  created,

  /// An entry was modified.
  modified,

  /// An entry was removed.
  removed,

  /// The operating system dropped events; rescan the affected paths.
  rescan,

  /// An entry moved. [WatchEvent.fromPath] is the old path.
  renamed,
}

/// A detached filesystem change reported by a watch.
final class const WatchEvent({
  /// The absolute path affected by the change.
  required final String path,

  /// The type of filesystem change.
  required final WatchEventKind kind,

  /// The old absolute path for a rename, or null for other changes.
  final String? fromPath,
});
