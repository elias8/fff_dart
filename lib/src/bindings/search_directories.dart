import 'dart:ffi';

import 'package:ffi/ffi.dart';

import '../ffi/fff.g.dart';
import 'search_values.dart';
import 'types/result.dart';
import 'types/search.dart';
import 'types/string.dart';

DirectorySearchResult searchDirectories(
  int handle,
  String query, {
  required String? currentFile,
  required int maxThreads,
  required int offset,
  required int pageSize,
}) {
  _checkUint32(maxThreads, 'maxThreads');
  _checkUint32(offset, 'offset');
  _checkUint32(pageSize, 'pageSize');

  return using((arena) {
    return decodeFffResult(
      () => fff_search_directories(
        Pointer<Void>.fromAddress(handle),
        query.toNativeChar(arena, 'query'),
        currentFile.toNativeChar(arena, 'currentFile'),
        maxThreads,
        offset,
        pageSize,
      ),
      operationName: 'FileFinder.searchDirectories',
      decodeSuccess: (envelope) {
        final result = envelope.handle.cast<FffDirSearchResult>();
        if (result == nullptr) {
          throw StateError('FFF returned a null directory search result');
        }
        try {
          return _copyDirectorySearchResult(result.ref);
        } finally {
          fff_free_dir_search_result(result);
        }
      },
    );
  });
}

void _checkUint32(int value, String name) {
  if (value < 0 || value > 0xffffffff) {
    throw RangeError.range(value, 0, 0xffffffff, name);
  }
}

DirectoryItem _copyDirectoryItem(FffDirItem item) {
  final relativePath = copyRequiredSearchString(
    item.relative_path,
    'relative path',
  );
  final dirName = copyRequiredSearchString(item.dir_name, 'directory name');
  return DirectoryItem(
    relativePath: relativePath,
    dirName: dirName,
    maxAccessFrecencyScore: item.max_access_frecency,
  );
}

DirectorySearchResult _copyDirectorySearchResult(FffDirSearchResult result) {
  final count = result.count;
  if (count > 0 && (result.items == nullptr || result.scores == nullptr)) {
    throw StateError('FFF returned incomplete directory search arrays');
  }

  final items = <DirectoryItem>[];
  final scores = <SearchScore>[];
  for (var index = 0; index < count; index++) {
    items.add(_copyDirectoryItem(result.items[index]));
    scores.add(copySearchScore(result.scores[index]));
  }
  return DirectorySearchResult(
    items,
    scores,
    totalMatched: result.total_matched,
    totalDirectories: result.total_dirs,
  );
}
