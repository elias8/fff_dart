# fff_dart

A single pure Dart package for the [FFF](https://github.com/dmtrKovalenko/fff) C ABI. The first API slice covers index creation, scan state, rescanning, waits, and disposal. Search APIs are still in development.

## Open an index

```dart
import 'package:fff_dart/fff_dart.dart';

void main() {
  final index = FileFinder.open(
    '/path/to/project',
    options: const FffOptions(watch: false),
  );
  try {
    if (index.waitForScan(const Duration(seconds: 30))) {
      final progress = index.scanProgress;
      print('Scanned ${progress.scannedFilesCount} files');
    }
    index.rescan();
  } finally {
    index.dispose();
  }
}
```

`FileFinder.open` starts native background work. Calls are synchronous and waits or disposal may block the calling isolate. Dispose the index when finished; later operations throw `StateError`. Native failures throw `FffException`.

## Native build

The build hook compiles the pinned FFF `v0.11.0` C library for Linux, macOS, and Windows host targets. Building requires Dart, Git, Rust/Cargo, a working native C toolchain, and network access to fetch the FFF source and Cargo dependencies. The hook bundles the resulting library with the consuming app. The desktop CI matrix checks each host and a consuming Dart app. Android support awaits verified prebuilt artifacts.
