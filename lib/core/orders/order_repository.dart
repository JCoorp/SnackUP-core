import 'package:cloud_firestore/cloud_firestore.dart';

import 'order_status.dart';

abstract interface class OrderDataStore {
  Future<Map<String, Object?>?> read(String orderId);

  Future<void> update(String orderId, Map<String, Object?> values);
}

class FirestoreOrderDataStore implements OrderDataStore {
  FirestoreOrderDataStore(this.firestore);

  final FirebaseFirestore firestore;

  @override
  Future<Map<String, Object?>?> read(String orderId) async {
    final snapshot = await firestore.collection('orders').doc(orderId).get();
    return snapshot.data();
  }

  @override
  Future<void> update(String orderId, Map<String, Object?> values) {
    return firestore.collection('orders').doc(orderId).update(values);
  }
}

class OrderRepository {
  OrderRepository(this.store);

  final OrderDataStore store;

  Future<void> changeStatus({
    required String orderId,
    required OrderStatus next,
  }) async {
    if (orderId.trim().isEmpty) {
      throw ArgumentError.value(orderId, 'orderId', 'No puede estar vacío');
    }

    final order = await store.read(orderId);
    if (order == null) {
      throw StateError('El pedido no existe');
    }

    final rawStatus = order['status'];
    if (rawStatus is! String) {
      throw StateError('El pedido no tiene un estado válido');
    }

    final current = OrderStatus.fromFirestore(rawStatus);
    if (!current.canTransitionTo(next)) {
      throw StateError(
        'Transición no permitida: '
        '${current.firestoreValue} → ${next.firestoreValue}',
      );
    }

    await store.update(orderId, <String, Object?>{
      'status': next.firestoreValue,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
