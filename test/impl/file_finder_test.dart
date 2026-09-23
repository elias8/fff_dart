import 'dart:io';

import 'package:fff_dart/fff_dart.dart';
import 'package:test/test.dart';

void main() {
  group('FffOptions', () {
    test('uses expected defaults', () {
      const options = FffOptions();

      expect(options.enableMmapCache, isTrue);
      expect(options.enableContentIndexing, isTrue);
      expect(options.watch, isTrue);
      expect(options.followSymlinks, isFalse);
    });
  });

  group('FileFinder', () {
    late Directory root;
    FileFinder? subject;

    setUp(() {
      root = Directory.systemTemp.createTempSync('fff-index-test-');
      subject = null;
    });

    tearDown(() {
      subject?.dispose();
      root.deleteSync(recursive: true);
    });

    FileFinder open({FffOptions options = const FffOptions(watch: false)}) {
      final index = FileFinder.open(root.path, options: options);
      subject = index;
      return index;
    }

    group('open', () {
      test('opens an existing directory', () {
        final index = open();

        final path = index.basePath;

        expect(FileSystemEntity.identicalSync(path, root.path), isTrue);
      });

      test('reports a missing directory as a native error', () {
        final missing = '${root.path}/missing';

        FileFinder operation() => FileFinder.open(missing);

        expect(operation, throwsA(isA<FffException>()));
      });

      test('rejects an empty base path', () {
        const path = '';

        FileFinder operation() => FileFinder.open(path);

        expect(operation, throwsArgumentError);
      });

      test('rejects a file as the base path', () {
        final file = File('${root.path}/file.txt')
          ..writeAsStringSync('content');

        FileFinder operation() {
          final index = FileFinder.open(file.path);
          subject = index;
          return index;
        }

        expect(operation, throwsArgumentError);
      });

      test('rejects a NUL byte in the base path', () {
        const path = 'bad\u0000path';

        FileFinder operation() => FileFinder.open(path);

        expect(operation, throwsArgumentError);
      });

      test('rejects a negative cache limit', () {
        const options = FffOptions(cacheBudgetMaxFiles: -1);

        FileFinder operation() => FileFinder.open(root.path, options: options);

        expect(operation, throwsRangeError);
      });

      test('rejects a NUL byte in an optional path', () {
        const options = FffOptions(historyDbPath: 'bad\u0000path');

        FileFinder operation() => FileFinder.open(root.path, options: options);

        expect(operation, throwsArgumentError);
      });

      test('round trips a UTF-8 base path', () {
        final directory = Directory('${root.path}/caf\u00e9')..createSync();
        final index = FileFinder.open(
          directory.path,
          options: const FffOptions(watch: false),
        );
        subject = index;

        final path = index.basePath;

        expect(FileSystemEntity.identicalSync(path, directory.path), isTrue);
      });
    });

    group('scanProgress', () {
      test('reports the number of scanned files', () {
        File('${root.path}/alpha.txt').writeAsStringSync('alpha');
        final index = open();
        index.waitForScan(const Duration(seconds: 30));

        final progress = index.scanProgress;

        expect(progress.scannedFilesCount, greaterThanOrEqualTo(1));
      });

      test('reports warmup complete when content indexing is disabled', () {
        final index = open(
          options: const FffOptions(watch: false, enableContentIndexing: false),
        );
        index.waitForScan(const Duration(seconds: 30));

        final progress = index.scanProgress;

        expect(progress.isWarmupComplete, isTrue);
      });
    });

    group('waitForScan', () {
      test('reports completion after the initial scan', () {
        final index = open();

        final completed = index.waitForScan(const Duration(seconds: 30));

        expect(completed, isTrue);
      });

      test('rejects a negative timeout', () {
        final index = open();

        bool operation() => index.waitForScan(const Duration(milliseconds: -1));

        expect(operation, throwsRangeError);
      });
    });

    group('waitForWatcher', () {
      test('reports no watcher when watching is disabled', () {
        final index = open();

        final ready = index.waitForWatcher(Duration.zero);

        expect(ready, isFalse);
      });
    });

    group('rescan', () {
      test('accepts a rescan request', () {
        final index = open();

        void operation() => index.rescan();

        expect(operation, returnsNormally);
      });
    });

    group('dispose', () {
      test('allows repeated disposal', () {
        final index = open();
        index.dispose();

        void operation() => index.dispose();

        expect(operation, returnsNormally);
      });

      test('rejects reading the base path afterward', () {
        final index = open();
        index.dispose();

        String operation() => index.basePath;

        expect(operation, throwsStateError);
      });

      test('rejects reading scan progress afterward', () {
        final index = open();
        index.dispose();

        FffScanProgress operation() => index.scanProgress;

        expect(operation, throwsStateError);
      });

      test('rejects reading scan state afterward', () {
        final index = open();
        index.dispose();

        bool operation() => index.isScanning;

        expect(operation, throwsStateError);
      });

      test('rejects a rescan afterward', () {
        final index = open();
        index.dispose();

        void operation() => index.rescan();

        expect(operation, throwsStateError);
      });

      test('rejects waiting for a scan afterward', () {
        final index = open();
        index.dispose();

        bool operation() => index.waitForScan(Duration.zero);

        expect(operation, throwsStateError);
      });

      test('rejects waiting for a watcher afterward', () {
        final index = open();
        index.dispose();

        bool operation() => index.waitForWatcher(Duration.zero);

        expect(operation, throwsStateError);
      });
    });
  });
}
