import 'package:code_assets/code_assets.dart';
import 'package:fff_dart/src/hook/library_provider.dart';
import 'package:test/test.dart';

void main() {
  test('releaseAssetName maps supported FFF targets', () {
    final cases = <({OS os, Architecture arch, String libc, String name})>[
      (
        os: .macOS,
        arch: .x64,
        libc: 'gnu',
        name: 'fff-x86_64-apple-darwin.dylib',
      ),
      (
        os: .macOS,
        arch: .arm64,
        libc: 'gnu',
        name: 'fff-aarch64-apple-darwin.dylib',
      ),
      (
        os: .windows,
        arch: .x64,
        libc: 'gnu',
        name: 'fff-x86_64-pc-windows-msvc.dll',
      ),
      (
        os: .windows,
        arch: .arm64,
        libc: 'gnu',
        name: 'fff-aarch64-pc-windows-msvc.dll',
      ),
      (
        os: .linux,
        arch: .x64,
        libc: 'gnu',
        name: 'fff-x86_64-unknown-linux-gnu.so',
      ),
      (
        os: .linux,
        arch: .arm64,
        libc: 'gnu',
        name: 'fff-aarch64-unknown-linux-gnu.so',
      ),
      (
        os: .linux,
        arch: .x64,
        libc: 'musl',
        name: 'fff-x86_64-unknown-linux-musl.so',
      ),
      (
        os: .linux,
        arch: .arm64,
        libc: 'musl',
        name: 'fff-aarch64-unknown-linux-musl.so',
      ),
      (
        os: .android,
        arch: .arm64,
        libc: 'gnu',
        name: 'fff-aarch64-linux-android.so',
      ),
    ];

    for (final entry in cases) {
      expect(
        releaseAssetName(entry.os, entry.arch, libc: entry.libc),
        entry.name,
      );
    }
  });

  test('releaseAssetName rejects unavailable targets', () {
    expect(() => releaseAssetName(.iOS, .arm64), throwsUnsupportedError);
  });
}
