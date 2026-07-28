import 'package:flutter_test/flutter_test.dart';
import 'package:snackup/core/orders/order_status.dart';

void main() {
  group('OrderStatus - cobertura de decisiones', () {
    test('pending permite preparar o cancelar', () {
      expect(
        OrderStatus.pending.canTransitionTo(OrderStatus.preparing),
        isTrue,
      );
      expect(
        OrderStatus.pending.canTransitionTo(OrderStatus.cancelled),
        isTrue,
      );
      expect(
        OrderStatus.pending.canTransitionTo(OrderStatus.completed),
        isFalse,
      );
    });

    test('preparing permite listo o cancelado', () {
      expect(OrderStatus.preparing.canTransitionTo(OrderStatus.ready), isTrue);
      expect(
        OrderStatus.preparing.canTransitionTo(OrderStatus.cancelled),
        isTrue,
      );
      expect(
        OrderStatus.preparing.canTransitionTo(OrderStatus.completed),
        isFalse,
      );
    });

    test('ready solo permite completar', () {
      expect(OrderStatus.ready.canTransitionTo(OrderStatus.completed), isTrue);
      expect(OrderStatus.ready.canTransitionTo(OrderStatus.cancelled), isFalse);
    });

    test('los estados terminales no permiten transiciones', () {
      for (final status in [OrderStatus.completed, OrderStatus.cancelled]) {
        expect(status.isTerminal, isTrue);
        expect(status.canTransitionTo(OrderStatus.pending), isFalse);
      }
    });

    test('convierte valores válidos de Firestore', () {
      expect(OrderStatus.fromFirestore('preparing'), OrderStatus.preparing);
    });

    test('rechaza estados desconocidos', () {
      expect(() => OrderStatus.fromFirestore('unknown'), throwsFormatException);
    });
  });
}
