import 'dart:io';

import 'package:fff_dart/fff_dart.dart';
import 'package:test/test.dart';

void main() {
  group('FileFinder query history', () {
    late Directory root;
    Directory? historyRoot;
    FileFinder? finder;

    setUp(() {
      root = Directory.systemTemp.createTempSync('fff-query-history-test-');
      historyRoot = null;
    });

    tearDown(() {
      finder?.dispose();
      root.deleteSync(recursive: true);
      historyRoot?.deleteSync(recursive: true);
    });

    FileFinder open({String? historyDbPath}) {
      final instance = FileFinder.open(
        root.path,
        options: FffOptions(watch: false, historyDbPath: historyDbPath),
      );
      finder = instance;
      instance.waitForScan(const Duration(seconds: 30));
      return instance;
    }

    test(
      'returns the native tracking value and null without history storage',
      () {
        final instance = open();

        expect(instance.trackQuery('main', root.path), isTrue);
        expect(instance.getHistoricalQuery(0), isNull);
      },
    );

    test('tracks completed queries and retrieves most recent first', () {
      final mainFile = File('${root.path}/main.dart')
        ..writeAsStringSync('main');
      final readme = File('${root.path}/README.md')
        ..writeAsStringSync('readme');
      historyRoot = Directory.systemTemp.createTempSync(
        'fff-query-history-db-',
      );
      final instance = open(historyDbPath: '${historyRoot!.path}/queries');

      expect(instance.trackQuery('main', mainFile.path), isTrue);
      expect(instance.trackQuery('readme', readme.path), isTrue);
      expect(instance.getHistoricalQuery(0), 'readme');
      expect(instance.getHistoricalQuery(1), 'main');
      expect(instance.getHistoricalQuery(2), isNull);
    });

    test('rejects NUL strings and offsets outside the native range', () {
      final instance = open();

      bool nulQuery() => instance.trackQuery('main\u0000file', root.path);
      bool nulPath() => instance.trackQuery('main', 'main\u0000.dart');
      String? negativeOffset() => instance.getHistoricalQuery(-1);
      String? oversizedOffset() =>
          instance.getHistoricalQuery(0x8000000000000000);

      expect(nulQuery, throwsArgumentError);
      expect(nulPath, throwsArgumentError);
      expect(negativeOffset, throwsRangeError);
      expect(oversizedOffset, throwsRangeError);
    });

    test('rejects use after disposal', () {
      final instance = open()..dispose();

      bool track() => instance.trackQuery('main', root.path);
      String? history() => instance.getHistoricalQuery(0);

      expect(track, throwsStateError);
      expect(history, throwsStateError);
    });
  });
}
