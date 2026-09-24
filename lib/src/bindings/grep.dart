import 'dart:ffi';

import 'package:ffi/ffi.dart';

import '../ffi/fff.g.dart';
import 'types/grep.dart';
import 'types/result.dart';
import 'types/string.dart';

final _emptyGrepMatch = GrepMatch(
  relativePath: '',
  fileName: '',
  gitStatus: '',
  lineContent: '',
  matchRanges: [],
  contextBefore: [],
  contextAfter: [],
  size: 0,
  modified: 0,
  totalFrecencyScore: 0,
  accessFrecencyScore: 0,
  modificationFrecencyScore: 0,
  lineNumber: 0,
  lineByteOffset: 0,
  columnByteOffset: 0,
  fuzzyScore: null,
  isBinary: false,
  isDefinition: false,
);
const _emptyMatchRange = GrepMatchRange(startByte: 0, endByte: 0);

GrepResult liveGrepEx(
  int handle,
  String query, {
  required GrepOptions options,
}) {
  _checkUint64(options.maxFileSizeBytes, 'maxFileSizeBytes');
  _checkUint32(options.maxMatchesPerFile, 'maxMatchesPerFile');
  _checkUint32(options.fileOffset, 'fileOffset');
  _checkUint32(options.pageLimit, 'pageLimit');
  _checkUint64(options.timeBudgetMs, 'timeBudgetMs');
  _checkUint32(options.beforeContext, 'beforeContext');
  _checkUint32(options.afterContext, 'afterContext');

  return using((arena) {
    return decodeFffResult(
      () => fff_live_grep_ex(
        Pointer<Void>.fromAddress(handle),
        query.toNativeChar(arena, 'query'),
        _nativeGrepMode(options.mode),
        options.maxFileSizeBytes,
        options.maxMatchesPerFile,
        options.smartCase,
        options.fileOffset,
        options.pageLimit,
        options.timeBudgetMs,
        options.enforceTimeBudget,
        options.beforeContext,
        options.afterContext,
        options.classifyDefinitions,
      ),
      operationName: 'FileFinder.grep',
      decodeSuccess: (envelope) {
        final result = envelope.handle.cast<FffGrepResult>();
        if (result == nullptr) {
          throw StateError('FFF returned a null grep result');
        }
        try {
          return _copyGrepResult(result);
        } finally {
          fff_free_grep_result(result);
        }
      },
    );
  });
}

GrepResult multiGrepEx(
  int handle,
  Iterable<String> patterns, {
  required MultiGrepOptions options,
}) {
  final patternList = _validatedPatterns(patterns);
  _checkUint64(options.maxFileSizeBytes, 'maxFileSizeBytes');
  _checkUint32(options.maxMatchesPerFile, 'maxMatchesPerFile');
  _checkUint32(options.fileOffset, 'fileOffset');
  _checkUint32(options.pageLimit, 'pageLimit');
  _checkUint64(options.timeBudgetMs, 'timeBudgetMs');
  _checkUint32(options.beforeContext, 'beforeContext');
  _checkUint32(options.afterContext, 'afterContext');

  return using((arena) {
    return decodeFffResult(
      () => fff_multi_grep_ex(
        Pointer<Void>.fromAddress(handle),
        patternList.join('\n').toNativeChar(arena, 'patterns'),
        options.constraints.toNativeChar(arena, 'constraints'),
        options.maxFileSizeBytes,
        options.maxMatchesPerFile,
        options.smartCase,
        options.fileOffset,
        options.pageLimit,
        options.timeBudgetMs,
        options.enforceTimeBudget,
        options.beforeContext,
        options.afterContext,
        options.classifyDefinitions,
      ),
      operationName: 'FileFinder.multiGrep',
      decodeSuccess: (envelope) {
        final result = envelope.handle.cast<FffGrepResult>();
        if (result == nullptr) {
          throw StateError('FFF returned a null multi-grep result');
        }
        try {
          return _copyGrepResult(result);
        } finally {
          fff_free_grep_result(result);
        }
      },
    );
  });
}

List<String> _validatedPatterns(Iterable<String> patterns) {
  final values = patterns.toList(growable: false);
  if (values.isEmpty) {
    throw ArgumentError.value(patterns, 'patterns', 'Must not be empty');
  }
  for (final pattern in values) {
    if (pattern.isEmpty) {
      throw ArgumentError.value(
        pattern,
        'patterns',
        'Patterns must not be empty',
      );
    }
    if (pattern.contains('\n')) {
      throw ArgumentError.value(
        pattern,
        'patterns',
        'Patterns must not contain a newline',
      );
    }
    if (pattern.contains('\u0000')) {
      throw ArgumentError.value(
        pattern,
        'patterns',
        'Must not contain a NUL byte',
      );
    }
  }
  return values;
}

void _checkUint32(int value, String name) {
  if (value < 0 || value > 0xffffffff) {
    throw RangeError.range(value, 0, 0xffffffff, name);
  }
}

void _checkUint64(int value, String name) {
  if (value < 0 || value > 0x7fffffffffffffff) {
    throw RangeError.range(value, 0, 0x7fffffffffffffff, name);
  }
}

List<String> _copyContextLines(
  Pointer<FffGrepMatch> match,
  int count,
  Pointer<Char> Function(Pointer<FffGrepMatch>, int) getLine,
) {
  final lines = List<String>.filled(count, '');
  for (var index = 0; index < count; index++) {
    final line = getLine(match, index);
    if (line == nullptr) {
      throw StateError('FFF returned a null context line at index $index');
    }
    lines[index] = line.toDartString();
  }
  return lines;
}

GrepMatch _copyGrepMatch(Pointer<FffGrepMatch> pointer) {
  final match = pointer.ref;
  final ranges = List<GrepMatchRange>.filled(
    match.match_ranges_count,
    _emptyMatchRange,
  );
  for (var index = 0; index < ranges.length; index++) {
    final range = fff_grep_match_get_match_range(pointer, index);
    if (range == nullptr) {
      throw StateError('FFF returned a null match range at index $index');
    }
    final value = range.ref;
    ranges[index] = GrepMatchRange(startByte: value.start, endByte: value.end);
  }
  final contextBefore = _copyContextLines(
    pointer,
    fff_grep_match_get_context_before_count(pointer),
    fff_grep_match_get_context_before,
  );
  final contextAfter = _copyContextLines(
    pointer,
    fff_grep_match_get_context_after_count(pointer),
    fff_grep_match_get_context_after,
  );
  return GrepMatch(
    relativePath: _requiredString(match.relative_path, 'relative path'),
    fileName: _requiredString(match.file_name, 'file name'),
    gitStatus: _requiredString(match.git_status, 'git status'),
    lineContent: _requiredString(match.line_content, 'line content'),
    matchRanges: ranges,
    contextBefore: contextBefore,
    contextAfter: contextAfter,
    size: match.size,
    modified: match.modified,
    totalFrecencyScore: match.total_frecency_score,
    accessFrecencyScore: match.access_frecency_score,
    modificationFrecencyScore: match.modification_frecency_score,
    lineNumber: match.line_number,
    lineByteOffset: match.byte_offset,
    columnByteOffset: match.col,
    fuzzyScore: match.has_fuzzy_score ? match.fuzzy_score : null,
    isBinary: match.is_binary,
    isDefinition: match.is_definition,
  );
}

int _nativeGrepMode(GrepMode mode) => switch (mode) {
  .plainText => 0,
  .regex => 1,
  .fuzzy => 2,
};

GrepResult _copyGrepResult(Pointer<FffGrepResult> pointer) {
  final result = pointer.ref;
  final matches = List<GrepMatch>.filled(result.count, _emptyGrepMatch);
  for (var index = 0; index < matches.length; index++) {
    final matchPointer = fff_grep_result_get_match(pointer, index);
    if (matchPointer == nullptr) {
      throw StateError('FFF returned a null grep match at index $index');
    }
    matches[index] = _copyGrepMatch(matchPointer);
  }
  return GrepResult(
    matches,
    candidateFilesConsumed: result.total_files_searched,
    totalFiles: result.total_files,
    filteredFileCount: result.filtered_file_count,
    nextFileOffset: result.next_file_offset,
    regexFallbackError: result.regex_fallback_error.toDartStringOrNull(),
  );
}

String _requiredString(Pointer<Char> pointer, String name) {
  if (pointer == nullptr) throw StateError('FFF returned a null $name');
  return pointer.toDartString();
}
