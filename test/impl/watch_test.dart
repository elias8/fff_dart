import 'dart:async';
import 'dart:io';

import 'package:fff_dart/fff_dart.dart';
import 'package:test/test.dart';

void main() {
  group('FileFinder.watch', () {
    late Directory root;
    FileFinder? finder;

    setUp(() {
      root = Directory.systemTemp.createTempSync('fff-watch-test-');
    });

    tearDown(() {
      finder?.dispose();
      root.deleteSync(recursive: true);
    });

    FileFinder open({bool watching = true}) {
      final instance = FileFinder.open(
        root.path,
        options: FffOptions(watch: watching),
      );
      finder = instance;
      instance.waitForScan(const Duration(seconds: 30));
      return instance;
    }

    test('emits copied filesystem change lists', () async {
      final instance = open();
      expect(instance.waitForWatcher(const Duration(seconds: 30)), isTrue);
      final stream = instance.watch();
      final event = expectLater(
        stream,
        emitsThrough(
          predicate<List<WatchEvent>>(
            (events) => events.any(
              (event) =>
                  event.path.endsWith('created.dart') && event.kind == .created,
            ),
          ),
        ),
      );

      File('${root.path}/created.dart').writeAsStringSync('content');
      await event;
    });

    test('emits the source and destination paths for a rename', () async {
      File('${root.path}/before.dart').writeAsStringSync('content');
      final instance = open();
      expect(instance.waitForWatcher(const Duration(seconds: 30)), isTrue);
      final stream = instance.watch();
      final event = expectLater(
        stream,
        emitsThrough(
          predicate<List<WatchEvent>>(
            (events) => events.any(
              (event) =>
                  event.kind == .renamed &&
                  event.path.endsWith('after.dart') &&
                  (event.fromPath?.endsWith('before.dart') ?? false),
            ),
          ),
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 100));
      File('${root.path}/before.dart').renameSync('${root.path}/after.dart');
      await event;
    });

    test('applies per-watch ignore prefixes', () async {
      Directory('${root.path}/ignored').createSync();
      final instance = open();
      expect(instance.waitForWatcher(const Duration(seconds: 30)), isTrue);
      final stream = instance.watch(ignore: ['ignored']);
      final event = expectLater(
        stream,
        emits(
          predicate<List<WatchEvent>>(
            (events) =>
                events.any((event) => event.path.endsWith('visible.dart')),
          ),
        ),
      );

      File('${root.path}/ignored/hidden.dart').writeAsStringSync('hidden');
      File('${root.path}/visible.dart').writeAsStringSync('visible');
      await event;
    });

    test('routes matching event lists to their streams', () async {
      final instance = open();
      expect(instance.waitForWatcher(const Duration(seconds: 30)), isTrue);
      final firstWatch = instance.watch(pattern: 'first.dart');
      final secondWatch = instance.watch(pattern: 'second.dart');
      final firstEvent = expectLater(
        firstWatch,
        emits(
          predicate<List<WatchEvent>>(
            (events) =>
                events.any((event) => event.path.endsWith('first.dart')),
          ),
        ),
      );
      final secondEvent = expectLater(
        secondWatch,
        emits(
          predicate<List<WatchEvent>>(
            (events) =>
                events.any((event) => event.path.endsWith('second.dart')),
          ),
        ),
      );

      File('${root.path}/first.dart').writeAsStringSync('first');
      File('${root.path}/second.dart').writeAsStringSync('second');
      await Future.wait([firstEvent, secondEvent]);
    });

    test(
      'restarts the native watch when a later stream listener attaches',
      () async {
        final instance = open();
        expect(instance.waitForWatcher(const Duration(seconds: 30)), isTrue);
        final stream = instance.watch();
        final firstListener = stream.listen((_) {});
        await firstListener.cancel();

        final event = expectLater(
          stream,
          emits(
            predicate<List<WatchEvent>>(
              (events) =>
                  events.any((event) => event.path.endsWith('resumed.dart')),
            ),
          ),
        );
        File('${root.path}/resumed.dart').writeAsStringSync('content');

        await event;
      },
    );

    test('broadcasts each event list to every active listener', () async {
      final instance = open();
      expect(instance.waitForWatcher(const Duration(seconds: 30)), isTrue);
      final stream = instance.watch();
      final firstEvent = expectLater(stream, emits(isA<List<WatchEvent>>()));
      final secondEvent = expectLater(stream, emits(isA<List<WatchEvent>>()));

      File('${root.path}/broadcast.dart').writeAsStringSync('content');

      await Future.wait([firstEvent, secondEvent]);
    });

    test(
      'routes callbacks independently for separate finder instances',
      () async {
        final firstFinder = open();
        final secondRoot = Directory.systemTemp.createTempSync(
          'fff-watch-second-test-',
        );
        addTearDown(() => secondRoot.deleteSync(recursive: true));
        final secondFinder = FileFinder.open(secondRoot.path);
        addTearDown(secondFinder.dispose);
        secondFinder.waitForScan(const Duration(seconds: 30));
        expect(firstFinder.waitForWatcher(const Duration(seconds: 30)), isTrue);
        expect(
          secondFinder.waitForWatcher(const Duration(seconds: 30)),
          isTrue,
        );

        final firstEvent = expectLater(
          firstFinder.watch(),
          emits(
            predicate<List<WatchEvent>>(
              (events) =>
                  events.any((event) => event.path.endsWith('first-root.dart')),
            ),
          ),
        );
        final secondEvent = expectLater(
          secondFinder.watch(),
          emits(
            predicate<List<WatchEvent>>(
              (events) => events.any(
                (event) => event.path.endsWith('second-root.dart'),
              ),
            ),
          ),
        );

        File('${root.path}/first-root.dart').writeAsStringSync('first');
        File('${secondRoot.path}/second-root.dart').writeAsStringSync('second');
        await Future.wait([firstEvent, secondEvent]);
      },
    );

    test('emits an error when filesystem watching is disabled', () async {
      final instance = open(watching: false);

      await expectLater(instance.watch(), emitsError(isA<FffException>()));
    });

    test('rejects watch operations after disposal', () {
      final instance = open()..dispose();

      Stream<List<WatchEvent>> subscribe() => instance.watch();

      expect(subscribe, throwsStateError);
    });

    test('disposes after a watch subscription is cancelled', () async {
      final instance = open();
      expect(instance.waitForWatcher(const Duration(seconds: 30)), isTrue);
      final subscription = instance.watch().listen((_) {});

      await subscription.cancel();

      expect(instance.dispose, returnsNormally);
    });

    test(
      'closes a previously returned stream listened to after disposal',
      () async {
        final instance = open();
        final stream = instance.watch();

        instance.dispose();

        await expectLater(stream, emitsDone);
      },
    );

    test('disposing one finder preserves another finder watch', () async {
      final firstFinder = open();
      final secondRoot = Directory.systemTemp.createTempSync(
        'fff-watch-second-test-',
      );
      addTearDown(() => secondRoot.deleteSync(recursive: true));
      final secondFinder = FileFinder.open(secondRoot.path);
      addTearDown(secondFinder.dispose);
      secondFinder.waitForScan(const Duration(seconds: 30));
      expect(firstFinder.waitForWatcher(const Duration(seconds: 30)), isTrue);
      expect(secondFinder.waitForWatcher(const Duration(seconds: 30)), isTrue);

      final firstStreamDone = expectLater(firstFinder.watch(), emitsDone);
      final secondEvent = expectLater(
        secondFinder.watch(),
        emits(
          predicate<List<WatchEvent>>(
            (events) =>
                events.any((event) => event.path.endsWith('surviving.dart')),
          ),
        ),
      );

      firstFinder.dispose();
      await firstStreamDone;
      File('${secondRoot.path}/surviving.dart').writeAsStringSync('content');
      await secondEvent;
    });
  });

  group('FileFinder.watch event lists', () {
    test('emits unmodifiable lists of detached events', () async {
      final root = Directory.systemTemp.createTempSync('fff-watch-list-');
      final finder = FileFinder.open(root.path);
      addTearDown(finder.dispose);
      addTearDown(() => root.deleteSync(recursive: true));
      finder.waitForScan(const Duration(seconds: 30));
      expect(finder.waitForWatcher(const Duration(seconds: 30)), isTrue);
      final stream = finder.watch();
      final received = Completer<List<WatchEvent>>();
      final listener = stream.listen((events) {
        if (events.any((event) => event.path.endsWith('list.dart'))) {
          received.complete(events);
        }
      });

      File('${root.path}/list.dart').writeAsStringSync('content');
      final events = await received.future;
      await listener.cancel();

      expect(
        () => events.add(const WatchEvent(path: '/other.dart', kind: .created)),
        throwsUnsupportedError,
      );
    });
  });
}
