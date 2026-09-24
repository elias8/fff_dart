import 'package:fff_dart/fff_dart.dart';

import 'support.dart';

BenchmarkResult runGrepBenchmark(int iterations) {
  final root = createBenchmarkRoot('grep');
  try {
    for (var index = 0; index < 1000; index++) {
      writeBenchmarkFile(
        root,
        'module-$index/entry.dart',
        'class Entry$index { final needle = true; }\n',
      );
      writeBenchmarkFile(
        root,
        'module-$index/README.md',
        'module $index has no matching token\n',
      );
    }

    final finder = openScannedFinder(root);
    try {
      const options = GrepOptions(pageLimit: 100);
      return measureBenchmark(
        name: 'grep',
        workload: '2,000 files; literal: needle; page limit: 100',
        iterations: iterations,
        operation: () => finder.grep('needle', options: options),
        hasExpectedResults: (result) => result.matches.isNotEmpty,
      );
    } finally {
      finder.dispose();
    }
  } finally {
    root.deleteSync(recursive: true);
  }
}
