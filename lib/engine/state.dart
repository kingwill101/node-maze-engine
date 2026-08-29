/// Deferred, typed application state with transition observation.
class StateMachine<T extends Object> {
  StateMachine(this.current);

  T current;
  T? next;

  bool get hasPendingTransition => next != null && next != current;

  void setNext(T value) => next = value;

  (T, T)? apply() {
    final target = next;
    next = null;
    if (target == null || target == current) return null;
    final previous = current;
    current = target;
    return (previous, target);
  }
}

class StateTransition<T extends Object> {
  const StateTransition(this.from, this.to);

  final T from;
  final T to;
}
