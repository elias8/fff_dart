import 'dart:io';

import 'package:fff_dart/fff_dart.dart';
import 'package:test/test.dart';

void main() {
  group('FileFinder.refreshGitStatus', () {
    late Directory root;
    FileFinder? finder;

    setUp(() {
      root = Directory.systemTemp.createTempSync('fff-git-status-test-');
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

    test(
      'returns the refreshed status count when no Git repository exists',
      () {
        File('${root.path}/main.dart').writeAsStringSync('main');
        final instance = open();

        expect(instance.refreshGitStatus(), 0);
      },
    );

    test(
      'returns a positive count for a repository with an untracked file',
      () {
        final gitInit = Process.runSync('git', ['init', '--quiet', root.path]);
        expect(gitInit.exitCode, 0, reason: gitInit.stderr.toString());
        File('${root.path}/main.dart').writeAsStringSync('main');
        final instance = open();

        expect(instance.refreshGitStatus(), greaterThan(0));
      },
    );

    test('rejects use after disposal', () {
      final instance = open()..dispose();

      int operation() => instance.refreshGitStatus();

      expect(operation, throwsStateError);
    });
  });
}
