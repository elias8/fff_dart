import 'dart:async';
import 'dart:ffi';
import 'dart:isolate';

import 'package:ffi/ffi.dart';

import '../ffi/fff.g.dart';
import 'types/result.dart';
import 'types/string.dart';
import 'types/watch.dart';

(RawReceivePort, NativeCallable<FffWatchCallbackFunction>)?
_watchCallbackRuntime;
final Map<int, _WatchCallbackState> _watchCallbacks = {};
final Set<int> _registeredCallbackHandles = {};

void setWatchCallback(int handle, {required WatchCallback callback}) {
  final state = _watchCallbacks[handle];
  if (state != null) {
    state.onEvents = callback;
    return;
  }

  _ensureNativeCallback();
  decodeFffResult<void>(
    () => fff_set_watch_callback(
      Pointer<Void>.fromAddress(handle),
      _watchCallbackRuntime!.$2.nativeFunction,
      Pointer<Void>.fromAddress(handle),
    ),
    operationName: 'FileFinder.watch',
    decodeSuccess: ignoreResult,
  );
  _watchCallbacks[handle] = _WatchCallbackState(callback);
  _registeredCallbackHandles.add(handle);
}

void disposeWatchHandle(int handle) {
  _watchCallbacks.remove(handle);
  _registeredCallbackHandles.remove(handle);
  if (_registeredCallbackHandles.isNotEmpty) return;

  final runtime = _watchCallbackRuntime;
  if (runtime == null) return;
  _watchCallbackRuntime = null;
  runtime.$2.close();
  runtime.$1.close();
}

bool unwatch(int handle, int watchId) {
  final existed = decodeFffResult(
    () => fff_unwatch(Pointer<Void>.fromAddress(handle), watchId),
    operationName: 'FileFinder.watch',
    decodeSuccess: (envelope) => switch (envelope.int_value) {
      0 => false,
      1 => true,
      final value => throw StateError(
        'FFF returned an invalid watch removal value: $value',
      ),
    },
  );

  final state = _watchCallbacks[handle];
  state?.watchIds.remove(watchId);
  if (state?.watchIds.isEmpty ?? false) _watchCallbacks.remove(handle);
  return existed;
}

int watchArgs(int handle, String? pattern, List<String> ignore) {
  final state = _watchCallbacks[handle];
  if (state == null) {
    throw StateError('Register the watch callback before watching');
  }
  if (ignore.length > 0xffffffff) {
    throw RangeError.range(ignore.length, 0, 0xffffffff, 'ignore.length');
  }

  try {
    final watchId = using((arena) {
      final patternPointer = pattern.toNativeChar(arena, 'pattern');
      final ignorePointers = ignore.isEmpty
          ? nullptr.cast<Pointer<Char>>()
          : arena<Pointer<Char>>(ignore.length);
      for (var index = 0; index < ignore.length; index++) {
        ignorePointers[index] = ignore[index].toNativeChar(
          arena,
          'ignore[$index]',
        );
      }

      return decodeFffResult(
        () => fff_watch_args(
          Pointer<Void>.fromAddress(handle),
          patternPointer,
          ignorePointers,
          ignore.length,
        ),
        operationName: 'FileFinder.watch',
        decodeSuccess: (envelope) => envelope.int_value,
      );
    });

    if (!state.watchIds.add(watchId)) {
      unwatch(handle, watchId);
      throw StateError('FFF returned an active watch identifier: $watchId');
    }
    return watchId;
  } on Object {
    if (state.watchIds.isEmpty) _watchCallbacks.remove(handle);
    rethrow;
  }
}

void _copyWatchBatch(
  SendPort sendPort,
  int handle,
  int watchId,
  Pointer<FffWatchEventBatch> batch,
) {
  Object message;
  try {
    if (batch == nullptr) throw StateError('FFF returned a null watch batch');
    final batchData = batch.ref;
    if (batchData.count > 0 && batchData.events == nullptr) {
      throw StateError('FFF returned a watch batch without event data');
    }

    final events = <WatchEvent>[];
    for (var index = 0; index < batchData.count; index++) {
      final event = batchData.events[index];
      final path = event.path.toDartStringOrNull();
      if (path == null) {
        throw StateError('FFF returned a watch event without a path');
      }

      final fromPath = switch (event.kind) {
        4 =>
          batchData.rename_sources == nullptr
              ? throw StateError('FFF returned a rename without source paths')
              : batchData.rename_sources[index].toDartStringOrNull(),
        _ => null,
      };

      if (event.kind == 4 && fromPath == null) {
        throw StateError('FFF returned a rename without a source path');
      }

      events.add(
        WatchEvent(
          path: path,
          fromPath: fromPath,
          kind: switch (event.kind) {
            0 => .created,
            1 => .modified,
            2 => .removed,
            3 => .rescan,
            4 => .renamed,
            final kind => throw StateError(
              'FFF returned an unknown watch event kind: $kind',
            ),
          },
        ),
      );
    }

    message = [handle, watchId, List<WatchEvent>.unmodifiable(events)];
  } on Object catch (error) {
    message = ['error', handle, watchId, error.toString()];
  } finally {
    fff_free_watch_events(batch);
  }

  try {
    sendPort.send(message);
  } on Object {
    // The isolate may be shutting down after FFF has stopped its watchers.
  }
}

void _ensureNativeCallback() {
  if (_watchCallbackRuntime != null) return;

  final receivePort = RawReceivePort(_receiveWatchMessage)
    ..keepIsolateAlive = false;
  final sendPort = receivePort.sendPort;
  final nativeCallback =
      NativeCallable<FffWatchCallbackFunction>.isolateGroupBound((
        int watchId,
        Pointer<FffWatchEventBatch> batch,
        Pointer<Void> userData,
      ) {
        _copyWatchBatch(sendPort, userData.address, watchId, batch);
      });
  _watchCallbackRuntime = (receivePort, nativeCallback);
}

void _receiveWatchMessage(Object? message) {
  switch (message) {
    case [final int handle, final int watchId, final List<WatchEvent> events]:
      final state = _watchCallbacks[handle];
      if (state == null || !state.watchIds.contains(watchId)) return;
      state.onEvents(watchId, events);
    case ['error', final int handle, final int watchId, final String message]:
      final state = _watchCallbacks[handle];
      if (state == null || !state.watchIds.contains(watchId)) return;
      Zone.current.handleUncaughtError(StateError(message), StackTrace.current);
    default:
      return;
  }
}

typedef WatchCallback = void Function(int watchId, List<WatchEvent> events);

final class _WatchCallbackState(var WatchCallback onEvents) {
  final Set<int> watchIds = {};
}
