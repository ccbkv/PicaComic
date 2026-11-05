import 'dart:async';
import 'dart:math';

/// Classification of an HTTP failure, deciding retry policy.
enum HttpErrorClass {
  /// 429 / 503 — back off and retry; do NOT count as a hard failure.
  rateLimited,

  /// Other 4xx — the request is wrong (bad model, auth); retrying won't help.
  clientError,

  /// Network error / timeout / 5xx — retry a bounded number of times.
  transient,

  /// Anything else unexpected.
  fatal,
}

HttpErrorClass classifyStatus(int statusCode) {
  if (statusCode == 429 || statusCode == 503) return HttpErrorClass.rateLimited;
  if (statusCode >= 400 && statusCode < 500) return HttpErrorClass.clientError;
  if (statusCode >= 500) return HttpErrorClass.transient;
  return HttpErrorClass.fatal;
}

/// Parses a `Retry-After` header. Only integer seconds are supported (clamped
/// to a sane ceiling); an HTTP-date value returns null so the caller falls
/// back to exponential backoff. Kept dart:io-free for web safety.
Duration? parseRetryAfter(String? header) {
  if (header == null) return null;
  var s = header.trim();
  if (s.isEmpty) return null;
  var secs = int.tryParse(s);
  if (secs == null) return null;
  return Duration(seconds: secs.clamp(0, 300));
}

const _baseBackoffMs = 500;
const _maxBackoff = Duration(seconds: 32);
final _defaultRng = Random().nextDouble;

/// Exponential backoff with full jitter: a random delay in [0, base * 2^attempt).
/// A provided [retryAfter] wins (capped). [rng] is injectable for tests.
Duration backoff(int attempt, {Duration? retryAfter, double Function()? rng}) {
  if (retryAfter != null) {
    return retryAfter > _maxBackoff ? _maxBackoff : retryAfter;
  }
  var r = (rng ?? _defaultRng)();
  var expMs = _baseBackoffMs * (1 << attempt.clamp(0, 6));
  var ms = (expMs * r).round().clamp(0, _maxBackoff.inMilliseconds);
  return Duration(milliseconds: ms);
}

/// A per-bucket counting semaphore whose limit is queried live via [limitOf],
/// so an AIMD controller or a settings change can shrink/grow it at runtime.
class ConcurrencyGate {
  ConcurrencyGate(this.limitOf);

  final int Function(String bucket) limitOf;
  final _active = <String, int>{};
  final _waiters = <String, List<Completer<void>>>{};

  int activeOf(String bucket) => _active[bucket] ?? 0;

  int waitingOf(String bucket) => _waiters[bucket]?.length ?? 0;

  /// Waits for a slot in [bucket].
  ///
  /// [maxWait] bounds the wait. Every holder is expected to bound its own work
  /// and release in a `finally`, so a slot should always come free — but if a
  /// holder ever fails to (a bug, or a platform call that never returns), an
  /// unbounded wait here turns one stuck operation into a permanently frozen
  /// queue with no error surfaced anywhere. Timing out throws [TimeoutException]
  /// so the caller fails that item and keeps going.
  Future<void> acquire(String bucket, {Duration? maxWait}) {
    if (activeOf(bucket) < limitOf(bucket)) {
      _active[bucket] = activeOf(bucket) + 1;
      return Future.value();
    }
    var completer = Completer<void>();
    var waiters = _waiters[bucket] ??= <Completer<void>>[];
    waiters.add(completer);
    if (maxWait == null) return completer.future;
    // On timeout the waiter is dropped WITHOUT taking a slot, so a later
    // release still hands its slot to a live waiter instead of a dead one.
    return completer.future.timeout(
      maxWait,
      onTimeout: () {
        waiters.remove(completer);
        throw TimeoutException('Waited too long for a slot', maxWait);
      },
    );
  }

  void release(String bucket) {
    _active[bucket] = max(0, activeOf(bucket) - 1);
    _drain(bucket);
  }

  void _drain(String bucket) {
    var waiters = _waiters[bucket];
    if (waiters == null) return;
    while (waiters.isNotEmpty && activeOf(bucket) < limitOf(bucket)) {
      _active[bucket] = activeOf(bucket) + 1;
      waiters.removeAt(0).complete();
    }
  }
}

/// Additive-increase / multiplicative-decrease concurrency estimate per bucket.
/// Starts optimistic (at [max]); halves on a rate-limit signal, then grows back
/// one step per success after a short cooldown of ignored successes. Purely
/// count-based (no wall clock) so it is deterministic and unit-testable.
class AimdController {
  AimdController({this.min = 1, this.max = 6, this.coolSuccesses = 3});

  final int min;
  final int max;
  final int coolSuccesses;

  final _limits = <String, double>{};
  final _cooldown = <String, int>{};

  int limitFor(String bucket) =>
      (_limits[bucket] ?? max.toDouble()).round().clamp(min, max);

  void onSuccess(String bucket) {
    var cool = _cooldown[bucket] ?? 0;
    if (cool > 0) {
      _cooldown[bucket] = cool - 1;
      return;
    }
    var cur = _limits[bucket] ?? max.toDouble();
    _limits[bucket] = min.toDouble() > cur + 1.0
        ? min.toDouble()
        : (cur + 1.0 > max.toDouble() ? max.toDouble() : cur + 1.0);
  }

  void onRateLimited(String bucket) {
    var cur = _limits[bucket] ?? max.toDouble();
    var halved = cur / 2.0;
    _limits[bucket] = halved < min.toDouble() ? min.toDouble() : halved;
    _cooldown[bucket] = coolSuccesses;
  }
}
