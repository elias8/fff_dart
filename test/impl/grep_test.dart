import 'dart:io';

import 'package:fff_dart/fff_dart.dart';
import 'package:test/test.dart';

void main() {
  group('GrepOptions', () {
    test('preserves native default sentinels', () {
      const options = GrepOptions();

      expect(options.mode, GrepMode.plainText);
      expect(options.maxFileSizeBytes, 0);
      expect(options.maxMatchesPerFile, 0);
      expect(options.smartCase, isTrue);
      expect(options.fileOffset, 0);
      expect(options.pageLimit, 0);
      expect(options.timeBudgetMs, 0);
      expect(options.enforceTimeBudget, isFalse);
      expect(options.beforeContext, 0);
      expect(options.afterContext, 0);
      expect(options.classifyDefinitions, isFalse);
    });
  });

  group('FileFinder.grep', () {
    late Directory root;
    FileFinder? finder;

    setUp(() {
      root = Directory.systemTemp.createTempSync('fff-grep-test-');
    });

    tearDown(() {
      finder?.dispose();
      root.deleteSync(recursive: true);
    });

    FileFinder open() {
      final instance = FileFinder.open(
        root.path,
        options: const FffOptions(watch: false),
      );
      finder = instance;
      instance.waitForScan(const Duration(seconds: 30));
      return instance;
    }

    test('returns detached match data and candidate pagination metadata', () {
      File('${root.path}/src/main.dart')
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('first\nλneedle here\nlast\n');
      final instance = open();

      final result = instance.grep(
        'needle',
        options: const GrepOptions(beforeContext: 1, afterContext: 1),
      );
      instance.dispose();

      expect(result.matches, hasLength(1));
      expect(result.matches.single.relativePath, 'src/main.dart');
      expect(result.matches.single.fileName, 'main.dart');
      expect(result.matches.single.lineContent, 'λneedle here');
      expect(result.matches.single.lineNumber, 2);
      expect(result.matches.single.lineByteOffset, 6);
      expect(result.matches.single.columnByteOffset, 2);
      expect(result.matches.single.matchRanges.single.startByte, 2);
      expect(result.matches.single.matchRanges.single.endByte, 8);
      expect(result.matches.single.contextBefore, ['first']);
      expect(result.matches.single.contextAfter, ['last']);
      expect(result.candidateFilesConsumed, 1);
      expect(result.totalFiles, 1);
      expect(result.filteredFileCount, 1);
      expect(result.nextFileOffset, 0);
      expect(result.regexFallbackError, isNull);
      expect(result.matches.clear, throwsUnsupportedError);
      expect(result.matches.single.contextBefore.clear, throwsUnsupportedError);
      expect(result.matches.single.matchRanges.clear, throwsUnsupportedError);
    });

    test(
      'returns regex compile errors when matching falls back to literal',
      () {
        File('${root.path}/main.txt').writeAsStringSync('needle [\n');
        final instance = open();

        final result = instance.grep(
          '[',
          options: const GrepOptions(mode: .regex),
        );

        expect(result.matches, hasLength(1));
        expect(result.regexFallbackError, isNotEmpty);
      },
    );

    test('exposes fuzzy score only when the native result has one', () {
      File('${root.path}/main.txt').writeAsStringSync('needle\n');
      final instance = open();

      final literal = instance.grep('needle');
      final fuzzy = instance.grep(
        'needle',
        options: const GrepOptions(mode: .fuzzy),
      );

      expect(literal.matches.single.fuzzyScore, isNull);
      expect(fuzzy.matches.single.fuzzyScore, isNotNull);
    });

    test('applies smart case in literal mode', () {
      File('${root.path}/main.txt').writeAsStringSync('needle\nNeedle\n');
      final instance = open();

      final sensitive = instance.grep('Needle');
      final insensitive = instance.grep('needle');

      expect(sensitive.matches, hasLength(1));
      expect(insensitive.matches, hasLength(2));
    });

    test('classifies code definitions when requested', () {
      File('${root.path}/main.dart').writeAsStringSync('class NeedleType {}\n');
      final instance = open();

      final result = instance.grep(
        'NeedleType',
        options: const GrepOptions(classifyDefinitions: true),
      );

      expect(result.matches.single.isDefinition, isTrue);
    });

    test('allows an empty query and returns no matches', () {
      File('${root.path}/main.txt').writeAsStringSync('content\n');
      final instance = open();

      final result = instance.grep('');

      expect(result.matches, isEmpty);
    });

    test('retries a parsed no-match query as literal without a diagnostic', () {
      File('${root.path}/main.dart').writeAsStringSync('*.rs needle\n');
      final instance = open();

      final result = instance.grep('*.rs needle');

      expect(result.matches, hasLength(1));
      expect(result.matches.single.relativePath, 'main.dart');
      expect(result.regexFallbackError, isNull);
    });

    test('keeps source byte coordinates when invalid UTF-8 is decoded', () {
      File('${root.path}/main.txt')
          .writeAsBytesSync([0xff, 110, 101, 101, 100, 108, 101, 10]);
      final instance = open();

      final result = instance.grep('needle');
      final match = result.matches.single;

      expect(match.lineContent, '\uFFFDneedle');
      expect(match.columnByteOffset, 1);
      expect(match.matchRanges.single.startByte, 1);
      expect(match.matchRanges.single.endByte, 7);
    });

    test('continues with the next candidate file offset', () {
      File('${root.path}/one.txt').writeAsStringSync('needle one\n');
      File('${root.path}/two.txt').writeAsStringSync('needle two\n');
      File('${root.path}/three.txt').writeAsStringSync('needle three\n');
      final instance = open();

      final first = instance.grep(
        'needle',
        options: const GrepOptions(pageLimit: 1),
      );
      final second = instance.grep(
        'needle',
        options: GrepOptions(fileOffset: first.nextFileOffset, pageLimit: 1),
      );

      expect(first.matches, hasLength(1));
      expect(second.matches, hasLength(1));
      expect(first.nextFileOffset, greaterThan(0));
      expect(
        second.matches.single.relativePath,
        isNot(first.matches.single.relativePath),
      );
    });

    test('rejects NUL queries and values outside native integer ranges', () {
      final instance = open();

      GrepResult nulQuery() => instance.grep('needle\u0000');
      GrepResult invalidMode() => instance.grep(
        'needle',
        options: const GrepOptions(maxFileSizeBytes: -1),
      );
      GrepResult overflow() => instance.grep(
        'needle',
        options: const GrepOptions(pageLimit: 0x100000000),
      );
      GrepResult contextOverflow() => instance.grep(
        'needle',
        options: const GrepOptions(afterContext: 0x100000000),
      );

      expect(nulQuery, throwsArgumentError);
      expect(invalidMode, throwsRangeError);
      expect(overflow, throwsRangeError);
      expect(contextOverflow, throwsRangeError);
    });

    test('rejects use after disposal', () {
      final instance = open()..dispose();

      GrepResult operation() => instance.grep('needle');

      expect(operation, throwsStateError);
    });
  });
}
