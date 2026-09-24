import 'dart:io';

import 'package:fff_dart/fff_dart.dart';
import 'package:test/test.dart';

void main() {
  group('FileFinder', () {
    group('searchMixed', () {
      late Directory root;
      FileFinder? finder;

      setUp(() {
        root = Directory.systemTemp.createTempSync('fff-mixed-search-');
      });

      tearDown(() {
        finder?.dispose();
        root.deleteSync(recursive: true);
      });

      FileFinder open() {
        final instance = FileFinder.open(
          root.path,
          options: const FffOptions(watch: false, enableContentIndexing: false),
        );
        finder = instance;
        instance.waitForScan(const Duration(seconds: 30));
        return instance;
      }

      void createFile(String name) {
        File('${root.path}/$name')
          ..parent.createSync(recursive: true)
          ..writeAsStringSync('mixed search fixture');
      }

      void createDirectory(String name) {
        createFile('$name/marker.txt');
      }

      test('returns file and directory entries', () {
        createFile('target_file.txt');
        createDirectory('target_directory');
        final result = open().searchMixed('target');

        expect(result.items.whereType<FileItem>(), hasLength(2));
        expect(result.items.whereType<DirectoryItem>(), hasLength(1));
      });

      test('copies file fields into detached values', () {
        createFile('target_file.txt');
        final instance = open();

        final result = instance.searchMixed('target_file.txt');
        instance.dispose();

        final item = result.items.whereType<FileItem>().single;
        expect(item.relativePath, 'target_file.txt');
        expect(item.fileName, 'target_file.txt');
        expect(item.gitStatus, isA<String>());
        expect(item.size, greaterThan(0));
        expect(item.modified, greaterThan(0));
        expect(item.accessFrecencyScore, isA<int>());
        expect(item.modificationFrecencyScore, isA<int>());
        expect(item.totalFrecencyScore, isA<int>());
        expect(item.isBinary, isFalse);
      });

      test('copies directory fields into detached values', () {
        createDirectory('target_directory');
        final instance = open();

        final result = instance.searchMixed('target_directory');
        instance.dispose();

        final item = result.items.whereType<DirectoryItem>().single;
        expect(item.relativePath, 'target_directory/');
        expect(item.dirName, 'target_directory/');
        expect(item.maxAccessFrecencyScore, isA<int>());
      });

      test('returns aligned scores in descending total order', () {
        createFile('target_alpha.txt');
        createFile('target_beta.txt');
        createDirectory('target_directory');
        final result = open().searchMixed('target');

        expect(result.items, hasLength(result.scores.length));
        expect(
          result.scores,
          isSortedByCompare<SearchScore, int>(
            (score) => score.total,
            (left, right) => right.compareTo(left),
          ),
        );
      });

      test('reports file and directory totals', () {
        createFile('target_file.txt');
        createDirectory('target_directory');
        final result = open().searchMixed('target');

        expect(result.totalMatched, 3);
        expect(result.totalFiles, 2);
        expect(result.totalDirectories, 2);
      });

      test('returns frecency-ranked results for an empty query', () {
        createFile('target_file.txt');
        createDirectory('target_directory');
        final result = open().searchMixed('');

        expect(result.items, isNotEmpty);
        expect(result.items, hasLength(result.scores.length));
        expect(
          result.scores.map((score) => score.matchType),
          everyElement('frecency'),
        );
      });

      test('searches only directories when the query ends with a slash', () {
        createFile('target_file.txt');
        createDirectory('target_directory');
        final result = open().searchMixed('target/');

        expect(result.items.whereType<FileItem>(), isEmpty);
        expect(result.items.whereType<DirectoryItem>(), hasLength(1));
      });

      test('uses offset as the number of mixed results to skip', () {
        createFile('target_alpha.txt');
        createFile('target_beta.txt');
        createDirectory('target_directory');
        final instance = open();

        final first = instance.searchMixed(
          'target',
          options: const SearchOptions(pageSize: 1),
        );
        final second = instance.searchMixed(
          'target',
          options: const SearchOptions(offset: 1, pageSize: 1),
        );

        expect(first.items, hasLength(1));
        expect(second.items, hasLength(1));
        expect(first.items.single, isNot(second.items.single));
        expect(first.totalMatched, 4);
      });

      test('returns a parsed query location', () {
        createFile('target_file.txt');
        final result = open().searchMixed('target_file:12');

        expect(result.location, isA<SearchLineLocation>());
        expect((result.location! as SearchLineLocation).line, 12);
      });

      test('returns empty lists and zero matches when no entries match', () {
        createFile('target_file.txt');
        final result = open().searchMixed('zzzzzzzz');

        expect(result.items, isEmpty);
        expect(result.scores, isEmpty);
        expect(result.totalMatched, 0);
        expect(result.totalFiles, 1);
        expect(result.totalDirectories, 1);
      });

      test('returns immutable item lists', () {
        createFile('target_file.txt');
        final result = open().searchMixed('target');

        expect(result.items.clear, throwsUnsupportedError);
      });

      test('returns immutable score lists', () {
        createFile('target_file.txt');
        final result = open().searchMixed('target');

        expect(result.scores.clear, throwsUnsupportedError);
      });

      test('rejects a query containing a NUL byte', () {
        final instance = open();

        expect(
          () => instance.searchMixed('target\u0000file'),
          throwsArgumentError,
        );
      });

      test('rejects a current file containing a NUL byte', () {
        final instance = open();

        expect(
          () => instance.searchMixed(
            'target',
            options: const SearchOptions(currentFile: 'bad\u0000path'),
          ),
          throwsArgumentError,
        );
      });

      test('rejects an offset outside the C integer range', () {
        final instance = open();

        expect(
          () => instance.searchMixed(
            'target',
            options: const SearchOptions(offset: 0x100000000),
          ),
          throwsRangeError,
        );
      });

      test('rejects use after disposal', () {
        final instance = open()..dispose();

        expect(() => instance.searchMixed('target'), throwsStateError);
      });
    });
  });
}
