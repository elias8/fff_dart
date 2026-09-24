import 'search_location.dart';

/// A file or directory returned by mixed fuzzy search.
sealed class const MixedItem();

/// A directory returned by a fuzzy directory or mixed search.
final class const DirectoryItem({
  /// Path relative to the indexed directory, with a trailing slash.
  required final String relativePath,

  /// Last path segment, including its trailing slash.
  required final String dirName,

  /// Highest access-frecency score among this directory's direct child files.
  required final int maxAccessFrecencyScore,
}) extends MixedItem;

/// Options for `FileFinder.searchDirectories`.
final class const DirectorySearchOptions({
  /// Maximum worker threads. Zero lets FFF choose the available parallelism.
  final int maxThreads = 0,

  /// Current file path used to adjust directory ranking, or null to skip it.
  final String? currentFile,

  /// Number of matching directories to skip. Zero starts at the first result.
  final int offset = 0,

  /// Maximum number of results. Zero uses FFF's default of 100.
  final int pageSize = 0,
});

/// Detached results from a fuzzy directory search.
final class DirectorySearchResult(
  List<DirectoryItem> items,
  List<SearchScore> scores, {

  /// Number of matching directories before applying the result range.
  required final int totalMatched,

  /// Number of directories in the index.
  required final int totalDirectories,
}) {
  /// Matched directories in score order.
  final List<DirectoryItem> items = List.unmodifiable(items);

  /// Score details corresponding by index to [items].
  final List<SearchScore> scores = List.unmodifiable(scores);

  this {
    if (items.length != scores.length) {
      throw ArgumentError(
        'Every directory item must have one corresponding score',
      );
    }
  }
}

/// A detached file returned by file or mixed fuzzy search.
final class const FileItem({
  /// Path relative to the indexed directory.
  required final String relativePath,

  /// File name without its parent path.
  required final String fileName,

  /// Git status reported by FFF.
  required final String gitStatus,

  /// File size in bytes.
  required final int size,

  /// Modification time as seconds since the Unix epoch.
  required final int modified,

  /// Score based on file access history.
  required final int accessFrecencyScore,

  /// Score based on file modification history.
  required final int modificationFrecencyScore,

  /// Combined frecency score.
  required final int totalFrecencyScore,

  /// Whether FFF detected the file as binary.
  required final bool isBinary,
}) extends MixedItem;

/// Options for [FileFinder.searchFile] and [FileFinder.searchMixed].
final class const SearchOptions({
  /// Maximum worker threads. Zero lets FFF choose the available parallelism.
  final int maxThreads = 0,

  /// Current file path to deprioritize, or null to skip this adjustment.
  final String? currentFile,

  /// Multiplier for query history combo boosts. Zero uses FFF's default of 100.
  final int comboBoostMultiplier = 0,

  /// Minimum combo count for a query history boost. Zero uses FFF's default 3.
  final int minComboCount = 0,

  /// Number of matching results to skip. Zero starts at the first result.
  final int offset = 0,

  /// Maximum number of results. Zero uses FFF's default of 100.
  final int pageSize = 0,
});

/// Options for [FileFinder.glob].
final class const GlobOptions({
  /// Worker-thread setting forwarded to FFF. Zero is FFF's default sentinel.
  final int maxThreads = 0,

  /// Current file path to deprioritize, or null to skip this adjustment.
  final String? currentFile,

  /// Number of matching files to skip. Zero starts at the first result.
  final int offset = 0,

  /// Maximum number of results. Zero uses FFF's default of 100.
  final int pageSize = 0,
});

/// Detached results from a file search.
final class SearchResult(
  List<FileItem> items,
  List<SearchScore> scores, {
  required final int totalMatched,
  required final int totalFiles,
  required final SearchLocation? location,
}) {
  /// Matched files in score order.
  final List<FileItem> items = List.unmodifiable(items);

  /// Score details corresponding by index to [items].
  final List<SearchScore> scores = List.unmodifiable(scores);

  this {
    if (items.length != scores.length) {
      throw ArgumentError(
        'Every search item must have one corresponding score',
      );
    }
  }
}

/// Detached files and directories returned in descending total-score order.
///
/// [items] is a sealed union of [FileItem] and [DirectoryItem], so a switch
/// over its values is exhaustive. Equal-score item ordering is unspecified.
final class MixedSearchResult(
  List<MixedItem> items,
  List<SearchScore> scores, {

  /// Number of matches before the result range; slash-terminated queries count
  /// matching directories only.
  required final int totalMatched,

  /// Number of files in the index.
  required final int totalFiles,

  /// Number of indexed directories, including the base directory.
  required final int totalDirectories,

  /// Location parsed from the query, if present.
  required final SearchLocation? location,
}) {
  /// Matched files and directories in score order.
  final List<MixedItem> items = List.unmodifiable(items);

  /// Score details corresponding by index to [items].
  final List<SearchScore> scores = List.unmodifiable(scores);

  this {
    if (items.length != scores.length) {
      throw ArgumentError(
        'Every mixed search item must have one corresponding score',
      );
    }
  }
}

/// Score components returned by file, directory, and mixed searches.
final class const SearchScore({
  /// Total combined score.
  required final int total,

  /// Base fuzzy match score.
  required final int baseScore,

  /// Bonus for matching the file name or directory name.
  required final int filenameBonus,

  /// Bonus for special file names such as `main.rs`; zero for directories.
  required final int specialFilenameBonus,

  /// Boost from frecency.
  required final int frecencyBoost,

  /// Penalty for distance in the path.
  required final int distancePenalty,

  /// Penalty for matching the current file; directory search leaves this zero
  /// and includes proximity adjustment in [distancePenalty].
  required final int currentFilePenalty,

  /// Boost from query history combo matching; zero for directory search.
  required final int comboMatchBoost,

  /// Bonus for alignment with path components; zero for directories.
  required final int pathAlignmentBonus,

  /// Whether the match is exact.
  required final bool exactMatch,

  /// FFF's match classification string.
  required final String matchType,
});
