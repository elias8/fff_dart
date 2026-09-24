import 'dart:io';

import 'package:fff_dart/fff_dart.dart';
import 'package:test/test.dart';

void main() {
  group('FileFinder.healthCheck', () {
    late Directory root;
    Directory? databaseRoot;
    FileFinder? finder;

    setUp(() {
      root = Directory.systemTemp.createTempSync('fff-health-check-test-');
      databaseRoot = null;
    });

    tearDown(() {
      finder?.dispose();
      root.deleteSync(recursive: true);
      databaseRoot?.deleteSync(recursive: true);
    });

    FileFinder open({String? frecencyDbPath, String? historyDbPath}) {
      File('${root.path}/main.dart').writeAsStringSync('main');
      final instance = FileFinder.open(
        root.path,
        options: FffOptions(
          watch: false,
          frecencyDbPath: frecencyDbPath,
          historyDbPath: historyDbPath,
        ),
      );
      finder = instance;
      instance.waitForScan(const Duration(seconds: 30));
      return instance;
    }

    test('returns typed status for a live index', () {
      final instance = open();

      final health = instance.healthCheck(testPath: root.path);

      expect(health.version, '0.11.0');
      expect(health.git.available, isTrue);
      expect(health.git.repositoryFound, isFalse);
      expect(health.git.libgit2Version, isNotEmpty);
      expect(health.filePicker.initialized, isTrue);
      expect(
        FileSystemEntity.identicalSync(health.filePicker.basePath!, root.path),
        isTrue,
      );
      expect(health.filePicker.isScanning, isFalse);
      expect(health.filePicker.indexedFiles, greaterThanOrEqualTo(1));
      expect(health.frecency.initialized, isFalse);
      expect(health.queryTracker.initialized, isFalse);
    });

    test('static health check marks instance services uninitialized', () {
      final health = FileFinder.healthCheckStatic(testPath: root.path);

      expect(health.version, '0.11.0');
      expect(health.git.repositoryFound, isFalse);
      expect(health.filePicker.initialized, isFalse);
      expect(health.frecency.initialized, isFalse);
      expect(health.queryTracker.initialized, isFalse);
    });

    test('uses the current directory for an empty test path', () {
      final omitted = FileFinder.healthCheckStatic();
      final empty = FileFinder.healthCheckStatic(testPath: '');

      expect(empty.git.repositoryFound, omitted.git.repositoryFound);
      expect(empty.git.workdir, omitted.git.workdir);
    });

    test(
      'returns optional database health details when databases are enabled',
      () {
        databaseRoot = Directory.systemTemp.createTempSync('fff-health-db-');
        final instance = open(
          frecencyDbPath: '${databaseRoot!.path}/frecency',
          historyDbPath: '${databaseRoot!.path}/history',
        );

        final health = instance.healthCheck(testPath: root.path);

        expect(health.frecency.initialized, isTrue);
        expect(health.frecency.details, isNotNull);
        expect(
          health.frecency.details!.path,
          Directory('${databaseRoot!.path}/frecency')
              .resolveSymbolicLinksSync(),
        );
        expect(health.queryTracker.initialized, isTrue);
        expect(health.queryTracker.details, isNotNull);
        expect(
          health.queryTracker.details!.path,
          Directory('${databaseRoot!.path}/history').resolveSymbolicLinksSync(),
        );
      },
    );

    test('rejects a NUL-containing test path', () {
      final instance = open();

      HealthCheck operation() =>
          instance.healthCheck(testPath: 'bad\u0000path');

      expect(operation, throwsArgumentError);
    });

    test('rejects instance health checks after disposal', () {
      final instance = open()..dispose();

      HealthCheck operation() => instance.healthCheck();

      expect(operation, throwsStateError);
    });
  });
}
