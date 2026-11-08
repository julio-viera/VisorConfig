import 'dart:async';
import 'dart:isolate';

/// A bounded background job whose isolate is stopped on cancellation or timeout.
class IsolateJob<T> {
  IsolateJob(Function worker, Object? input, Duration timeout) {
    _port.listen((message) {
      if (message is List && message.first == true) {
        _finish(message[1] as T);
      } else {
        _fail(StateError(message.toString()));
      }
    });
    _timer = Timer(
      timeout,
      () => _fail(TimeoutException('Processing timed out')),
    );
    Isolate.spawn(
      _runJob,
      [_port.sendPort, worker, input],
      onError: _port.sendPort,
      onExit: _port.sendPort,
    ).then((isolate) {
      if (_done.isCompleted) {
        isolate.kill(priority: Isolate.immediate);
      } else {
        _isolate = isolate;
      }
    }, onError: (Object error, StackTrace stack) => _fail(error));
  }
  final _port = ReceivePort();
  final _done = Completer<T>();
  Isolate? _isolate;
  Timer? _timer;
  Future<T> get result => _done.future;

  void cancel() => _fail(StateError('Processing cancelled'));
  void _finish(T result) {
    if (_done.isCompleted) return;
    _done.complete(result);
    _dispose();
  }

  void _fail(Object error) {
    if (_done.isCompleted) return;
    _done.completeError(error);
    _dispose();
  }

  void _dispose() {
    _timer?.cancel();
    _port.close();
    _isolate?.kill(priority: Isolate.immediate);
  }
}

void _runJob(List<Object?> message) {
  final port = message[0] as SendPort;
  try {
    Isolate.exit(port, [
      true,
      Function.apply(message[1] as Function, [message[2]]),
    ]);
  } catch (error) {
    port.send([false, error.toString()]);
  }
}
