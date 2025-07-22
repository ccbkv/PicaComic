import 'package:meta/meta.dart';

/// A collating function provided to a sql collation.
///
/// The function must return a `int`.
///
/// If invoking the function throws a Dart exception, the sql function will
/// result with an error result as well.
typedef CollatingFunction = int Function(String? textA, String? textB);

/// A scalar function exposed to sql.
///
/// {@template sqlite3_function_behavior}
/// The function must either return a `bool`, `num`, `String`, `List<int>`,
/// `BigInt` or `null`.
///
/// If invoking the function throws a Dart exception, the sql function will
/// result with an error result as well.
/// {@endtemplate}
typedef ScalarFunction = Object? Function(List<Object?> arguments);

/// Interface for application-defined aggregate functions.
///
/// A subclass of [AggregateFunction] should hold no state across invocations.
/// All its state needed during a computation should be stored in an instance of
/// [V].
///
/// As an example, take a look at the following Dart implementation of the
/// `count()` aggregate. Recall that there are two versions of `count()`. With
/// zero arguments, `count()` returns the number of rows. With one argument,
/// `count()` returns the number of times that the argument was non-null.
///
/// ```dart
/// class MyCount implements AggregateFunction<int> {
///  @override
///  AggregateContext<int> createContext() => AggregateContext(0);
///
///  @override
///  void step(List<Object> arguments, AggregateContext<int> context) {
///    if (arguments.isEmpty || arguments.first != null) {
///      context.value++;
///    }
///  }
///
///  @override
///  Object finalize(AggregateContext<int> context) {
///    return context.value;
///  }
///}
/// ```
@immutable
abstract class AggregateFunction<V> {
  /// Creates an initial context holding the initial value before [step] is
  /// called.
  ///
  /// If [step] is never called before the query concludes, the initial context
  /// is also used for [finalize].
  AggregateContext<V> createContext();

  /// Adds a new row to the aggregate.
  ///
  /// The [context] should be modified to reflect the new row calling this
  /// function with [arguments].
  void step(List<Object?> arguments, AggregateContext<V> context);

  /// Computes the final value from a populated [context].
  ///
  /// This is the last call made with the given [context], so this function may
  /// also choose to clean up resources associated with the aggregate context.
  ///
  /// {@macro sqlite3_function_behavior}
  Object? finalize(AggregateContext<V> context);
}

/// A window function for sqlite3.
///
/// In addition to [AggregateFunction]s, which run over an entire query, window
/// functions can run over a subset of rows as defined in an `OVER` clause.
///
/// This example defines a window function taking a single argument, which must
/// be an int. The result of the window function is the sum of all arguments
/// in the current window.
///
/// ```dart
/// class _SumInt implements WindowFunction<int> {
///  @override
///  AggregateContext<int> createContext() => AggregateContext(0);
///
///  @override
///  Object? finalize(AggregateContext<int> context) {
///    // There's nothing to finalize, if our [createContext] had side-effects
///    // we'd have to undo them here.
///    return value(context);
///  }
///
///  int _argument(List<Object?> arguments) {
///    return arguments.single! as int;
///  }
///
///  @override
///  void inverse(List<Object?> arguments, AggregateContext<int> context) {
///    context.value -= _argument(arguments);
///  }
///
///  @override
///  void step(List<Object?> arguments, AggregateContext<int> context) {
///    context.value += _argument(arguments);
///  }
///
///  @override
///  Object? value(AggregateContext<int> context) => context.value;
///}
/// ```

@immutable
abstract class WindowFunction<V> implements AggregateFunction<V> {
  /// Obtain the current aggregate in the window.
  ///
  /// This is similar to [finalize], but shouldn't be used to clean up resources
  /// as subsequent calls may happen with the same [context].
  Object? value(AggregateContext<V> context);

  /// Removes the row of [arguments] from this window.
  void inverse(List<Object?> arguments, AggregateContext<V> context);
}

/// Application-defined context used to compute results in aggregate functions.
final class AggregateContext<V> {
  /// The current value of this context.
  V value;

  /// Creates a context with an initial [value].
  AggregateContext(this.value);
}

/// Describes how many arguments an application-defined sql function can take.
final class AllowedArgumentCount {
  final int allowedArgs;

  const AllowedArgumentCount(this.allowedArgs);
  const AllowedArgumentCount.any() : allowedArgs = -1;
}
