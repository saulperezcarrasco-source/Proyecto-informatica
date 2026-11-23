import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/services.dart';

import '../../core/models/models.dart';
import '../../core/travel_mode.dart';
import 'island_graph.dart';

/// Keeps the graph off the UI isolate, including decoding and spatial indexing.
class IslandRoutingService {
  IslandRoutingService({this.mode = TravelMode.walking});
  final TravelMode mode;
  Isolate? _worker;
  ReceivePort? _responses;
  Future<SendPort>? _opening;
  Completer<SendPort>? _ready;
  final _pending = <int, Completer<RouteResult>>{};
  var _next = 0;
  bool _disposed = false;
  String? diagnostic;

  Future<SendPort> _open() async {
    final asset = await rootBundle.load(
      'assets/routing/dominican-${mode.assetName}.rdi',
    );
    if (_disposed) throw RouteFailure.invalidData;
    final ready = _ready = Completer<SendPort>();
    final responses = _responses = ReceivePort();
    responses.listen((dynamic message) {
      if (message is SendPort) {
        if (!ready.isCompleted) ready.complete(message);
      } else if (message is List && message[0] == 'load-error') {
        diagnostic = message[1] as String;
        if (!ready.isCompleted) ready.completeError(RouteFailure.invalidData);
      } else if (message is RouteFailure) {
        if (!ready.isCompleted) ready.completeError(message);
      } else if (message is List) {
        final request = _pending.remove(message[0]);
        if (message[1] is RouteResult) {
          request?.complete(message[1] as RouteResult);
        } else {
          request?.completeError(message[1] as RouteFailure);
        }
      }
    });
    _worker = await Isolate.spawn(_run, [
      responses.sendPort,
      TransferableTypedData.fromList([
        asset.buffer.asUint8List(asset.offsetInBytes, asset.lengthInBytes),
      ]),
      mode,
    ]);
    if (_disposed) {
      _worker?.kill(priority: Isolate.immediate);
      responses.close();
      throw RouteFailure.invalidData;
    }
    return ready.future.timeout(const Duration(seconds: 45));
  }

  Future<RouteResult> calculate(Coordinate start, Coordinate end) async {
    final SendPort port;
    try {
      port = await (_opening ??= _open());
    } catch (error, stack) {
      diagnostic ??= '$error\n$stack';
      _worker?.kill(priority: Isolate.immediate);
      _responses?.close();
      _opening = null;
      throw RouteFailure.invalidData;
    }
    if (_disposed) throw RouteFailure.invalidData;
    final id = ++_next;
    final result = Completer<RouteResult>();
    _pending[id] = result;
    port.send([id, start, end]);
    try {
      return await result.future.timeout(const Duration(seconds: 45));
    } on TimeoutException {
      throw RouteFailure.invalidData;
    } finally {
      _pending.remove(id);
    }
  }

  void dispose() {
    _disposed = true;
    if (_ready != null && !_ready!.isCompleted && _responses != null) {
      // Release an opening request immediately; calculate checks disposed
      // before sending anything to this now-closed response port.
      _ready!.complete(_responses!.sendPort);
    }
    _worker?.kill(priority: Isolate.immediate);
    _responses?.close();
    for (final request in _pending.values) {
      request.completeError(RouteFailure.invalidData);
    }
    _pending.clear();
  }
}

void _run(List<dynamic> arguments) {
  final replies = arguments[0] as SendPort;
  try {
    final compressed = (arguments[1] as TransferableTypedData)
        .materialize()
        .asUint8List();
    final decoded = gzip.decode(compressed);
    final graph = IslandGraph(
      decoded is Uint8List ? decoded : Uint8List.fromList(decoded),
    );
    final requests = ReceivePort();
    replies.send(requests.sendPort);
    requests.listen((dynamic message) {
      try {
        replies.send([
          message[0],
          graph.calculate(
            message[1] as Coordinate,
            message[2] as Coordinate,
            mode: arguments[2] as TravelMode,
          ),
        ]);
      } on RouteFailure catch (failure) {
        replies.send([message[0], failure]);
      } catch (_) {
        replies.send([message[0], RouteFailure.invalidData]);
      }
    });
  } catch (error, stack) {
    replies.send(['load-error', '$error\n$stack']);
  }
}
