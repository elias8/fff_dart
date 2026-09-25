<p align="center">
  <img src="assets/fff-dart.png" alt="fff-dart logo" width="360">
</p>

<p align="center">
  <a href="https://pub.dev/packages/fff_dart"><img src="https://img.shields.io/pub/v/fff_dart?label=fff_dart" alt="pub package version"></a>&nbsp;
  <a href="https://github.com/elias8/fff_dart/actions/workflows/ci.yml"><img src="https://github.com/elias8/fff_dart/actions/workflows/ci.yml/badge.svg" alt="GitHub Actions build status"></a>&nbsp;
  <a href="https://github.com/sponsors/elias8"><img src="https://img.shields.io/github/sponsors/elias8?logo=githubsponsors&label=sponsor" alt="Sponsor elias8"></a>&nbsp;
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue" alt="MIT license"></a>
</p>

<p align="center">
  <i>A file search toolkit for humans and AI agents. Really fast.</i>
</p>

<p align="center">
  Dart FFI bindings for <a href="https://github.com/dmtrKovalenko/fff">FFF</a>.
</p>

`fff_dart` provides an idiomatic Dart API for indexing a directory, finding
files and folders, searching file contents, and watching filesystem changes.

> Typo-resistant path and content search, frequency-ranked file access, a
> background watcher, and a lightweight in-memory content index. Way faster
> than CLIs like `ripgrep` and `fzf` in any long-running process that searches
> more than once.

| Linux | macOS | Windows |
|:-----:|:-----:|:-------:|
|  ✓   |  ✓   |   ✓    |

## Features

- Fuzzy file, directory, and mixed file/directory search
- Root-relative glob filtering
- Literal, regular-expression, and fuzzy content search
- Multi-pattern literal content search
- Filesystem change streams
- Scan progress, rescanning, and index restart
- Git status refresh, query history, and typed health diagnostics

## Getting started

Add the package to your application:

```yaml
dependencies:
  fff_dart: ^0.1.0
```

## Quick start

Open the project directory you want to index, wait for its initial scan, search
for a file, and dispose the finder when finished:

```dart
import 'dart:io';

import 'package:fff_dart/fff_dart.dart';

void main() {
  final finder = FileFinder.open('/path/to/project');

  try {
    if (!finder.waitForScan(const Duration(seconds: 30))) {
      throw StateError('The initial file scan timed out');
    }

    final results = finder.searchFile('main.dart');
    for (final item in results.items) {
      stdout.writeln(item.relativePath);
    }
  } finally {
    finder.dispose();
  }
}
```

## Search and content APIs

All search methods are synchronous. Wait for the initial scan when results
must include the whole directory. Search results and score lists are detached
and immutable.

```dart
final files = finder.searchFile('src main');
final directories = finder.searchDirectories('components');
final mixed = finder.searchMixed('components');
final dartFiles = finder.glob('**/*.dart');

final matches = finder.grep(
  'TODO',
  options: const GrepOptions(pageLimit: 20),
);
final anyMatches = finder.multiGrep(['TODO', 'FIXME']);
```

`searchFile`, `searchDirectories`, and `searchMixed` use FFF's fuzzy query
parser and ranking. `glob` matches a root-relative pattern. `grep` supports
literal, regex, and fuzzy modes; invalid regex patterns fall back to literal
matching and are reported in `GrepResult.regexFallbackError`. `multiGrep`
matches any of its literal patterns.

`searchMixed` items can be handled exhaustively:

```dart
for (final item in mixed.items) {
  switch (item) {
    case FileItem(:final relativePath):
      stdout.writeln('File: $relativePath');
    case DirectoryItem(:final relativePath):
      stdout.writeln('Directory: $relativePath');
  }
}
```

## Watch filesystem changes

Watching is enabled by default. Wait until the watcher is ready before
subscribing, and cancel active subscriptions before disposing the finder:

```dart
// In an async function, after opening the finder with watching enabled:
if (finder.waitForWatcher(const Duration(seconds: 30))) {
  final subscription = finder.watch(ignore: ['.git']).listen((events) {
    for (final event in events) {
      stdout.writeln('${event.kind}: ${event.path}');
    }
  });

  // Keep the subscription while changes are needed, then cancel it before
  // disposing the finder.
  await subscription.cancel();
}
```

The stream is broadcast and emits immutable event lists. Rename events include
the destination in `path` and the old path in `fromPath`. Cancelling the last
listener stops monitoring; a later listener starts it again.

## Configuration and diagnostics

Pass `FffOptions` when opening an index to configure persistent frecency and
query-history databases, content indexing, watching, cache limits, tracing, and
symlink handling. For example:

```dart
final finder = FileFinder.open(
  projectPath,
  options: FffOptions(
    frecencyDbPath: '/path/to/frecency.db',
    historyDbPath: '/path/to/history.db',
    watch: false,
  ),
);
```

`refreshGitStatus()` returns the number of Git status entries reported by FFF.
Configure `historyDbPath` to persist selections recorded with `trackQuery()`;
`getHistoricalQuery()` reads them back. `healthCheck()` and
`FileFinder.healthCheckStatic()` return typed diagnostics.

## Lifecycle and errors

`FileFinder.open` starts background indexing and returns before the scan
finishes. API calls are synchronous and can block the calling isolate;
`waitForScan`, `waitForWatcher`, and `dispose` can also wait for native work.
Move calls to an isolate when blocking a UI or latency-sensitive event loop is
not acceptable.

Always dispose a finder when finished. Cancel active watch subscriptions first.
Native failures throw `FffException`; invalid arguments throw standard Dart
argument or range errors, and use after disposal throws `StateError`.

## License

MIT. See [LICENSE](LICENSE).
