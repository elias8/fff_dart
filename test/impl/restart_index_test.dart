import 'dart:io';

import 'package:fff_dart/fff_dart.dart';
import 'package:test/test.dart';

void main() {
  group('FileFinder.restartIndex', () {
    late Directory firstRoot;
    late Directory secondRoot;
    FileFinder? finder;

    setUp(() {
      firstRoot = Directory.systemTemp.createTempSync('fff-restart-first-');
      secondRoot = Directory.systemTemp.createTempSync('fff-restart-second-');
    });

    tearDown(() {
      finder?.dispose();
      firstRoot.deleteSync(recursive: true);
      secondRoot.deleteSync(recursive: true);
    });

    FileFinder open() {
      final instance = FileFinder.open(
        firstRoot.path,
        options: const FffOptions(watch: false),
      );
      finder = instance;
      instance.waitForScan(const Duration(seconds: 30));
      return instance;
    }

    test('switches the base path and indexed results', () {
      File('${firstRoot.path}/first.dart').writeAsStringSync('first');
      File('${secondRoot.path}/second.dart').writeAsStringSync('second');
      final instance = open();

      instance.restartIndex(secondRoot.path);
      expect(instance.waitForScan(const Duration(seconds: 30)), isTrue);

      expect(
        instance.basePath,
        Directory(secondRoot.path).resolveSymbolicLinksSync(),
      );
      expect(instance.glob('*.dart').items.map((item) => item.relativePath), [
        'second.dart',
      ]);
    });

    test('preserves the old index when the new path does not exist', () {
      File('${firstRoot.path}/first.dart').writeAsStringSync('first');
      final instance = open();

      void restart() => instance.restartIndex('${secondRoot.path}/missing');

      expect(restart, throwsA(isA<FffException>()));
      expect(
        FileSystemEntity.identicalSync(instance.basePath, firstRoot.path),
        isTrue,
      );
      expect(instance.glob('*.dart').items.single.relativePath, 'first.dart');
    });

    test('rejects empty, NUL-containing, and existing file paths', () {
      final instance = open();
      final filePath = '${secondRoot.path}/not-a-directory';
      File(filePath).writeAsStringSync('file');

      void emptyPath() => instance.restartIndex('');
      void nulPath() => instance.restartIndex('bad\u0000path');
      void filePathAsRoot() => instance.restartIndex(filePath);

      expect(emptyPath, throwsArgumentError);
      expect(nulPath, throwsArgumentError);
      expect(filePathAsRoot, throwsArgumentError);
      expect(
        FileSystemEntity.identicalSync(instance.basePath, firstRoot.path),
        isTrue,
      );
    });

    test('rejects use after disposal', () {
      final instance = open()..dispose();

      void restart() => instance.restartIndex(secondRoot.path);
      void restartWithEmptyPath() => instance.restartIndex('');

      expect(restart, throwsStateError);
      expect(restartWithEmptyPath, throwsStateError);
    });
  });
}
