import 'dart:io';

import 'package:fff_dart/fff_dart.dart';

const benchmarkFffOptions = FffOptions(
  watch: false,
  enableMmapCache: false,
  enableContentIndexing: false,
);

Directory createBenchmarkRoot(String name) =>
    Directory.systemTemp.createTempSync('fff-$name-benchmark-');

BenchmarkResult measureBenchmark<T>({
  required String name,
  required String workload,
  required int iterations,
  required T Function() operation,
  required bool Function(T result) hasExpectedResults,
}) {
  const warmups = 3;
  for (var index = 0; index < warmups; index++) {
    _requireResult(name, operation(), hasExpectedResults);
  }

  final initialRss = ProcessInfo.currentRss;
  final samples = List<int>.filled(iterations, 0);
  for (var index = 0; index < iterations; index++) {
    final clock = Stopwatch()..start();
    final result = operation();
    clock.stop();
    _requireResult(name, result, hasExpectedResults);
    samples[index] = clock.elapsedMicroseconds;
  }
  final rssDeltaBytes = ProcessInfo.currentRss - initialRss;

  samples.sort();
  final middle = iterations ~/ 2;
  final medianMicroseconds = iterations.isOdd
      ? samples[middle].toDouble()
      : (samples[middle - 1] + samples[middle]) / 2;
  final p95Index = ((iterations * 95 + 99) ~/ 100) - 1;

  return BenchmarkResult(
    name: name,
    workload: workload,
    iterations: iterations,
    medianMicroseconds: medianMicroseconds,
    p95Microseconds: samples[p95Index],
    rssDeltaBytes: rssDeltaBytes,
    operatingSystem: Platform.operatingSystem,
    operatingSystemVersion: Platform.operatingSystemVersion,
    dartVersion: Platform.version.split(' ').first,
  );
}

FileFinder openScannedFinder(Directory root) {
  final finder = FileFinder.open(root.path, options: benchmarkFffOptions);
  if (!finder.waitForScan(const Duration(seconds: 60))) {
    finder.dispose();
    throw StateError('FFF scan did not finish');
  }
  return finder;
}

void writeBenchmarkFile(Directory root, String relativePath, String content) {
  final file = File('${root.path}/$relativePath');
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(content);
}

void _requireResult<T>(
  String name,
  T result,
  bool Function(T result) hasExpectedResults,
) {
  if (!hasExpectedResults(result)) {
    throw StateError('FFF returned no expected results for $name');
  }
}

final class BenchmarkResult {
  final String name;
  final String workload;
  final int iterations;
  final double medianMicroseconds;
  final int p95Microseconds;
  final int rssDeltaBytes;
  final String operatingSystem;
  final String operatingSystemVersion;
  final String dartVersion;
  const new({
    required this.name,
    required this.workload,
    required this.iterations,
    required this.medianMicroseconds,
    required this.p95Microseconds,
    required this.rssDeltaBytes,
    required this.operatingSystem,
    required this.operatingSystemVersion,
    required this.dartVersion,
  });

  factory fromJson(Map<String, Object?> json) => .new(
    name: json['name']! as String,
    workload: json['workload']! as String,
    iterations: json['iterations']! as int,
    medianMicroseconds: (json['medianMicroseconds']! as num).toDouble(),
    p95Microseconds: json['p95Microseconds']! as int,
    rssDeltaBytes: json['rssDeltaBytes']! as int,
    operatingSystem: json['operatingSystem']! as String,
    operatingSystemVersion: json['operatingSystemVersion']! as String,
    dartVersion: json['dartVersion']! as String,
  );

  Map<String, Object> toJson() => {
    'name': name,
    'workload': workload,
    'iterations': iterations,
    'medianMicroseconds': medianMicroseconds,
    'p95Microseconds': p95Microseconds,
    'rssDeltaBytes': rssDeltaBytes,
    'operatingSystem': operatingSystem,
    'operatingSystemVersion': operatingSystemVersion,
    'dartVersion': dartVersion,
  };
}
