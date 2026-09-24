import 'dart:io';

import 'package:fff_dart/fff_dart.dart';
import 'package:test/test.dart';

void main() {
  group('MultiGrepOptions', () {
    test('preserves native default sentinels', () {
      const options = MultiGrepOptions();

      expect(options.constraints, isNull);
      expect(options.maxFileSizeBytes, 0);
      expect(options.maxMatchesPerFile, 0);
      expect(options.smartCase, isTrue);
      expect(options.fileOffset, 0);
      expect(options.pageLimit, 0);
      expect(options.timeBudgetMs, 0);
      expect(options.enforceTimeBudget, isFalse);
      expect(options.beforeContext, 0);
      expect(options.afterContext, 0);
      expect(options.classifyDefinitions, isFalse);
    });
  });

  group('FileFinder.multiGrep', () {
    late Directory root;
    FileFinder? finder;

    setUp(() {
      root = Directory.systemTemp.createTempSync('fff-multi-grep-test-');
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

    test('matches any literal pattern and copies all line ranges', () {
      File('${root.path}/src/main.dart')
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('before\nalpha and beta\nafter\n');
      final instance = open();

      final result = instance.multiGrep([
        'alpha',
        'beta',
      ], options: const MultiGrepOptions(beforeContext: 1, afterContext: 1));
      instance.dispose();

      expect(result.matches, hasLength(1));
      expect(result.matches.single.relativePath, 'src/main.dart');
      expect(result.matches.single.lineContent, 'alpha and beta');
      expect(result.matches.single.matchRanges, hasLength(2));
      expect(result.matches.single.matchRanges[0].startByte, 0);
      expect(result.matches.single.matchRanges[0].endByte, 5);
      expect(result.matches.single.matchRanges[1].startByte, 10);
      expect(result.matches.single.matchRanges[1].endByte, 14);
      expect(result.matches.single.contextBefore, ['before']);
      expect(result.matches.single.contextAfter, ['after']);
      expect(result.matches.single.fuzzyScore, isNull);
      expect(result.regexFallbackError, isNull);
      expect(result.matches.clear, throwsUnsupportedError);
      expect(result.matches.single.matchRanges.clear, throwsUnsupportedError);
      expect(result.matches.single.contextBefore.clear, throwsUnsupportedError);
    });

    test(
      'uses case-insensitive matching only when every pattern allows it',
      () {
        File('${root.path}/lower.txt').writeAsStringSync('needle\n');
        File('${root.path}/upper.txt').writeAsStringSync('Needle\n');
        final instance = open();

        final insensitive = instance.multiGrep(['needle', 'other']);
        final sensitive = instance.multiGrep(['needle', 'Érror']);

        expect(insensitive.matches, hasLength(2));
        expect(sensitive.matches, hasLength(1));
        expect(sensitive.matches.single.lineContent, 'needle');
      },
    );

    test('applies separate path constraints without broadening on a miss', () {
      File('${root.path}/src/main.dart')
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('needle\n');
      File('${root.path}/README.txt').writeAsStringSync('needle\n');
      final instance = open();

      final constrained = instance.multiGrep([
        'needle',
      ], options: const MultiGrepOptions(constraints: '*.dart'));
      final missing = instance.multiGrep([
        'needle',
      ], options: const MultiGrepOptions(constraints: '*.rs'));

      expect(constrained.matches, hasLength(1));
      expect(constrained.matches.single.relativePath, 'src/main.dart');
      expect(missing.matches, isEmpty);
    });

    test('continues with the next candidate file offset', () {
      File('${root.path}/one.txt').writeAsStringSync('alpha\n');
      File('${root.path}/two.txt').writeAsStringSync('beta\n');
      File('${root.path}/three.txt').writeAsStringSync('alpha beta\n');
      final instance = open();

      final first = instance.multiGrep([
        'alpha',
        'beta',
      ], options: const MultiGrepOptions(pageLimit: 1));
      final second = instance.multiGrep(
        ['alpha', 'beta'],
        options: MultiGrepOptions(
          fileOffset: first.nextFileOffset,
          pageLimit: 1,
        ),
      );

      expect(first.matches, hasLength(1));
      expect(second.matches, hasLength(1));
      expect(first.nextFileOffset, greaterThan(0));
      expect(
        second.matches.single.relativePath,
        isNot(first.matches.single.relativePath),
      );
    });

    test('rejects invalid patterns and a NUL-containing constraint', () {
      final instance = open();

      GrepResult noPatterns() => instance.multiGrep([]);
      GrepResult emptyPattern() => instance.multiGrep(['']);
      GrepResult newlinePattern() => instance.multiGrep(['alpha\nbeta']);
      GrepResult nulPattern() => instance.multiGrep(['alpha\u0000beta']);
      GrepResult nulConstraint() => instance.multiGrep([
        'alpha',
      ], options: const MultiGrepOptions(constraints: 'src/\u0000other'));

      expect(noPatterns, throwsArgumentError);
      expect(emptyPattern, throwsArgumentError);
      expect(newlinePattern, throwsArgumentError);
      expect(nulPattern, throwsArgumentError);
      expect(nulConstraint, throwsArgumentError);
    });

    test('rejects values outside native integer ranges', () {
      final instance = open();

      GrepResult maxSize() => instance.multiGrep([
        'alpha',
      ], options: const MultiGrepOptions(maxFileSizeBytes: -1));
      GrepResult pageLimit() => instance.multiGrep([
        'alpha',
      ], options: const MultiGrepOptions(pageLimit: 0x100000000));

      expect(maxSize, throwsRangeError);
      expect(pageLimit, throwsRangeError);
    });

    test('rejects use after disposal', () {
      final instance = open()..dispose();

      GrepResult operation() => instance.multiGrep(['alpha']);

      expect(operation, throwsStateError);
    });
  });
}
