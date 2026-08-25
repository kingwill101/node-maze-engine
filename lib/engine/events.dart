typedef EventListener<T extends Object> = void Function(T event);

class EventBus {
  final Map<Type, List<void Function(Object)>> _listeners = {};

  void on<T extends Object>(EventListener<T> listener) {
    (_listeners[T] ??= []).add((event) => listener(event as T));
  }

  void emit<T extends Object>(T event) {
    for (final listener in List.of(_listeners[T] ?? const [])) {
      listener(event);
    }
  }

  void clear() => _listeners.clear();
}
