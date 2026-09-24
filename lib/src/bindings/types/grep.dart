/// A detached content match returned by [FileFinder.grep].
final class GrepMatch({
  /// Path relative to the indexed directory.
  required final String relativePath,

  /// File name without its parent path.
  required final String fileName,

  /// Git status reported by FFF.
  required final String gitStatus,

  /// Matched line text, potentially truncated to 512 bytes by FFF.
  required final String lineContent,

  /// Highlight spans as source-line byte offsets. They align with
  /// [lineContent] when the original line is valid UTF-8.
  required List<GrepMatchRange> matchRanges,

  /// Context lines before the match, each potentially truncated to 512 bytes.
  required List<String> contextBefore,

  /// Context lines after the match, each potentially truncated to 512 bytes.
  required List<String> contextAfter,

  /// Full file size in bytes.
  required final int size,

  /// File modification time in seconds since the Unix epoch.
  required final int modified,

  /// Combined frecency score.
  required final int totalFrecencyScore,

  /// Access-based frecency score.
  required final int accessFrecencyScore,

  /// Modification-based frecency score.
  required final int modificationFrecencyScore,

  /// One-based line number.
  required final int lineNumber,

  /// Source-byte offset of the start of this line in the file.
  required final int lineByteOffset,

  /// Zero-based byte column of the match start within the source line.
  required final int columnByteOffset,

  /// Fuzzy score, or null when the selected mode did not provide one.
  required final int? fuzzyScore,

  /// Whether FFF detected the containing file as binary.
  required final bool isBinary,

  /// Whether FFF's enabled definition classifier marked this match.
  required final bool isDefinition,
}) {
  /// Highlight spans as an unmodifiable detached list.
  final List<GrepMatchRange> matchRanges = List.unmodifiable(matchRanges);

  /// Context lines before the match as an unmodifiable detached list.
  final List<String> contextBefore = List.unmodifiable(contextBefore);

  /// Context lines after the match as an unmodifiable detached list.
  final List<String> contextAfter = List.unmodifiable(contextAfter);
}

/// A matched highlight span, represented as a half-open byte range.
final class const GrepMatchRange({
  /// Inclusive byte offset in the source line. It aligns with
  /// [GrepMatch.lineContent] when the original line is valid UTF-8.
  required final int startByte,

  /// Exclusive byte offset in the source line. It aligns with
  /// [GrepMatch.lineContent] when the original line is valid UTF-8.
  required final int endByte,
});

/// Matching strategies supported by content search.
enum GrepMode {
  /// Literal matching with FFF's byte-oriented SIMD matcher.
  plainText,

  /// Regular-expression matching with literal fallback on invalid patterns.
  regex,

  /// Fuzzy matching within each line.
  fuzzy,
}

/// Options for [FileFinder.grep].
///
/// Zero values retain FFF's native default sentinels. [fileOffset] resumes
/// within the same filtered, ranked candidate-file sequence returned by an
/// earlier call with the same query and options.
final class const GrepOptions({
  /// Matching mode. Defaults to plain text.
  final GrepMode mode = .plainText,

  /// Maximum searchable file size in bytes; zero uses 10 MiB.
  final int maxFileSizeBytes = 0,

  /// Maximum matches returned per file; zero is unlimited.
  final int maxMatchesPerFile = 0,

  /// Use ASCII case-insensitive matching for all-lowercase queries.
  final bool smartCase = true,

  /// Candidate-file offset for pagination; zero starts at the first candidate.
  final int fileOffset = 0,

  /// Soft page limit; zero uses 50. FFF may finish the current file past it.
  final int pageLimit = 0,

  /// Best-effort time budget in milliseconds; zero is unlimited.
  final int timeBudgetMs = 0,

  /// Apply the time budget from the start for plain and regex searches.
  /// Fuzzy search uses a nonzero budget regardless of this flag.
  final bool enforceTimeBudget = false,

  /// Number of lines of context to include before each match.
  final int beforeContext = 0,

  /// Number of lines of context to include after each match.
  final int afterContext = 0,

  /// Ask FFF to heuristically mark code definitions.
  final bool classifyDefinitions = false,
});

/// Detached results from one content-search page.
final class GrepResult(
  List<GrepMatch> matches, {

  /// Number of positions advanced within the already-filtered candidate list.
  /// This includes candidates without matches or read failures, but excludes
  /// files removed during filtering.
  required final int candidateFilesConsumed,

  /// Number of indexed files before query filtering.
  required final int totalFiles,

  /// Number of candidate files eligible after query filtering.
  required final int filteredFileCount,

  /// Cursor for the next page, or zero when there are no remaining candidates.
  required final int nextFileOffset,

  /// Regex compilation diagnostic when FFF falls back to literal matching.
  required final String? regexFallbackError,
}) {
  /// Matches from this page in FFF's search order.
  final List<GrepMatch> matches = List.unmodifiable(matches);
}
