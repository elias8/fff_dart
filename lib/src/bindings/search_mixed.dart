import 'dart:ffi';

import 'package:ffi/ffi.dart';

import '../ffi/fff.g.dart';
import 'search_values.dart';
import 'types/result.dart';
import 'types/search.dart';
import 'types/string.dart';

MixedSearchResult searchMixed(
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
      () => fff_search_mixed(
        Pointer<Void>.fromAddress(handle),
        query.toNativeChar(arena, 'query'),
        currentFile.toNativeChar(arena, 'currentFile'),
        maxThreads,
        offset,
        pageSize,
        comboBoostMultiplier,
        minComboCount,
      ),
      operationName: 'FileFinder.searchMixed',
      decodeSuccess: (envelope) {
        final result = envelope.handle.cast<FffMixedSearchResult>();
        if (result == nullptr) {
          throw StateError('FFF returned a null mixed search result');
        }
        try {
          return _copyMixedSearchResult(result.ref);
        } finally {
          fff_free_mixed_search_result(result);
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

MixedItem _copyMixedItem(FffMixedItem item) => switch (item.item_type) {
  0 => FileItem(
    relativePath: copyRequiredSearchString(item.relative_path, 'relative path'),
    fileName: copyRequiredSearchString(item.display_name, 'file name'),
    gitStatus: copyRequiredSearchString(item.git_status, 'Git status'),
    size: item.size,
    modified: item.modified,
    accessFrecencyScore: item.access_frecency_score,
    modificationFrecencyScore: item.modification_frecency_score,
    totalFrecencyScore: item.total_frecency_score,
    isBinary: item.is_binary,
  ),
  1 => DirectoryItem(
    relativePath: copyRequiredSearchString(item.relative_path, 'relative path'),
    dirName: copyRequiredSearchString(item.display_name, 'directory name'),
    maxAccessFrecencyScore: item.access_frecency_score,
  ),
  final tag => throw StateError('FFF returned an unknown mixed item tag: $tag'),
};

MixedSearchResult _copyMixedSearchResult(FffMixedSearchResult result) {
  final count = result.count;
  if (count > 0 && (result.items == nullptr || result.scores == nullptr)) {
    throw StateError('FFF returned incomplete mixed search arrays');
  }

  final items = <MixedItem>[];
  final scores = <SearchScore>[];
  for (var index = 0; index < count; index++) {
    items.add(_copyMixedItem(result.items[index]));
    scores.add(copySearchScore(result.scores[index]));
  }
  return MixedSearchResult(
    items,
    scores,
    totalMatched: result.total_matched,
    totalFiles: result.total_files,
    totalDirectories: result.total_dirs,
    location: copySearchLocation(result.location),
  );
}
