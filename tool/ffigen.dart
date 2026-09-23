/// Regenerates raw FFF C bindings from the source named by `fff.version`.
///
/// Set `FFF_SRC` to a local checkout at that tag to avoid fetching the header.
library;

import 'dart:io';

import 'package:fff_dart/src/hook/fff_source.dart';
import 'package:ffigen/ffigen.dart';

Future<void> main() async {
  final root = Platform.script.resolve('../');
  final local = Platform.environment['FFF_SRC'];
  final source = await resolveFffSource(
    packageRoot: root,
    cacheRoot: root.resolve('.dart_tool/ffigen/'),
    localSource: local == null ? null : Directory(local).uri,
  );
  final header = source.uri.resolve('crates/fff-c/include/fff.h');
  final output = root.resolve('lib/src/ffi/fff.g.dart');
  final generator = FfiGenerator(
    output: Output(
      dart: DartOutput(path: output),
      style: const NativeExternalBindings(
        assetId: 'package:fff_dart/fff_dart.dart',
      ),
    ),
    input: Input(entryPoints: [header], include: (uri) => uri == header),
    visitors: [
      Visitor(
        func: (node) => node.isIncluded = node.name.startsWith('fff_'),
        struct: (node) => node.isIncluded = node.name.startsWith('Fff'),
        union: (node) => node.isIncluded = node.name.startsWith('Fff'),
        enumClass: (node) => node.isIncluded = node.name.startsWith('Fff'),
        typealias: (node) =>
            node.isIncluded = node.name.startsWith('Fff') ? .ifUsed : .never,
        macroConstant: (node) => node.isIncluded = node.name.startsWith('FFF_'),
        global: (node) => node.isIncluded = node.name.startsWith('fff_'),
      ),
    ],
  );
  await generator.generate();
}
