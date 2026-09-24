import 'package:fff_dart/fff_dart.dart';

import 'support.dart';

BenchmarkResult runIndexLifecycleBenchmark(int iterations) {
  final root = createBenchmarkRoot('index-lifecycle');
  try {
    for (var index = 0; index < 100; index++) {
      writeBenchmarkFile(root, 'file-$index.txt', 'entry $index\n');
    }

    return measureBenchmark(
      name: 'index lifecycle',
      workload: '100 files; open, scan, read properties, dispose',
      iterations: iterations,
      operation: () {
        final finder = FileFinder.open(root.path, options: benchmarkFffOptions);
        try {
          if (!finder.waitForScan(const Duration(seconds: 30))) {
            throw StateError('FFF scan did not finish');
          }
          return (finder.scanProgress, finder.basePath);
        } finally {
          finder.dispose();
        }
      },
      hasExpectedResults: (result) => result.$2 == root.path,
    );
  } finally {
    root.deleteSync(recursive: true);
  }
}
