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
