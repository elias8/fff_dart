import 'dart:io';

const fffRepository = 'https://github.com/dmtrKovalenko/fff.git';

String fffVersion(Uri packageRoot) {
  final file = File.fromUri(packageRoot.resolve('fff.version'));
  final version = file.readAsStringSync().trim();
  if (!RegExp(r'^v\d+\.\d+\.\d+$').hasMatch(version)) {
    throw FormatException('Invalid FFF tag in ${file.path}: $version');
  }
  return version;
}

Future<Directory> resolveFffSource({
  required Uri packageRoot,
  required Uri cacheRoot,
  Uri? localSource,
}) async {
  final version = fffVersion(packageRoot);
  final source = localSource == null
      ? Directory.fromUri(cacheRoot.resolve('fff-$version/'))
      : Directory.fromUri(localSource);
  final cachedGit = Directory.fromUri(source.uri.resolve('.git/'));
  if (localSource == null && !cachedGit.existsSync()) {
    if (source.existsSync()) await source.delete(recursive: true);
    final clone = await Process.run('git', [
      'clone',
      '--depth',
      '1',
      '--branch',
      version,
      fffRepository,
      source.path,
    ]);
    if (clone.exitCode != 0) {
      if (source.existsSync()) await source.delete(recursive: true);
      throw StateError('Cannot fetch FFF $version: ${clone.stderr}');
    }
  }
  await validateFffSource(source, packageRoot: packageRoot);
  return source;
}

Future<void> validateFffSource(
  Directory source, {
  required Uri packageRoot,
}) async {
  final version = fffVersion(packageRoot);
  final header = File.fromUri(source.uri.resolve('crates/fff-c/include/fff.h'));
  if (!header.existsSync()) {
    throw StateError('FFF C header not found in ${source.path}');
  }
  final tag = await Process.run('git', [
    'describe',
    '--tags',
    '--exact-match',
    'HEAD',
  ], workingDirectory: source.path);
  if (tag.exitCode != 0 || (tag.stdout as String).trim() != version) {
    throw StateError('FFF source must be checked out at tag $version');
  }
  final changes = await Process.run('git', [
    'status',
    '--porcelain',
    '--untracked-files=no',
  ], workingDirectory: source.path);
  if (changes.exitCode != 0 || (changes.stdout as String).trim().isNotEmpty) {
    throw StateError('FFF source has tracked changes: ${source.path}');
  }
}
