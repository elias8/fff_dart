import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:fff_dart/src/hook/library_provider.dart';
import 'package:hooks/hooks.dart';

Future<void> main(List<String> args) => build(args, _build);

Future<void> _build(BuildInput input, BuildOutputBuilder output) async {
  if (!input.config.buildCodeAssets) return;
  output.dependencies.add(input.packageRoot.resolve('fff.version'));

  final os = input.config.code.targetOS;
  final library = File.fromUri(
    input.outputDirectory.resolve(os.dylibFileName('fff')),
  );
  library.parent.createSync(recursive: true);
  await LibraryProvider.resolve(input, output).provide(library);
  if (!library.existsSync()) {
    throw StateError('FFF native library was not produced: ${library.path}');
  }

  output.assets.code.add(
    CodeAsset(
      name: 'fff_dart.dart',
      package: input.packageName,
      linkMode: DynamicLoadingBundled(),
      file: library.uri,
    ),
  );
}
