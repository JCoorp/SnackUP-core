enum OrderStatus {
  pending,
  preparing,
  ready,
  completed,
  cancelled;

  String get firestoreValue => name;

  bool get isTerminal =>
      this == OrderStatus.completed || this == OrderStatus.cancelled;

  bool canTransitionTo(OrderStatus next) {
    return switch (this) {
      OrderStatus.pending =>
        next == OrderStatus.preparing || next == OrderStatus.cancelled,
      OrderStatus.preparing =>
        next == OrderStatus.ready || next == OrderStatus.cancelled,
      OrderStatus.ready => next == OrderStatus.completed,
      OrderStatus.completed || OrderStatus.cancelled => false,
    };
  }

  static OrderStatus fromFirestore(String value) {
    return OrderStatus.values.firstWhere(
      (status) => status.firestoreValue == value,
      orElse: () =>
          throw FormatException('Estado de pedido desconocido: $value'),
    );
  }
}
