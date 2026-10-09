import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snackup/features/user/order_checkout.dart';
import 'package:snackup/features/user/student_order_repository.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late MockFirebaseAuth auth;
  late StudentOrderRepository repository;

  CollectionReference<Map<String, dynamic>> cart() =>
      firestore.collection('users').doc('student-1').collection('cart');

  Future<void> product(
    String id, {
    String businessId = 'cafeteria-1',
    double price = 25.50,
    int stock = 10,
    bool available = true,
    Object? imageUrl = 'https://example.test/snack.png',
  }) => firestore.collection('products').doc(id).set({
    'businessId': businessId,
    'name': 'Snack $id',
    'price': price,
    'priceCents': (price * 100).round(),
    'stock': stock,
    'isAvailable': available,
    'imageUrl': imageUrl,
  });

  Matcher flowError(String fragment) => throwsA(
    isA<OrderFlowException>().having(
      (error) => error.message,
      'message',
      contains(fragment),
    ),
  );

  Future<CheckoutQuote> quote({int quantity = 2}) async {
    await product('sandwich');
    await repository.addProducts([
      CartProductRequest('sandwich', quantity, ' Sin cebolla '),
    ]);
    return repository.prepareQuote(['sandwich']);
  }

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    auth = MockFirebaseAuth(
      mockUser: MockUser(uid: 'student-1', email: 'student@example.test'),
      signedIn: true,
    );
    repository = StudentOrderRepository(firestore: firestore, auth: auth);
    await firestore.collection('users').doc('student-1').set({
      'displayName': 'Estudiante SnackUP',
      'numeroDeControl': '20260001',
    });
    await firestore.collection('businesses').doc('cafeteria-1').set({
      'isOpen': true,
    });
  });

  group('current catalog and cart', () {
    test('persists catalog prices, sanitized notes and a server timestamp', () async {
      await product('sandwich');
      await repository.addProducts([
        const CartProductRequest('sandwich', 2, ' Sin cebolla '),
      ]);

      final line = (await cart().doc('sandwich').get()).data()!;
      expect(line, containsPair('productId', 'sandwich'));
      expect(line, containsPair('businessId', 'cafeteria-1'));
      expect(line, containsPair('name', 'Snack sandwich'));
      expect(line, containsPair('price', 25.50));
      expect(line, containsPair('quantity', 2));
      expect(line, containsPair('notes', 'Sin cebolla'));
      expect(line['imageUrl'], 'https://example.test/snack.png');
      expect(line['addedAt'], isA<Timestamp>());
    });

    test('reordering adds quantity and refreshes the current catalog price', () async {
      await product('sandwich', imageUrl: 42);
      await repository.addProducts([
        const CartProductRequest('sandwich', 2, 'Anterior'),
      ]);
      await product('sandwich', price: 26, imageUrl: null);
      await repository.addProducts([
        const CartProductRequest('sandwich', 3, ' Nueva instrucción '),
      ]);

      final line = (await cart().doc('sandwich').get()).data()!;
      expect(line['quantity'], 5);
      expect(line['price'], 26);
      expect(line['imageUrl'], '');
      expect(line['notes'], 'Nueva instrucción');
    });

    test('rejects empty, oversized and duplicate selections', () async {
      await expectLater(repository.addProducts([]), flowError('1 y 8'));
      await expectLater(
        repository.addProducts(List.generate(
          9,
          (index) => CartProductRequest('product-$index', 1, ''),
        )),
        flowError('1 y 8'),
      );
      await expectLater(repository.addProducts([
        const CartProductRequest('sandwich', 1, ''),
        const CartProductRequest('sandwich', 1, ''),
      ]), flowError('repetidos'));
      expect((await cart().get()).docs, isEmpty);
    });

    test('enforces the eight distinct products limit against the existing cart', () async {
      for (var index = 0; index < maxOrderLines; index++) {
        await product('product-$index');
      }
      await repository.addProducts(List.generate(
        maxOrderLines,
        (index) => CartProductRequest('product-$index', 1, ''),
      ));
      await product('extra');

      await expectLater(repository.addProducts([
        const CartProductRequest('extra', 1, ''),
      ]), flowError('hasta 8'));
      expect((await cart().get()).docs, hasLength(maxOrderLines));
    });

    test('blocks a removed product and a closed cafeteria', () async {
      await expectLater(repository.addProducts([
        const CartProductRequest('removed', 1, ''),
      ]), flowError('ya no está disponible'));
      await product('sandwich');
      await firestore.collection('businesses').doc('cafeteria-1').update({
        'isOpen': false,
      });
      await expectLater(repository.addProducts([
        const CartProductRequest('sandwich', 1, ''),
      ]), flowError('cerrado'));
      expect((await cart().get()).docs, isEmpty);
    });

    test('prevents mixing products from two cafeterias', () async {
      await product('sandwich');
      await product('coffee', businessId: 'cafeteria-2');
      await expectLater(repository.addProducts([
        const CartProductRequest('sandwich', 1, ''),
        const CartProductRequest('coffee', 1, ''),
      ]), flowError('otro local'));
      await repository.addProducts([
        const CartProductRequest('sandwich', 1, ''),
      ]);
      await expectLater(repository.addProducts([
        const CartProductRequest('coffee', 1, ''),
      ]), flowError('otro local'));
      expect((await cart().get()).docs.map((line) => line.id), ['sandwich']);
    });

    test('rejects missing business identity, unavailable stock and invalid prices', () async {
      await product('sandwich', businessId: '');
      await expectLater(repository.addProducts([
        const CartProductRequest('sandwich', 1, ''),
      ]), flowError('otro local'));
      await product('sandwich', available: false);
      await expectLater(repository.addProducts([
        const CartProductRequest('sandwich', 1, ''),
      ]), flowError('disponibilidad'));
      await product('sandwich', stock: 1);
      await expectLater(repository.addProducts([
        const CartProductRequest('sandwich', 2, ''),
      ]), flowError('disponibilidad'));
      await product('sandwich');
      await firestore.collection('products').doc('sandwich').update({'price': 0});
      await expectLater(repository.addProducts([
        const CartProductRequest('sandwich', 1, ''),
      ]), flowError('precio'));
      expect((await cart().get()).docs, isEmpty);
    });

    test('validates combined quantity against current stock before changing a line', () async {
      await product('sandwich', stock: 3);
      await repository.addProducts([
        const CartProductRequest('sandwich', 2, ''),
      ]);
      await expectLater(repository.addProducts([
        const CartProductRequest('sandwich', 2, ''),
      ]), flowError('disponibilidad'));
      expect((await cart().doc('sandwich').get()).data()!['quantity'], 2);
    });
  });

  group('quotation and order persistence', () {
    test('quotation ignores tampered cart prices and uses the live catalog', () async {
      await quote();
      await cart().doc('sandwich').update({'price': 0.01, 'name': 'Alterado'});
      final current = await repository.prepareQuote(['sandwich']);
      expect(current.businessId, 'cafeteria-1');
      expect(current.totalCents, 5100);
      expect(current.items.single['name'], 'Snack sandwich');
      expect(current.items.single['unitPriceCents'], 2550);
    });

    test('quotation rejects invalid size and missing cart lines', () async {
      await expectLater(repository.prepareQuote([]), flowError('1 a 8'));
      await expectLater(
        repository.prepareQuote(List.generate(9, (index) => 'item-$index')),
        flowError('1 a 8'),
      );
      await expectLater(
        repository.prepareQuote(['missing']),
        flowError('carrito cambió'),
      );
    });

    test('quotation reports removal of its catalog product or business', () async {
      await quote();
      await firestore.collection('products').doc('sandwich').delete();
      await expectLater(
        repository.prepareQuote(['sandwich']),
        flowError('local de este pedido'),
      );
      await product('sandwich');
      await firestore.collection('businesses').doc('cafeteria-1').delete();
      await expectLater(
        repository.prepareQuote(['sandwich']),
        flowError('cerrado'),
      );
    });

    test('confirmed order stores exact cents, pickup data and empties only its cart', () async {
      final confirmed = await quote();
      await firestore.collection('users').doc('other-student').collection('cart')
          .doc('sandwich').set({'quantity': 1});
      final pickup = DateTime.now().add(const Duration(hours: 1));
      final id = await repository.placeOrder(
        confirmedQuote: confirmed,
        paymentMethod: 'Tarjeta',
        pickupTime: pickup,
      );
      final order = (await firestore.collection('orders').doc(id).get()).data()!;
      expect(order['businessId'], 'cafeteria-1');
      expect(order['userId'], 'student-1');
      expect(order['userDisplayName'], 'Estudiante SnackUP');
      expect(order['userNumeroDeControl'], '20260001');
      expect(order['status'], 'pending');
      expect(order['totalCents'], 5100);
      expect(order['totalPrice'], 51);
      expect(order['paymentMethod'], 'Tarjeta');
      expect(order['schemaVersion'], 2);
      expect(order['createdAt'], isA<Timestamp>());
      expect((order['scheduledPickupTime'] as Timestamp).toDate(), pickup);
      expect(order['items'], confirmed.items);
      expect(order['pickupCode'], matches(RegExp(r'^[0-9a-f]{32}$')));
      expect((await cart().get()).docs, isEmpty);
      expect((await firestore.collection('users').doc('other-student')
          .collection('cart').doc('sandwich').get()).exists, isTrue);
    });

    test('allows immediate pickup and uses safe profile display defaults', () async {
      final confirmed = await quote(quantity: 1);
      await firestore.collection('users').doc('student-1').set({
        'displayName': 42,
        'numeroDeControl': null,
      });
      final id = await repository.placeOrder(
        confirmedQuote: confirmed,
        paymentMethod: 'Efectivo',
      );
      final order = (await firestore.collection('orders').doc(id).get()).data()!;
      expect(order['userDisplayName'], 'Estudiante');
      expect(order['userNumeroDeControl'], '');
      expect(order['scheduledPickupTime'], isNull);
    });

    test('invalid payment and pickup leave the cart intact without creating an order', () async {
      final confirmed = await quote();
      await expectLater(repository.placeOrder(
        confirmedQuote: confirmed,
        paymentMethod: 'Crédito no admitido',
      ), flowError('forma de pago'));
      await expectLater(repository.placeOrder(
        confirmedQuote: confirmed,
        paymentMethod: 'Efectivo',
        pickupTime: DateTime.now().subtract(const Duration(minutes: 1)),
      ), flowError('hora futura'));
      expect((await firestore.collection('orders').get()).docs, isEmpty);
      expect((await cart().get()).docs, hasLength(1));
    });

    test('changed price requires a fresh quotation and confirmation', () async {
      final confirmed = await quote();
      await product('sandwich', price: 30);
      await expectLater(repository.placeOrder(
        confirmedQuote: confirmed,
        paymentMethod: 'Vale',
      ), flowError('Cambió el precio'));
      expect((await firestore.collection('orders').get()).docs, isEmpty);
      expect((await cart().get()).docs, hasLength(1));
      final refreshed = await repository.prepareQuote(['sandwich']);
      expect(refreshed.totalCents, 6000);
      final id = await repository.placeOrder(
        confirmedQuote: refreshed,
        paymentMethod: 'Vale',
      );
      expect((await firestore.collection('orders').doc(id).get()).data()!
          ['totalCents'], 6000);
    });

    test('revalidates product removal and stock at order confirmation', () async {
      final confirmed = await quote();
      await firestore.collection('products').doc('sandwich').delete();
      await expectLater(repository.placeOrder(
        confirmedQuote: confirmed,
        paymentMethod: 'Efectivo',
      ), flowError('ya no existe'));
      await product('sandwich', stock: 1);
      await expectLater(repository.placeOrder(
        confirmedQuote: confirmed,
        paymentMethod: 'Efectivo',
      ), flowError('disponibilidad'));
      expect((await firestore.collection('orders').get()).docs, isEmpty);
      expect((await cart().get()).docs, hasLength(1));
    });

    test('blocks removed cart lines and prevents submitting the same order twice', () async {
      final confirmed = await quote();
      await repository.placeOrder(
        confirmedQuote: confirmed,
        paymentMethod: 'Efectivo',
      );
      await expectLater(repository.placeOrder(
        confirmedQuote: confirmed,
        paymentMethod: 'Efectivo',
      ), flowError('carrito ya cambió'));
      expect((await firestore.collection('orders').get()).docs, hasLength(1));
    });

    test('requires a saved student profile before persisting an order', () async {
      final confirmed = await quote();
      await firestore.collection('users').doc('student-1').delete();
      await expectLater(repository.placeOrder(
        confirmedQuote: confirmed,
        paymentMethod: 'Efectivo',
      ), flowError('perfil'));
      expect((await firestore.collection('orders').get()).docs, isEmpty);
      expect((await cart().get()).docs, hasLength(1));
    });
  });

  test('all mutations and quotation require an authenticated student', () async {
    final confirmed = await quote();
    await auth.signOut();
    await expectLater(repository.addProducts([
      const CartProductRequest('sandwich', 1, ''),
    ]), flowError('Inicia sesión'));
    await expectLater(
      repository.prepareQuote(['sandwich']),
      flowError('Inicia sesión'),
    );
    await expectLater(repository.placeOrder(
      confirmedQuote: confirmed,
      paymentMethod: 'Efectivo',
    ), flowError('Inicia sesión'));
    expect((await firestore.collection('orders').get()).docs, isEmpty);
  });

  test('error messages distinguish flow validation, permission and connectivity', () {
    expect(studentOrderError(const OrderFlowException('Revisa el carrito.')),
        'Revisa el carrito.');
    expect(studentOrderError(FirebaseException(
      plugin: 'cloud_firestore',
      code: 'permission-denied',
    )), contains('No tienes permiso'));
    expect(studentOrderError(FirebaseException(
      plugin: 'cloud_firestore',
      code: 'unavailable',
    )), contains('conexión'));
    expect(studentOrderError(StateError('Internal detail')),
        isNot(contains('Internal detail')));
  });
}
