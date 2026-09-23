import 'dart:io';

import 'package:fff_dart/fff_dart.dart';
import 'package:test/test.dart';

void main() {
  group('FileFinder', () {
    group('searchDirectories', () {
      late Directory root;
      FileFinder? finder;

      setUp(() {
        root = Directory.systemTemp.createTempSync('fff-directory-search-');
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

      void createDirectory(String name) {
        File('${root.path}/$name/marker.txt')
          ..parent.createSync(recursive: true)
          ..writeAsStringSync('marker');
      }

      test('returns detached directory and score values', () {
        createDirectory('target_directory');
        final instance = open();

        final result = instance.searchDirectories('target_directory');
        instance.dispose();

        final item = result.items.single;
        expect(item.relativePath, 'target_directory/');
        expect(item.dirName, 'target_directory/');
        expect(item.maxAccessFrecencyScore, isA<int>());
        final score = result.scores.single;
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
        expect(result.totalMatched, 1);
        expect(result.totalDirectories, 1);
      });

      test('returns immutable item lists', () {
        createDirectory('target_directory');
        final result = open().searchDirectories('target_directory');

        expect(result.items.clear, throwsUnsupportedError);
      });

      test('returns immutable score lists', () {
        createDirectory('target_directory');
        final result = open().searchDirectories('target_directory');

        expect(result.scores.clear, throwsUnsupportedError);
      });

      test('uses frecency scores for an empty query', () {
        createDirectory('target_directory');
        final instance = open();

        final result = instance.searchDirectories('');

        expect(result.items, hasLength(1));
        expect(result.scores.single.matchType, 'frecency');
        expect(result.totalMatched, 1);
        expect(result.totalDirectories, 1);
      });

      test('returns directory counts when there are no matches', () {
        createDirectory('target_directory');
        final result = open().searchDirectories('missing_directory');

        expect(result.items, isEmpty);
        expect(result.scores, isEmpty);
        expect(result.totalMatched, 0);
        expect(result.totalDirectories, 1);
      });

      test('uses offset as the number of results to skip', () {
        createDirectory('target_directory_alpha');
        createDirectory('target_directory_beta');
        final instance = open();

        final first = instance.searchDirectories(
          'target_directory',
          options: const DirectorySearchOptions(pageSize: 1),
        );
        final second = instance.searchDirectories(
          'target_directory',
          options: const DirectorySearchOptions(offset: 1, pageSize: 1),
        );

        expect(first.items, hasLength(1));
        expect(second.items, hasLength(1));
        expect(
          first.items.single.relativePath,
          isNot(second.items.single.relativePath),
        );
        expect(first.totalMatched, 2);
      });

      test('ignores a parsed location suffix when matching directories', () {
        createDirectory('target_directory');
        final instance = open();

        final plain = instance.searchDirectories('target_directory');
        final withLocation = instance.searchDirectories('target_directory:12');

        expect(
          withLocation.items.single.relativePath,
          plain.items.single.relativePath,
        );
        expect(withLocation.totalMatched, plain.totalMatched);
      });

      test('rejects a query containing a NUL byte', () {
        final instance = open();

        expect(
          () => instance.searchDirectories('target\u0000directory'),
          throwsArgumentError,
        );
      });

      test('rejects a current directory containing a NUL byte', () {
        final instance = open();

        expect(
          () => instance.searchDirectories(
            'target',
            options: const DirectorySearchOptions(currentFile: 'bad\u0000path'),
          ),
          throwsArgumentError,
        );
      });

      test('rejects use after disposal', () {
        final instance = open()..dispose();

        expect(() => instance.searchDirectories('target'), throwsStateError);
      });

      test('rejects a negative offset', () {
        final instance = open();

        expect(
          () => instance.searchDirectories(
            'target',
            options: const DirectorySearchOptions(offset: -1),
          ),
          throwsRangeError,
        );
      });

      test('rejects an offset above the native integer range', () {
        final instance = open();

        expect(
          () => instance.searchDirectories(
            'target',
            options: const DirectorySearchOptions(offset: 0x100000000),
          ),
          throwsRangeError,
        );
      });

      test('rejects a thread count above the native integer range', () {
        final instance = open();

        expect(
          () => instance.searchDirectories(
            'target',
            options: const DirectorySearchOptions(maxThreads: 0x100000000),
          ),
          throwsRangeError,
        );
      });

      test('rejects a page size above the native integer range', () {
        final instance = open();

        expect(
          () => instance.searchDirectories(
            'target',
            options: const DirectorySearchOptions(pageSize: 0x100000000),
          ),
          throwsRangeError,
        );
      });
    });

    group('DirectorySearchOptions', () {
      test('preserves native defaults', () {
        const options = DirectorySearchOptions();

        expect(options.maxThreads, 0);
        expect(options.currentFile, isNull);
        expect(options.offset, 0);
        expect(options.pageSize, 0);
      });
    });
  });
}
