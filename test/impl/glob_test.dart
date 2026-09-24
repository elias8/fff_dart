import 'dart:io';

import 'package:fff_dart/fff_dart.dart';
import 'package:test/test.dart';

void main() {
  group('GlobOptions', () {
    test('preserves native default sentinels', () {
      const options = GlobOptions();

      expect(options.maxThreads, 0);
      expect(options.currentFile, isNull);
      expect(options.offset, 0);
      expect(options.pageSize, 0);
    });
  });

  group('FileFinder.glob', () {
    late Directory root;
    FileFinder? finder;

    setUp(() {
      root = Directory.systemTemp.createTempSync('fff-glob-test-');
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

    test('matches files with a recursive pattern and frecency scores', () {
      File('${root.path}/lib/src/main.dart')
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('main');
      File('${root.path}/README.md').writeAsStringSync('readme');
      final instance = open();

      final result = instance.glob('**/*.dart');

      expect(result.items.map((item) => item.relativePath), [
        'lib/src/main.dart',
      ]);
      expect(result.totalMatched, 1);
      expect(result.totalFiles, 2);
      expect(result.location, isNull);
      expect(result.scores.single.matchType, 'frecency');
      expect(result.scores.single.baseScore, 0);
    });

    test('treats malformed patterns as empty matches', () {
      File('${root.path}/main.dart').writeAsStringSync('main');
      final instance = open();

      final result = instance.glob('[invalid');

      expect(result.items, isEmpty);
      expect(result.totalMatched, 0);
      expect(result.totalFiles, 1);
    });

    test('uses offset as the number of matching files to skip', () {
      File('${root.path}/one.dart').writeAsStringSync('one');
      File('${root.path}/two.dart').writeAsStringSync('two');
      File('${root.path}/three.dart').writeAsStringSync('three');
      final instance = open();

      final first = instance.glob(
        '*.dart',
        options: const GlobOptions(pageSize: 1),
      );
      final second = instance.glob(
        '*.dart',
        options: const GlobOptions(offset: 1, pageSize: 1),
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

    test('returns detached and immutable values', () {
      File('${root.path}/main.dart').writeAsStringSync('main');
      final instance = open();

      final result = instance.glob('*.dart');
      instance.dispose();

      expect(result.items.single.fileName, 'main.dart');
      expect(result.items.clear, throwsUnsupportedError);
      expect(result.scores.clear, throwsUnsupportedError);
    });

    test('rejects an empty pattern', () {
      final instance = open();

      SearchResult operation() => instance.glob('');

      expect(operation, throwsArgumentError);
    });

    test('rejects a pattern containing a NUL byte', () {
      final instance = open();

      SearchResult operation() => instance.glob('*.\u0000dart');

      expect(operation, throwsArgumentError);
    });

    test('rejects a current file containing a NUL byte', () {
      final instance = open();

      SearchResult operation() => instance.glob(
        '*.dart',
        options: const GlobOptions(currentFile: 'bad\u0000path'),
      );

      expect(operation, throwsArgumentError);
    });

    test('rejects a negative offset', () {
      final instance = open();

      SearchResult operation() =>
          instance.glob('*.dart', options: const GlobOptions(offset: -1));

      expect(operation, throwsRangeError);
    });

    test('rejects an offset above the C integer range', () {
      final instance = open();

      SearchResult operation() => instance.glob(
        '*.dart',
        options: const GlobOptions(offset: 0x100000000),
      );

      expect(operation, throwsRangeError);
    });

    test('rejects a page size above the C integer range', () {
      final instance = open();

      SearchResult operation() => instance.glob(
        '*.dart',
        options: const GlobOptions(pageSize: 0x100000000),
      );

      expect(operation, throwsRangeError);
    });

    test('rejects a thread count above the C integer range', () {
      final instance = open();

      SearchResult operation() => instance.glob(
        '*.dart',
        options: const GlobOptions(maxThreads: 0x100000000),
      );

      expect(operation, throwsRangeError);
    });

    test('rejects use after disposal', () {
      final instance = open()..dispose();

      SearchResult operation() => instance.glob('*.dart');

      expect(operation, throwsStateError);
    });
  });
}
