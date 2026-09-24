import 'dart:convert';
import 'dart:io';

import 'directory_search.dart';
import 'file_search.dart';
import 'glob.dart';
import 'grep.dart';
import 'index_lifecycle.dart';
import 'mixed_search.dart';
import 'multi_grep.dart';
import 'support.dart';

const _benchmarkNames = [
  'index',
  'file-search',
  'directory-search',
  'mixed-search',
  'glob',
  'grep',
  'multi-grep',
];
const _resultMarker = 'FFF_BENCHMARK_RESULT:';

Future<void> main(List<String> args) async {
  final options = _parseArguments(args);
  if (options.help) {
    stdout.writeln(_usage);
    return;
  }

  if (options.worker case final worker?) {
    final result = _runBenchmark(worker, options.iterations);
    stdout.writeln('$_resultMarker${jsonEncode(result.toJson())}');
    return;
  }

  final results = <BenchmarkResult>[];
  for (final name in options.selected) {
    final process = await Process.run(Platform.resolvedExecutable, [
      'run',
      Platform.script.toFilePath(),
      '--worker=$name',
      '--iterations=${options.iterations}',
    ]);
    if (process.exitCode != 0) {
      stderr
        ..writeln('Benchmark "$name" failed.')
        ..write(process.stderr)
        ..write(process.stdout);
      exitCode = process.exitCode;
      return;
    }

    final output = process.stdout as String;
    final markerIndex = output.lastIndexOf(_resultMarker);
    if (markerIndex < 0) {
      throw FormatException('Benchmark "$name" returned no JSON result');
    }
    final resultLine = output
        .substring(markerIndex + _resultMarker.length)
        .trim()
        .split('\n')
        .first;
    results.add(
      BenchmarkResult.fromJson(jsonDecode(resultLine) as Map<String, Object?>),
    );
  }

  _writeReport(results);
}

BenchmarkResult _runBenchmark(String name, int iterations) => switch (name) {
  'index' => runIndexLifecycleBenchmark(iterations),
  'file-search' => runFileSearchBenchmark(iterations),
  'directory-search' => runDirectorySearchBenchmark(iterations),
  'mixed-search' => runMixedSearchBenchmark(iterations),
  'glob' => runGlobBenchmark(iterations),
  'grep' => runGrepBenchmark(iterations),
  'multi-grep' => runMultiGrepBenchmark(iterations),
  _ => throw ArgumentError.value(name, 'benchmark', 'Unknown benchmark'),
};

({int iterations, List<String> selected, String? worker, bool help})
_parseArguments(List<String> args) {
  var iterations = 100;
  String? only;
  String? worker;
  var help = false;

  for (var index = 0; index < args.length; index++) {
    final argument = args[index];
    if (argument == '--help' || argument == '-h') {
      help = true;
    } else if (argument.startsWith('--iterations=')) {
      iterations = int.parse(argument.substring('--iterations='.length));
    } else if (argument == '--iterations') {
      iterations = int.parse(args[++index]);
    } else if (argument.startsWith('--only=')) {
      only = argument.substring('--only='.length);
    } else if (argument == '--only') {
      only = args[++index];
    } else if (argument.startsWith('--worker=')) {
      worker = argument.substring('--worker='.length);
    } else {
      throw FormatException('Unknown argument: $argument\n\n$_usage');
    }
  }

  if (iterations < 1) {
    throw RangeError.value(iterations, 'iterations', 'Must be positive');
  }
  if (worker case final workerName?
      when !_benchmarkNames.contains(workerName)) {
    throw ArgumentError.value(workerName, 'worker', 'Unknown benchmark');
  }

  final selected = only == null || only == 'all'
      ? _benchmarkNames
      : only.split(',').map((name) => name.trim()).toList();
  for (final name in selected) {
    if (!_benchmarkNames.contains(name)) {
      throw ArgumentError.value(name, 'only', 'Unknown benchmark');
    }
  }

  return (
    iterations: iterations,
    selected: selected,
    worker: worker,
    help: help,
  );
}

void _writeReport(List<BenchmarkResult> results) {
  final first = results.first;
  stdout.writeln(
    'FFF benchmarks · ${first.operatingSystem} '
    '${first.operatingSystemVersion} · Dart ${first.dartVersion}',
  );
  stdout.writeln(
    'Each workload runs in its own process; 3 warmups precede timed calls.',
  );
  stdout.writeln(
    '${'Benchmark'.padRight(19)} '
    '${'Workload'.padRight(51)} '
    '${'Runs'.padLeft(6)} '
    '${'Median'.padLeft(12)} '
    '${'P95'.padLeft(12)} '
    '${'RSS Δ'.padLeft(12)}',
  );

  for (final result in results) {
    stdout.writeln(
      '${_truncate(result.name, 18).padRight(19)} '
      '${_truncate(result.workload, 50).padRight(51)} '
      '${result.iterations.toString().padLeft(6)} '
      '${'${result.medianMicroseconds.toStringAsFixed(1)} µs'.padLeft(12)} '
      '${'${result.p95Microseconds} µs'.padLeft(12)} '
      '${_formatBytes(result.rssDeltaBytes).padLeft(12)}',
    );
  }
}

String _truncate(String value, int maximumLength) =>
    value.length <= maximumLength
    ? value
    : '${value.substring(0, maximumLength - 1)}…';

String _formatBytes(int value) {
  final sign = value < 0 ? '−' : '+';
  final magnitude = value.abs();
  if (magnitude >= 1024 * 1024) {
    return '$sign${(magnitude / (1024 * 1024)).toStringAsFixed(2)} MiB';
  }
  if (magnitude >= 1024) {
    return '$sign${(magnitude / 1024).toStringAsFixed(1)} KiB';
  }
  return '$sign$magnitude B';
}

final _usage =
    '''
Usage: dart run benchmark/benchmark.dart [options]

Options:
  --iterations N       Number of measured calls per workload (default: 100)
  --only NAME[,NAME]   Run selected workloads, or "all" (default: all)
  -h, --help           Show this help

Workloads: ${_benchmarkNames.join(', ')}
Example: dart run benchmark/benchmark.dart --only file-search,grep --iterations 500
''';
