part of 'api.dart';

final Map<WatchId, _WatchStream> _watchStreams = {};

void _disposeWatchStreams(int handle) {
  final routes = _watchStreams.keys
      .where((route) => route.handle == handle)
      .toList();
  for (final route in routes) {
    final stream = _watchStreams.remove(route);
    if (stream == null) continue;
    stream._activeWatch = null;
    stream._close();
  }
}

void _routeEvents(int handle, int watchId, List<WatchEvent> events) {
  _watchStreams[(handle: handle, watchId: watchId)]?._deliver(events);
}

typedef WatchId = ({int handle, int watchId});

final class _WatchStream(
  final FileFinder _owner,
  final String? _pattern,
  final List<String> _ignore,
) {
  WatchId? _activeWatch;
  late final _controller = StreamController<List<WatchEvent>>.broadcast(
    onListen: _start,
    onCancel: _stop,
  );

  Stream<List<WatchEvent>> get stream => _controller.stream;

  void _close() {
    if (_controller.isClosed) return;
    unawaited(_controller.close());
  }

  void _deliver(List<WatchEvent> events) {
    if (!_controller.isClosed) _controller.add(events);
  }

  void _start() {
    if (_controller.isClosed) return;
    if (_owner._handle == 0) {
      _close();
      return;
    }
    final handle = _owner._handle;
    try {
      watch_bindings.setWatchCallback(
        handle,
        callback: (watchId, events) => _routeEvents(handle, watchId, events),
      );
      final watchId = watch_bindings.watchArgs(handle, _pattern, _ignore);
      final route = (handle: handle, watchId: watchId);
      if (_watchStreams.containsKey(route)) {
        watch_bindings.unwatch(handle, watchId);
        throw StateError('FFF returned an active watch identifier: $watchId');
      }
      _activeWatch = route;
      _watchStreams[route] = this;
    } on Object catch (error, stackTrace) {
      scheduleMicrotask(() {
        if (_controller.isClosed) return;
        _controller.addError(error, stackTrace);
        _close();
      });
    }
  }

  void _stop() {
    final activeWatch = _activeWatch;
    if (activeWatch == null) return;
    _activeWatch = null;
    _watchStreams.remove(activeWatch);
    if (_owner._handle != 0) {
      watch_bindings.unwatch(activeWatch.handle, activeWatch.watchId);
    }
  }
}
