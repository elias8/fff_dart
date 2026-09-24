import 'package:fff_dart/fff_dart.dart';

import 'support.dart';

BenchmarkResult runMultiGrepBenchmark(int iterations) {
  final root = createBenchmarkRoot('multi-grep');
  try {
    for (var index = 0; index < 1000; index++) {
      writeBenchmarkFile(
        root,
        'module-$index/entry.dart',
        'class Entry$index { final needle = true; final marker = false; }\n',
      );
      writeBenchmarkFile(
        root,
        'module-$index/README.md',
        'module $index has no matching token\n',
      );
    }

    final finder = openScannedFinder(root);
    try {
      const options = MultiGrepOptions(pageLimit: 100);
      const patterns = ['needle', 'marker'];
      return measureBenchmark(
        name: 'multi-grep',
        workload: '2,000 files; 2 literals; page limit: 100',
        iterations: iterations,
        operation: () => finder.multiGrep(patterns, options: options),
        hasExpectedResults: (result) => result.matches.isNotEmpty,
      );
    } finally {
      finder.dispose();
    }
  } finally {
    root.deleteSync(recursive: true);
  }
}
