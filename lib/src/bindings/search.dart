import 'dart:ffi';

import 'package:ffi/ffi.dart';

import '../ffi/fff.g.dart';
import 'search_values.dart';
import 'types/result.dart';
import 'types/search.dart';
import 'types/search_location.dart';
import 'types/string.dart';

SearchResult search(
  int handle,
  String query, {
  required String? currentFile,
  required int maxThreads,
  required int offset,
  required int pageSize,
  required int comboBoostMultiplier,
  required int minComboCount,
}) {
  _checkUint32(maxThreads, 'maxThreads');
  _checkUint32(offset, 'offset');
  _checkUint32(pageSize, 'pageSize');
  _checkInt32(comboBoostMultiplier, 'comboBoostMultiplier');
  _checkUint32(minComboCount, 'minComboCount');

  return using((arena) {
    return decodeFffResult(
      () => fff_search(
        Pointer<Void>.fromAddress(handle),
        query.toNativeChar(arena, 'query'),
        currentFile.toNativeChar(arena, 'currentFile'),
        maxThreads,
        offset,
        pageSize,
        comboBoostMultiplier,
        minComboCount,
      ),
      operationName: 'FileFinder.searchFile',
      decodeSuccess: (envelope) {
        final result = envelope.handle.cast<FffSearchResult>();
        if (result == nullptr) {
          throw StateError('FFF returned a null search result');
        }
        try {
          return _copySearchResult(result.ref);
        } finally {
          fff_free_search_result(result);
        }
      },
    );
  });
}

void _checkInt32(int value, String name) {
  if (value < -0x80000000 || value > 0x7fffffff) {
    throw RangeError.range(value, -0x80000000, 0x7fffffff, name);
  }
}

void _checkUint32(int value, String name) {
  if (value < 0 || value > 0xffffffff) {
    throw RangeError.range(value, 0, 0xffffffff, name);
  }
}

FileItem _copyFileItem(FffFileItem item) {
  final relativePath = copyRequiredSearchString(
    item.relative_path,
    'relative path',
  );
  final fileName = copyRequiredSearchString(item.file_name, 'file name');
  final gitStatus = copyRequiredSearchString(item.git_status, 'Git status');
  return FileItem(
    relativePath: relativePath,
    fileName: fileName,
    gitStatus: gitStatus,
    size: item.size,
    modified: item.modified,
    accessFrecencyScore: item.access_frecency_score,
    modificationFrecencyScore: item.modification_frecency_score,
    totalFrecencyScore: item.total_frecency_score,
    isBinary: item.is_binary,
  );
}

SearchLocation? _copyLocation(FffLocation location) => switch (location.tag) {
  0 => null,
  1 => SearchLineLocation(location.line),
  2 => SearchPositionLocation(location.line, location.col),
  3 => SearchRangeLocation(
    startLine: location.line,
    startColumn: location.col,
    endLine: location.end_line,
    endColumn: location.end_col,
  ),
  final tag => throw StateError('FFF returned an unknown location tag: $tag'),
};

SearchResult _copySearchResult(FffSearchResult result) {
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
    location: _copyLocation(result.location),
  );
}
