import 'package:flutter_test/flutter_test.dart';
import 'package:snackup/core/orders/order_repository.dart';
import 'package:snackup/core/orders/order_status.dart';

class InMemoryOrderDataStore implements OrderDataStore {
  InMemoryOrderDataStore(this.orders);

  final Map<String, Map<String, Object?>> orders;

  @override
  Future<Map<String, Object?>?> read(String orderId) async {
    final order = orders[orderId];
    return order == null ? null : Map<String, Object?>.from(order);
  }

  @override
  Future<void> update(String orderId, Map<String, Object?> values) async {
    orders[orderId]!.addAll(values);
  }
}

void main() {
  group('OrderRepository + OrderDataStore', () {
    test('integra lectura, regla de negocio y escritura', () async {
      final store = InMemoryOrderDataStore({
        'order-1': <String, Object?>{'status': 'pending'},
      });
      final repository = OrderRepository(store);

      await repository.changeStatus(
        orderId: 'order-1',
        next: OrderStatus.preparing,
      );

      expect(store.orders['order-1']!['status'], 'preparing');
      expect(store.orders['order-1']!['updatedAt'], isNotNull);
    });

    test('no escribe cuando la transición es inválida', () async {
      final store = InMemoryOrderDataStore({
        'order-2': <String, Object?>{'status': 'pending'},
      });
      final repository = OrderRepository(store);

      await expectLater(
        repository.changeStatus(
          orderId: 'order-2',
          next: OrderStatus.completed,
        ),
        throwsStateError,
      );

      expect(store.orders['order-2']!['status'], 'pending');
      expect(store.orders['order-2']!.containsKey('updatedAt'), isFalse);
    });

    test('reporta un pedido inexistente', () async {
      final repository = OrderRepository(InMemoryOrderDataStore({}));

      await expectLater(
        repository.changeStatus(
          orderId: 'missing',
          next: OrderStatus.preparing,
        ),
        throwsStateError,
      );
    });
  });
}
