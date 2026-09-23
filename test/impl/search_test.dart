import 'dart:io';

import 'package:fff_dart/fff_dart.dart';
import 'package:test/test.dart';

void main() {
  group('SearchOptions', () {
    test('preserves native default sentinels', () {
      const options = SearchOptions();

      expect(options.maxThreads, 0);
      expect(options.currentFile, isNull);
      expect(options.comboBoostMultiplier, 0);
      expect(options.minComboCount, 0);
      expect(options.offset, 0);
      expect(options.pageSize, 0);
    });
  });

  group('FileFinder.searchFile', () {
    late Directory root;
    FileFinder? finder;

    setUp(() {
      root = Directory.systemTemp.createTempSync('fff-search-test-');
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

    test('returns detached file and score values', () {
      final source = File('${root.path}/src/main.dart')
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('void main() {}\n');
      final instance = open();

      final result = instance.searchFile('main');
      instance.dispose();

      final item = result.items.single;
      final score = result.scores.single;
      expect(item.relativePath, 'src/main.dart');
      expect(item.fileName, 'main.dart');
      expect(item.size, source.lengthSync());
      expect(item.modified, greaterThan(0));
      expect(item.gitStatus, isNotEmpty);
      expect(item.isBinary, isFalse);
      expect(score.total, isA<int>());
      expect(score.baseScore, isA<int>());
      expect(score.filenameBonus, isA<int>());
      expect(score.specialFilenameBonus, isA<int>());
      expect(score.frecencyBoost, isA<int>());
      expect(score.distancePenalty, isA<int>());
      expect(score.currentFilePenalty, isA<int>());
      expect(score.comboMatchBoost, isA<int>());
      expect(score.pathAlignmentBonus, isA<int>());
      expect(score.exactMatch, isA<bool>());
      expect(score.matchType, isNotEmpty);
      expect(result.items, hasLength(result.scores.length));
    });

    test('returns immutable result lists', () {
      File('${root.path}/main.dart').writeAsStringSync('main');
      final instance = open();
      final result = instance.searchFile('main');

      expect(result.items.clear, throwsUnsupportedError);
      expect(result.scores.clear, throwsUnsupportedError);
    });

    test('reports binary files', () {
      File('${root.path}/payload.bin').writeAsBytesSync([0, 1, 2]);
      final instance = open();

      final result = instance.searchFile('payload');

      expect(result.items.single.isBinary, isTrue);
    });

    test('returns total counts when there are no matches', () {
      File('${root.path}/known.txt').writeAsStringSync('known');
      final instance = open();

      final result = instance.searchFile('no-such-file-token');

      expect(result.items, isEmpty);
      expect(result.scores, isEmpty);
      expect(result.totalMatched, 0);
      expect(result.totalFiles, 1);
      expect(result.location, isNull);
    });

    test('uses offset as the number of results to skip', () {
      File('${root.path}/match-one.txt').writeAsStringSync('match-one');
      File('${root.path}/match-two.txt').writeAsStringSync('match-two');
      File('${root.path}/match-three.txt').writeAsStringSync('match-three');
      final instance = open();

      final first = instance.searchFile(
        'match',
        options: const SearchOptions(pageSize: 1),
      );
      final second = instance.searchFile(
        'match',
        options: const SearchOptions(offset: 1, pageSize: 1),
      );

      expect(first.items, hasLength(1));
      expect(second.items, hasLength(1));
      expect(first.totalMatched, 3);
      expect(second.totalMatched, 3);
      expect(
        second.items.single.relativePath,
        isNot(first.items.single.relativePath),
      );
    });

    test('returns a parsed line location', () {
      File('${root.path}/main.dart').writeAsStringSync('main');
      final instance = open();

      final result = instance.searchFile('main.dart:12');

      expect(
        result.location,
        isA<SearchLineLocation>().having((value) => value.line, 'line', 12),
      );
    });

    test('returns a parsed position location', () {
      File('${root.path}/main.dart').writeAsStringSync('main');
      final instance = open();

      final result = instance.searchFile('main.dart:12:4');

      expect(
        result.location,
        isA<SearchPositionLocation>()
            .having((value) => value.line, 'line', 12)
            .having((value) => value.column, 'column', 4),
      );
    });

    test('returns a parsed range location', () {
      File('${root.path}/main.dart').writeAsStringSync('main');
      final instance = open();

      final result = instance.searchFile('main.dart:12:4-14:20');

      expect(
        result.location,
        isA<SearchRangeLocation>()
            .having((value) => value.startLine, 'start line', 12)
            .having((value) => value.startColumn, 'start column', 4)
            .having((value) => value.endLine, 'end line', 14)
            .having((value) => value.endColumn, 'end column', 20),
      );
    });

    test('rejects a query containing a NUL byte', () {
      final instance = open();

      SearchResult operation() => instance.searchFile('bad\u0000query');

      expect(operation, throwsArgumentError);
    });

    test('rejects a current file containing a NUL byte', () {
      final instance = open();

      SearchResult operation() => instance.searchFile(
        'main',
        options: const SearchOptions(currentFile: 'bad\u0000path'),
      );

      expect(operation, throwsArgumentError);
    });

    test('rejects use after disposal', () {
      final instance = open()..dispose();

      SearchResult operation() => instance.searchFile('main');

      expect(operation, throwsStateError);
    });

    test('rejects a negative offset', () {
      final instance = open();

      SearchResult operation() =>
          instance.searchFile('main', options: const SearchOptions(offset: -1));

      expect(operation, throwsRangeError);
    });

    test('rejects an offset above the C integer range', () {
      final instance = open();

      SearchResult operation() => instance.searchFile(
        'main',
        options: const SearchOptions(offset: 0x100000000),
      );

      expect(operation, throwsRangeError);
    });

    test('rejects a thread count above the C integer range', () {
      final instance = open();

      SearchResult operation() => instance.searchFile(
        'main',
        options: const SearchOptions(maxThreads: 0x100000000),
      );

      expect(operation, throwsRangeError);
    });

    test('rejects a page size above the C integer range', () {
      final instance = open();

      SearchResult operation() => instance.searchFile(
        'main',
        options: const SearchOptions(pageSize: 0x100000000),
      );

      expect(operation, throwsRangeError);
    });

    test('rejects a combo count above the C integer range', () {
      final instance = open();

      SearchResult operation() => instance.searchFile(
        'main',
        options: const SearchOptions(minComboCount: 0x100000000),
      );

      expect(operation, throwsRangeError);
    });

    test('rejects a combo multiplier outside the C integer range', () {
      final instance = open();

      SearchResult operation() => instance.searchFile(
        'main',
        options: const SearchOptions(comboBoostMultiplier: 0x80000000),
      );

      expect(operation, throwsRangeError);
    });

    test('rejects a combo multiplier below the C integer range', () {
      final instance = open();

      SearchResult operation() => instance.searchFile(
        'main',
        options: const SearchOptions(comboBoostMultiplier: -0x80000001),
      );

      expect(operation, throwsRangeError);
    });

    test('accepts a negative signed combo multiplier', () {
      File('${root.path}/main.dart').writeAsStringSync('main');
      final instance = open();

      final result = instance.searchFile(
        'main',
        options: const SearchOptions(comboBoostMultiplier: -1),
      );

      expect(result.items, isNotEmpty);
    });
  });
}
