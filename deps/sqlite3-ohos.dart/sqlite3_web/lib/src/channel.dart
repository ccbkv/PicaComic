import 'dart:async';
import 'dart:js_interop';
import 'dart:math';

import 'package:stream_channel/stream_channel.dart';
import 'package:web/web.dart' hide Request, Response, Notification;

import 'locks.dart';
import 'protocol.dart';

const _disconnectMessage = '_disconnect';
final Random _random = Random();

@JS()
@anonymous
extension type WebEndpoint._(JSObject _) implements JSObject {
  external MessagePort get port;
  external String? get lockName;

  external factory WebEndpoint({
    required MessagePort port,
    required String? lockName,
  });

  StreamChannel<Message> connect() {
    return _channel(port, lockName, null);
  }
}

Future<(WebEndpoint, StreamChannel<Message>)> createChannel() async {
  final webChannel = MessageChannel();
  final locks = WebLocks.instance;

  // For servers, it's useful to know when a connection is closed, so that it
  // can release locks or otherwise clean up resources occupied by the
  // connection. This is kind of tricky for message ports, because they have
  // no "closed" event.
  // As a workaround, we're making one side take a unique lock and tell the
  // other endpoint about it. When that side closes for any reason, even just
  // because the tab is improperly closed, the other end will be able to take
  // the lock and thus know that the connection has been closed.
  HeldLock? lock;
  String? lockName;
  if (locks != null) {
    lockName = _randomLockName();
    lock = await locks.request(lockName);
  }

  final channel = _channel(webChannel.port2, lockName, lock);
  return (WebEndpoint(port: webChannel.port1, lockName: lockName), channel);
}

String _randomLockName() {
  final buffer = StringBuffer('channel-close-');
  for (var i = 0; i < 16; i++) {
    const charCodeSmallA = 97;
    buffer.writeCharCode(charCodeSmallA + _random.nextInt(26));
  }

  return buffer.toString();
}

StreamChannel<Message> _channel(
    MessagePort port, String? lockName, HeldLock? lock) {
  final controller = StreamChannelController<Message>();
  port.start();
  EventStreamProviders.messageEvent.forTarget(port).listen((event) {
    final message = event.data;

    if (message == _disconnectMessage.toJS) {
      // Other end has closed the connection
      controller.local.sink.close();
    } else {
      controller.local.sink.add(Message.deserialize(message as JSObject));
    }
  });

  controller.local.stream.listen((msg) {
    msg.sendToPort(port);
  }, onDone: () {
    // Closed locally, inform the other end.
    port
      ..postMessage(_disconnectMessage.toJS)
      ..close();
    lock?.release();
  });

  if (lock == null && lockName != null) {
    // Once this side is able to acquire the lock, the connection is closed.
    WebLocks.instance!.request(lockName).then((lock) {
      controller.local.sink.close();
      lock.release();
    });
  }

  return controller.foreign;
}

abstract class ProtocolChannel {
  final StreamChannel<Message> _channel;

  var _nextRequestId = 0;
  final Map<int, Completer<Response>> _responses = {};

  ProtocolChannel(this._channel) {
    _channel.stream.listen(_handleIncoming);
  }

  Future<void> get closed => _channel.sink.done;

  /// Handle an incoming message from the client.
  void _handleIncoming(Message message) async {
    switch (message) {
      case Response(:final requestId):
        _responses.remove(requestId)?.complete(message);
        break;
      case Request():
        Response response;

        try {
          response = await handleRequest(message);
        } catch (e, s) {
          console.error('Error in worker: ${e.toString()}'.toJS);
          console.error('Original trace: $s'.toJS);

          response = ErrorResponse(
              message: e.toString(), requestId: message.requestId);
        }

        _channel.sink.add(response);
      case Notification():
        handleNotification(message);
      case StartFileSystemServer():
        throw StateError('Should only be a top-level message');
    }
  }

  /// Sends a request to the other end and expects a response of the
  /// [expectedType].
  ///
  /// The returned future completes with an error if the type doesn't match
  /// what's expected (for instance because an [ErrorResponse]) is sent instead.
  /// It also completes with an error if the channel gets closed in the
  /// meantime.
  Future<Res> sendRequest<Res extends Response>(
      Request request, MessageType<Res> expectedType) async {
    final id = _nextRequestId++;
    final completer = _responses[id] = Completer.sync();

    _channel.sink.add(request..requestId = id);

    final response = await completer.future;
    if (response.type == expectedType) {
      return response as Res;
    } else {
      throw response.interpretAsError();
    }
  }

  Future<Response> handleRequest(Request request);

  void sendNotification(Notification notification) {
    _channel.sink.add(notification);
  }

  void handleNotification(Notification notification);

  Future<void> close() async {
    await _channel.sink.close();
  }
}

extension InjectErrors<T> on StreamChannel<T> {
  /// Returns a stream channel reporting error events from [target] through its
  /// [StreamChannel.stream].
  StreamChannel<T> injectErrorsFrom(EventTarget target) {
    return changeStream((original) {
      return Stream.multi((listener) {
        // Listen to the original stream...
        final upstreamSubscription = original.listen(
          listener.addSync,
          onDone: listener.closeSync,
          onError: listener.addErrorSync,
          cancelOnError: false,
        );

        // And also to errors which are forwarded to the listener
        final errorSubscription = EventStreamProviders.errorEvent
            .forTarget(target)
            .listen(listener.addErrorSync);

        // Don't pause the error subscription, but propagate pauses upstream.
        listener
          ..onPause = upstreamSubscription.pause
          ..onResume = upstreamSubscription.resume
          ..onCancel = () async {
            await upstreamSubscription.cancel();
            await errorSubscription.cancel();
          };
      });
    });
  }
}
