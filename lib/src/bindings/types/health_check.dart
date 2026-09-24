/// Health information returned by FFF's diagnostic operation.
final class const HealthCheck(
  /// Version string of the native FFF library.
  final String version, {

  /// libgit2 and repository-discovery status.
  required final GitHealth git,

  /// State of the indexed filesystem picker.
  required final FilePickerHealth filePicker,

  /// State and optional health data of the frecency database.
  required final DatabaseHealth frecency,

  /// State and optional health data of the query-history database.
  required final DatabaseHealth queryTracker,
});

/// FFF's libgit2 availability and repository-discovery status.
final class const GitHealth({
  /// Whether FFF's libgit2 integration is available.
  required final bool available,

  /// Whether a repository was found at the requested test path.
  required final bool repositoryFound,

  /// Version string reported by libgit2.
  required final String libgit2Version,

  /// Repository working directory, omitted for repositories without one.
  final String? workdir,

  /// Repository-discovery error when no repository is found.
  final String? error,
});

/// State reported by the indexed file picker.
final class const FilePickerHealth({
  /// Whether the native picker has been initialized.
  required final bool initialized,

  /// Root directory currently being indexed.
  final String? basePath,

  /// Whether a filesystem scan is running.
  final bool? isScanning,

  /// Number of files indexed so far.
  final int? indexedFiles,

  /// Picker status error, when reported by FFF.
  final String? error,
});

/// Initialization and optional database health details.
final class const DatabaseHealth({
  /// Whether the corresponding FFF database is initialized.
  required final bool initialized,

  /// Database path and disk size, omitted when FFF has no details.
  final DatabaseHealthDetails? details,

  /// Database health error, when reported by FFF.
  final String? error,
});

/// Location and disk size of an initialized FFF database.
final class const DatabaseHealthDetails(
  /// Native database path.
  final String path,

  /// Database size on disk in bytes.
  final int diskSizeBytes,
);
