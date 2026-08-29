import 'dart:async';

/// Implemented by resources that own subscriptions, native handles, or files.
abstract interface class DisposableResource {
  FutureOr<void> dispose();
}

/// Type-indexed singleton storage, equivalent to Bevy resources.
class Resources {
  final Map<Type, Object> _values = <Type, Object>{};

  void insert<T extends Object>(T value) => _values[T] = value;

  void insertObject(Object value) => _values[value.runtimeType] = value;

  bool contains<T extends Object>() => _values.containsKey(T);

  T? maybeGet<T extends Object>() => _values[T] as T?;

  T get<T extends Object>() =>
      maybeGet<T>() ?? (throw StateError('Resource $T is not installed'));

  T? remove<T extends Object>() => _values.remove(T) as T?;

  Iterable<Type> get types => _values.keys;

  Iterable<Object> get values => _values.values;
}
