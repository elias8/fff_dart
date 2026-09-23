import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:crypto/crypto.dart';
import 'package:hooks/hooks.dart';

import 'asset_hashes.dart';
import 'fff_source.dart';

/// Release asset name for an FFF C library target.
String releaseAssetName(
  OS os,
  Architecture architecture, {
  String libc = 'gnu',
}) {
  final arch = switch (architecture) {
    Architecture.x64 => 'x86_64',
    Architecture.arm64 => 'aarch64',
    final other => throw UnsupportedError('No FFF release for $other'),
  };
  final suffix = switch (os) {
    OS.macOS => 'apple-darwin.dylib',
    OS.windows => 'pc-windows-msvc.dll',
    OS.android when arch == 'aarch64' => 'linux-android.so',
    OS.linux when libc == 'gnu' || libc == 'musl' => 'unknown-linux-$libc.so',
    OS.linux => throw ArgumentError.value(libc, 'libc', 'Expected gnu or musl'),
    _ => throw UnsupportedError('No FFF release for $os/$arch'),
  };
  return 'fff-$arch-$suffix';
}

String _linuxLibc(BuildInput input) {
  final value = input.userDefines['libc'];
  if (value == null || value == 'gnu') return 'gnu';
  if (value == 'musl') return 'musl';
  throw ArgumentError.value(value, 'libc', 'Expected gnu or musl');
}

Future<String> _sha256(File file) async {
  return sha256.convert(await file.readAsBytes()).toString();
}

enum LibrarySource(final String configValue) {
  compile('compile'),
  prebuilt('prebuilt');

  static LibrarySource fromConfig(Object? value) {
    if (value == null) return assetHashes.isEmpty ? compile : prebuilt;
    for (final source in values) {
      if (source.configValue == value) return source;
    }
    throw ArgumentError.value(value, 'source', 'Expected compile or prebuilt');
  }
}

/// Selects and provides the native FFF C library for one hook target.
sealed class LibraryProvider(
  final BuildInput input,
  final BuildOutputBuilder output,
) {
  Future<void> provide(File target);

  static LibraryProvider resolve(BuildInput input, BuildOutputBuilder output) =>
      switch (LibrarySource.fromConfig(input.userDefines['source'])) {
        LibrarySource.compile => SourceLibraryProvider(input, output),
        LibrarySource.prebuilt => PrebuiltLibraryProvider(input, output),
      };
}

/// Downloads a release binary and checks it against the published SHA-256.
final class PrebuiltLibraryProvider(super.input, super.output)
    extends LibraryProvider {
  @override
  Future<void> provide(File target) async {
    const version = releaseTag;
    if (version == null) {
      throw StateError('No fff_dart release tag in the asset hash manifest');
    }
    final assetName = releaseAssetName(
      input.config.code.targetOS,
      input.config.code.targetArchitecture,
      libc: _linuxLibc(input),
    );
    final expected = assetHashes[assetName];
    if (expected == null) {
      throw UnsupportedError(
        'No verified FFF $version release asset for $assetName',
      );
    }
    final cached = File.fromUri(
      input.outputDirectoryShared.resolve('fff-$version/$assetName'),
    );
    cached.parent.createSync(recursive: true);
    if (cached.existsSync() && await _sha256(cached) != expected) {
      await cached.delete();
    }
    if (!cached.existsSync()) {
      await _download(assetName, expected, version, cached);
    }
    await cached.copy(target.path);
  }

  Future<void> _download(
    String assetName,
    String expected,
    String version,
    File cached,
  ) async {
    final url = Uri.parse(
      'https://github.com/elias8/fff_dart/releases/download/'
      '$version/$assetName',
    );
    final client = HttpClient();
    final temporary = File('${cached.path}.tmp');
    try {
      final response = await (await client.getUrl(url)).close();
      if (response.statusCode != HttpStatus.ok) {
        throw StateError(
          'FFF release download failed: HTTP ${response.statusCode} ($url)',
        );
      }
      await response.pipe(temporary.openWrite());
      if (await _sha256(temporary) != expected) {
        throw StateError('FFF release SHA-256 mismatch for $assetName');
      }
      await temporary.rename(cached.path);
    } finally {
      client.close();
      if (temporary.existsSync()) await temporary.delete();
    }
  }
}

/// Builds the pinned source with the same backend as the release binaries.
final class SourceLibraryProvider(super.input, super.output)
    extends LibraryProvider {
  @override
  Future<void> provide(File target) async {
    final os = input.config.code.targetOS;
    if (os != OS.current ||
        input.config.code.targetArchitecture != Architecture.current ||
        (os != OS.macOS && os != OS.linux && os != OS.windows)) {
      throw UnsupportedError('FFF compile supports host desktop builds only');
    }
    final local = input.userDefines.path('source_dir');
    if (local != null) output.dependencies.add(local);
    final source = await resolveFffSource(
      packageRoot: input.packageRoot,
      cacheRoot: input.outputDirectoryShared,
      localSource: local,
    );
    final result = await Process.run('cargo', [
      'build',
      '--release',
      '--locked',
      '-p',
      'fff-c',
      '--no-default-features',
      '--features',
      'zlob',
    ], workingDirectory: source.path);
    if (result.exitCode != 0) {
      throw StateError(
        'FFF cargo build failed (${result.exitCode}):\n'
        '${result.stdout}\n${result.stderr}',
      );
    }
    final built = File.fromUri(
      source.uri.resolve('target/release/${os.dylibFileName('fff_c')}'),
    );
    if (!built.existsSync()) {
      throw StateError('Cargo succeeded but ${built.path} is missing');
    }
    await built.copy(target.path);
  }
}
