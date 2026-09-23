/// A location parsed from a search query.
///
/// Line and column values are returned as parsed by FFF.
sealed class const SearchLocation();

/// A query location that identifies one line.
final class const SearchLineLocation(final int line) extends SearchLocation;

/// A query location that identifies one line and column.
final class const SearchPositionLocation(final int line, final int column)
    extends SearchLocation;

/// A query location that identifies a range of lines and columns.
final class const SearchRangeLocation({
  required final int startLine,
  required final int startColumn,
  required final int endLine,
  required final int endColumn,
}) extends SearchLocation;
