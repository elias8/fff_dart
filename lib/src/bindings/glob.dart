import 'dart:ffi';

import 'package:ffi/ffi.dart';

import '../ffi/fff.g.dart';
import 'search_values.dart';
import 'types/result.dart';
import 'types/search.dart';
import 'types/string.dart';

SearchResult glob(
  int handle,
  String pattern, {
  required String? currentFile,
  required int maxThreads,
  required int offset,
  required int pageSize,
}) {
  if (pattern.isEmpty) {
    throw ArgumentError.value(pattern, 'pattern', 'Must not be empty');
  }
  _checkUint32(maxThreads, 'maxThreads');
  _checkUint32(offset, 'offset');
  _checkUint32(pageSize, 'pageSize');

  return using((arena) {
    return decodeFffResult(
      () => fff_glob(
        Pointer<Void>.fromAddress(handle),
        pattern.toNativeChar(arena, 'pattern'),
        currentFile.toNativeChar(arena, 'currentFile'),
        maxThreads,
        offset,
        pageSize,
      ),
      operationName: 'FileFinder.glob',
      decodeSuccess: (envelope) {
        final result = envelope.handle.cast<FffSearchResult>();
        if (result == nullptr) {
          throw StateError('FFF returned a null glob result');
        }
        try {
          return copySearchResult(result.ref);
        } finally {
          fff_free_search_result(result);
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
