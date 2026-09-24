import 'dart:ffi';

import '../ffi/fff.g.dart';
import 'types/search.dart';
import 'types/search_location.dart';
import 'types/string.dart';

String copyRequiredSearchString(Pointer<Char> pointer, String field) {
  if (pointer == nullptr) {
    throw StateError('FFF returned a null $field');
  }
  return pointer.toDartString();
}

SearchLocation? copySearchLocation(FffLocation location) =>
    switch (location.tag) {
      0 => null,
      1 => SearchLineLocation(location.line),
      2 => SearchPositionLocation(location.line, location.col),
      3 => SearchRangeLocation(
        startLine: location.line,
        startColumn: location.col,
        endLine: location.end_line,
        endColumn: location.end_col,
      ),
      final tag => throw StateError(
        'FFF returned an unknown location tag: $tag',
      ),
    };

SearchResult copySearchResult(FffSearchResult result) {
  final count = result.count;
  if (count > 0 && (result.items == nullptr || result.scores == nullptr)) {
    throw StateError('FFF returned incomplete search result arrays');
  }

  final items = <FileItem>[];
  final scores = <SearchScore>[];
  for (var index = 0; index < count; index++) {
    items.add(_copyFileItem(result.items[index]));
    scores.add(copySearchScore(result.scores[index]));
  }
  return SearchResult(
    items,
    scores,
    totalMatched: result.total_matched,
    totalFiles: result.total_files,
    location: copySearchLocation(result.location),
  );
}

SearchScore copySearchScore(FffScore score) {
  final matchType = score.match_type;
  if (matchType == nullptr) {
    throw StateError('FFF returned a null match type');
  }
  return SearchScore(
    total: score.total,
    baseScore: score.base_score,
    filenameBonus: score.filename_bonus,
    specialFilenameBonus: score.special_filename_bonus,
    frecencyBoost: score.frecency_boost,
    distancePenalty: score.distance_penalty,
    currentFilePenalty: score.current_file_penalty,
    comboMatchBoost: score.combo_match_boost,
    pathAlignmentBonus: score.path_alignment_bonus,
    exactMatch: score.exact_match,
    matchType: matchType.toDartString(),
  );
}

FileItem _copyFileItem(FffFileItem item) => FileItem(
  relativePath: copyRequiredSearchString(item.relative_path, 'relative path'),
  fileName: copyRequiredSearchString(item.file_name, 'file name'),
  gitStatus: copyRequiredSearchString(item.git_status, 'Git status'),
  size: item.size,
  modified: item.modified,
  accessFrecencyScore: item.access_frecency_score,
  modificationFrecencyScore: item.modification_frecency_score,
  totalFrecencyScore: item.total_frecency_score,
  isBinary: item.is_binary,
);
