# fff_dart

A single pure Dart package for the [FFF](https://github.com/dmtrKovalenko/fff) C ABI. The API covers index lifecycle and scan state, fuzzy file, directory, and mixed search, glob filtering, and content grep.

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

      final results = index.searchFile(
        'main.dart',
        options: const SearchOptions(pageSize: 10),
      );
      for (final item in results.items) {
        print(item.relativePath);
      }

      final directories = index.searchDirectories('lib');
      for (final directory in directories.items) {
        print(directory.relativePath);
      }

      final dartFiles = index.glob('**/*.dart');
      for (final item in dartFiles.items) {
        print(item.relativePath);
      }
      final refreshedGitEntries = index.refreshGitStatus();
      print('Git status entry count: $refreshedGitEntries');
      final health = index.healthCheck();
      print('FFF version: ${health.version}');

      final matches = index.grep(
        'FileFinder',
        options: const GrepOptions(mode: .regex, beforeContext: 1),
      );
      for (final match in matches.matches) {
        print('${match.relativePath}:${match.lineNumber}: ${match.lineContent}');
      }

      final anyMatches = index.multiGrep(['FileFinder', 'GrepResult']);
      for (final match in anyMatches.matches) {
        print('${match.relativePath}:${match.lineNumber}: ${match.lineContent}');
      }

      final mixed = index.searchMixed('components');
      for (final item in mixed.items) {
        switch (item) {
          case FileItem(:final relativePath):
            print('File: $relativePath');
          case DirectoryItem(:final relativePath):
            print('Directory: $relativePath');
        }
      }
    }
    index.rescan();
  } finally {
    index.dispose();
  }
}
```

`FileFinder.open` starts native background work. Calls are synchronous and waits or disposal may block the calling isolate. Dispose the index when finished; later operations throw `StateError`. Native failures throw `FffException`.

Content grep supports literal, regex, and fuzzy modes. `multiGrep` searches for any of several literal patterns and reuses the same detached result types. Its pagination cursor advances through candidate files and should be reused with the same query and options. Regex errors fall back to literal matching and are returned in `GrepResult.regexFallbackError`. Match columns and highlight ranges use UTF-8 byte offsets. See the API docs for limits, context, and time-budget behavior.

## Watch filesystem changes

Wait until filesystem monitoring is ready before subscribing. Each stream emits
immutable event lists with absolute paths; rename events include both the old
and new paths.

```dart
final finder = FileFinder.open('/path/to/project');
try {
  if (finder.waitForWatcher(const Duration(seconds: 30))) {
    final changes = finder.watch(ignore: ['.git']);
    final listener = changes.listen((events) {
      for (final event in events) {
        print('${event.kind}: ${event.path}');
      }
    });

    // Cancelling the final listener pauses monitoring; listening again resumes
    // it.
    await listener.cancel();
  }
} finally {
  finder.dispose();
}
```
