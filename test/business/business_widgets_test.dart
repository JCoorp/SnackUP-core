import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snackup/features/business/add_edit_product_screen.dart';
import 'package:snackup/features/business/manage_menu_screen.dart';
import 'package:snackup/features/business/order_detail_screen.dart';
import 'package:snackup/features/business/order_list_tab.dart';
import 'package:snackup/features/business/statistics_screen.dart';
import 'package:snackup/features/business/view_orders_screen.dart';
import 'package:snackup/features/home/business_home_screen.dart';

const businessId = 'cafeteria-a';
const orderId = 'order-00000001';

Map<String, dynamic> product({int stock = 10}) => {
  'businessId': businessId,
  'name': 'Taco al pastor',
  'description': 'Taco recién preparado',
  'category': 'TACOS',
  'price': 25.0,
  'priceCents': 2500,
  'stock': stock,
  'isAvailable': true,
  'isFeatured': true,
};

Map<String, dynamic> order(String status) => {
  'businessId': businessId,
  'status': status,
  'userDisplayName': 'Ana López',
  'userNumeroDeControl': '20260001',
  'totalPrice': 50.0,
  'paymentMethod': 'Efectivo',
  'pickupCode': 'pickup-123',
  'createdAt': Timestamp.fromDate(DateTime.now()),
  'items': [
    {'productId': 'taco-a', 'name': 'Taco al pastor', 'quantity': 2,
      'price': 25.0, 'notes': 'Sin cebolla'},
  ],
};

Future<void> showScreen(WidgetTester tester, Widget screen) async {
  await tester.binding.setSurfaceSize(const Size(1200, 2200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) =>
    Scaffold(body: FilledButton(
      onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => screen,
      )),
      child: const Text('Abrir pantalla'),
    )),
  )));
  await tester.tap(find.text('Abrir pantalla'));
  await tester.pumpAndSettle();
}

MockFirebaseAuth ownerAuth() => MockFirebaseAuth(
  mockUser: MockUser(uid: 'owner-a', email: 'negocio@utsjr.edu.mx'),
  signedIn: true,
);

Future<FakeFirebaseFirestore> businessStore() async {
  final db = FakeFirebaseFirestore();
  await db.collection('businesses').doc(businessId).set({
    'name': 'Cafetería de Ana', 'ownerId': 'owner-a', 'isOpen': true,
  });
  return db;
}

Future<void> showOrder(WidgetTester tester, FakeFirebaseFirestore db,
    String status, {MockFirebaseAuth? auth}) async {
  await db.collection('orders').doc(orderId).set(order(status));
  await showScreen(tester, OrderDetailScreen(orderId: orderId,
    businessId: businessId, firestore: db, auth: auth ?? ownerAuth()));
}

Future<void> tapVisible(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('empty menu offers creation and opens the product form', (tester) async {
    final db = FakeFirebaseFirestore();
    await showScreen(tester, ManageMenuScreen(businessId: businessId, firestore: db));
    expect(find.text('Tu menú está vacío'), findsOneWidget);
    await tapVisible(tester, find.text('Agregar Primer Producto'));
    expect(find.text('Nuevo Producto'), findsOneWidget);
    expect(find.text('Nombre del Producto'), findsOneWidget);
    expect(find.text('Disponible para pedir'), findsOneWidget);
  });

  testWidgets('menu groups products and shows price, stock and availability', (tester) async {
    final db = FakeFirebaseFirestore();
    await db.collection('products').doc('taco-a').set(product());
    await db.collection('products').doc('agua-a').set({
      ...product(stock: 0), 'name': 'Agua de jamaica', 'category': 'BEBIDAS',
      'isAvailable': false, 'isFeatured': false,
    });
    await db.collection('products').doc('foreign').set({
      ...product(), 'businessId': 'cafeteria-b', 'name': 'Producto ajeno',
    });
    await showScreen(tester, ManageMenuScreen(businessId: businessId, firestore: db));
    expect(find.text('TACOS'), findsOneWidget);
    expect(find.text('BEBIDAS'), findsOneWidget);
    expect(find.text('Stock: 10'), findsOneWidget);
    expect(find.text('Stock: 0'), findsOneWidget);
    expect(find.text('Producto ajeno'), findsNothing);
  });

  testWidgets('pending list filters out other businesses and scheduled orders', (tester) async {
    final db = FakeFirebaseFirestore();
    await db.collection('orders').doc(orderId).set(order('pending'));
    await db.collection('orders').doc('scheduled').set({
      ...order('pending'), 'userDisplayName': 'Programado',
      'scheduledPickupTime': Timestamp.fromDate(DateTime.now()),
    });
    await db.collection('orders').doc('foreign').set({
      ...order('pending'), 'businessId': 'cafeteria-b', 'userDisplayName': 'Ajeno',
    });
    await showScreen(tester, Scaffold(body: OrderListTab(businessId: businessId,
      status: 'pending', orderType: 'asap', firestore: db)));
    expect(find.text('Pedido de Ana López'), findsOneWidget);
    expect(find.text('2x Taco al pastor'), findsOneWidget);
    expect(find.text('2 productos en total'), findsOneWidget);
    expect(find.text('Nuevo pedido'), findsOneWidget);
    expect(find.text('Pedido de Programado'), findsNothing);
    expect(find.text('Pedido de Ajeno'), findsNothing);
    await tapVisible(tester, find.text('Pedido de Ana López'));
    expect(find.text('Detalle del Pedido'), findsOneWidget);
    expect(find.text('20260001'), findsOneWidget);
  });

  testWidgets('scheduled list retains overdue orders and sorts pickup time', (tester) async {
    final db = FakeFirebaseFirestore();
    await db.collection('orders').doc('later-0001').set({
      ...order('pending'), 'userDisplayName': 'Después',
      'scheduledPickupTime': Timestamp.fromDate(DateTime(2026, 10, 9, 13)),
    });
    await db.collection('orders').doc('early-0001').set({
      ...order('pending'), 'userDisplayName': 'Primero',
      'scheduledPickupTime': Timestamp.fromDate(DateTime(2026, 10, 9, 10)),
    });
    await showScreen(tester, Scaffold(body: OrderListTab(businessId: businessId,
      status: 'pending', orderType: 'scheduled', firestore: db)));
    expect(find.text('Recoger: 10:00'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Pedido de Primero')).dy,
      lessThan(tester.getTopLeft(find.text('Pedido de Después')).dy));
  });

  for (final state in ['preparing', 'ready', 'completed', 'cancelled', 'other']) {
    testWidgets('empty $state orders show an explanatory state', (tester) async {
      await showScreen(tester, Scaffold(body: OrderListTab(businessId: businessId,
        status: state, orderType: 'all', firestore: FakeFirebaseFirestore())));
      expect(find.text('Los pedidos aparecerán aquí cuando cambien a este estado'),
        findsOneWidget);
    });
  }

  testWidgets('order tabs switch between scheduled and new orders', (tester) async {
    final db = FakeFirebaseFirestore();
    await showScreen(tester, ViewOrdersScreen(businessId: businessId, firestore: db));
    expect(find.text('Pedidos Nuevos'), findsOneWidget);
    await tapVisible(tester, find.text('Programados'));
    expect(find.text('Pedidos Programados'), findsOneWidget);
    await tapVisible(tester, find.text('Preparando'));
    expect(find.text('En Preparación'), findsOneWidget);
  });

  testWidgets('missing order and ownership mismatch cannot show actions', (tester) async {
    final db = FakeFirebaseFirestore();
    await showScreen(tester, OrderDetailScreen(orderId: orderId,
      businessId: businessId, firestore: db));
    expect(find.text('Pedido no encontrado'), findsOneWidget);
    await db.collection('orders').doc(orderId).set({
      ...order('pending'), 'businessId': 'cafeteria-b',
    });
    await tester.pumpAndSettle();
    expect(find.text('Este pedido no pertenece a tu negocio.'), findsOneWidget);
    expect(find.text('Aceptar Pedido'), findsNothing);
  });

  testWidgets('accepting an order reserves stock and advances the visible status', (tester) async {
    final db = await businessStore();
    await db.collection('products').doc('taco-a').set(product());
    await showOrder(tester, db, 'pending');
    expect(find.text('Ana López'), findsOneWidget);
    expect(find.text('Sin cebolla'), findsOneWidget);
    await tapVisible(tester, find.text('Aceptar Pedido'));
    expect((await db.collection('orders').doc(orderId).get()).data()!['status'],
      'preparing');
    expect((await db.collection('products').doc('taco-a').get()).data()!['stock'], 8);
    expect(find.text('PREPARANDO'), findsOneWidget);
    await tapVisible(tester, find.text('Marcar como Listo'));
    expect((await db.collection('orders').doc(orderId).get()).data()!['status'], 'ready');
    expect(find.text('Entrega Manual'), findsOneWidget);
  });

  testWidgets('insufficient stock rejects acceptance without changing the order', (tester) async {
    final db = await businessStore();
    await db.collection('products').doc('taco-a').set(product(stock: 1));
    await showOrder(tester, db, 'pending');
    await tapVisible(tester, find.text('Aceptar Pedido'));
    expect(find.textContaining('No hay stock disponible'), findsOneWidget);
    expect((await db.collection('orders').doc(orderId).get()).data()!['status'], 'pending');
  });

  testWidgets('expired business session cannot update an order', (tester) async {
    final db = await businessStore();
    await showOrder(tester, db, 'preparing', auth: MockFirebaseAuth());
    await tapVisible(tester, find.text('Marcar como Listo'));
    expect(find.text('Inicia sesión de nuevo.'), findsOneWidget);
    expect((await db.collection('orders').doc(orderId).get()).data()!['status'], 'preparing');
  });

  testWidgets('cancellation dialog explains inventory and supports cancel then confirm', (tester) async {
    final db = await businessStore();
    await showOrder(tester, db, 'pending');
    await tapVisible(tester, find.text('Cancelar Pedido'));
    expect(find.textContaining('inventario reservado no se repone'), findsOneWidget);
    await tapVisible(tester, find.text('Volver'));
    expect((await db.collection('orders').doc(orderId).get()).data()!['status'], 'pending');
    await tapVisible(tester, find.text('Cancelar Pedido'));
    await tapVisible(tester, find.text('Cancelar pedido').last);
    expect((await db.collection('orders').doc(orderId).get()).data()!['status'], 'cancelled');
    expect(find.text('Abrir pantalla'), findsOneWidget);
  });

  testWidgets('manual delivery rejects wrong code and completes the matching order', (tester) async {
    final db = await businessStore();
    await showOrder(tester, db, 'ready');
    await tapVisible(tester, find.text('Entrega Manual'));
    expect(find.text('Confirmar entrega'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'wrong');
    await tapVisible(tester, find.text('Confirmar'));
    expect(find.text('Código de entrega incorrecto.'), findsOneWidget);
    expect((await db.collection('orders').doc(orderId).get()).data()!['status'], 'ready');
    await tapVisible(tester, find.text('Entrega Manual'));
    await tester.enterText(find.byType(TextField), 'pickup-123');
    await tapVisible(tester, find.text('Confirmar'));
    final completed = (await db.collection('orders').doc(orderId).get()).data()!;
    expect(completed['status'], 'completed');
    expect(completed['completedAt'], isA<Timestamp>());
  });

  for (final state in ['completed', 'cancelled']) {
    testWidgets('$state order displays history without further action buttons', (tester) async {
      await showOrder(tester, FakeFirebaseFirestore(), state);
      expect(find.text(state == 'completed' ? 'Pedido completado y entregado' :
        'Pedido cancelado'), findsOneWidget);
      expect(find.text('Aceptar Pedido'), findsNothing);
      expect(find.text('Entrega Manual'), findsNothing);
    });
  }

  testWidgets('new product form validates required name category price and stock', (tester) async {
    await showScreen(tester, AddEditProductScreen(businessId: businessId,
      firestore: FakeFirebaseFirestore(), auth: ownerAuth()));
    await tapVisible(tester, find.text('Agregar Producto'));
    expect(find.text('El nombre es obligatorio'), findsOneWidget);
    expect(find.text('La categoría es obligatoria'), findsOneWidget);
    expect(find.text('El precio es obligatorio'), findsOneWidget);
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Taco');
    await tester.enterText(fields.at(1), 'Tacos');
    await tester.enterText(fields.at(3), '-3');
    await tester.enterText(fields.at(4), '-1');
    await tapVisible(tester, find.text('Agregar Producto'));
    expect(find.text('Precio entre \$0.01 y \$10,000'), findsOneWidget);
    expect(find.text('Stock entre 0 y 1,000,000'), findsOneWidget);
  });

  testWidgets('owner creates a product with normalized category cents and toggles', (tester) async {
    final db = await businessStore();
    await showScreen(tester, AddEditProductScreen(businessId: businessId,
      firestore: db, auth: ownerAuth()));
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '  Agua fresca  ');
    await tester.enterText(fields.at(1), 'bebidas');
    await tester.enterText(fields.at(2), 'Jamaica');
    await tester.enterText(fields.at(3), '12,50');
    await tester.enterText(fields.at(4), '7');
    await tapVisible(tester, find.byType(Switch).at(1));
    await tapVisible(tester, find.text('Agregar Producto'));
    final products = await db.collection('products').get();
    expect(products.docs, hasLength(1));
    final saved = products.docs.single.data();
    expect(saved['name'], 'Agua fresca');
    expect(saved['category'], 'BEBIDAS');
    expect(saved['priceCents'], 1250);
    expect(saved['stock'], 7);
    expect(saved['isFeatured'], isTrue);
    expect(saved['isAvailable'], isTrue);
    expect(find.text('Abrir pantalla'), findsOneWidget);
  });

  testWidgets('edit product loads cents and protects changed inventory', (tester) async {
    final db = await businessStore();
    await db.collection('products').doc('taco-a').set(product());
    await showScreen(tester, AddEditProductScreen(businessId: businessId,
      productId: 'taco-a', firestore: db, auth: ownerAuth()));
    final fields = find.byType(TextFormField);
    expect(tester.widget<TextFormField>(fields.at(3)).controller!.text, '25.00');
    await db.collection('products').doc('taco-a').update({'stock': 8});
    await tester.enterText(fields.at(0), 'Taco actualizado');
    await tapVisible(tester, find.text('Guardar Cambios'));
    final saved = (await db.collection('products').doc('taco-a').get()).data()!;
    expect(saved['name'], 'Taco actualizado');
    expect(saved['stock'], 8, reason: 'Untouched stock must not overwrite a reservation');
  });

  testWidgets('explicit stock edit detects a concurrent reservation', (tester) async {
    final db = await businessStore();
    await db.collection('products').doc('taco-a').set(product());
    await showScreen(tester, AddEditProductScreen(businessId: businessId,
      productId: 'taco-a', firestore: db, auth: ownerAuth()));
    await db.collection('products').doc('taco-a').update({'stock': 8});
    await tester.enterText(find.byType(TextFormField).at(4), '20');
    await tapVisible(tester, find.text('Guardar Cambios'));
    expect(find.textContaining('El stock cambió mientras editabas'), findsOneWidget);
    expect((await db.collection('products').doc('taco-a').get()).data()!['stock'], 8);
  });

  testWidgets('missing product provides retry rather than a writable empty form', (tester) async {
    final db = FakeFirebaseFirestore();
    await showScreen(tester, AddEditProductScreen(businessId: businessId,
      productId: 'missing', firestore: db));
    expect(find.text('No se pudo cargar el producto. Verifica tu conexión y permisos.'),
      findsOneWidget);
    await db.collection('products').doc('missing').set(product());
    await tapVisible(tester, find.text('Reintentar'));
    expect(find.text('Guardar Cambios'), findsOneWidget);
  });

  testWidgets('product deletion requires confirmation and removes only that product', (tester) async {
    final db = await businessStore();
    await db.collection('products').doc('taco-a').set(product());
    await showScreen(tester, AddEditProductScreen(businessId: businessId,
      productId: 'taco-a', firestore: db, auth: ownerAuth()));
    await tapVisible(tester, find.byTooltip('Eliminar producto'));
    await tapVisible(tester, find.text('Cancelar'));
    expect((await db.collection('products').doc('taco-a').get()).exists, isTrue);
    await tapVisible(tester, find.byTooltip('Eliminar producto'));
    await tapVisible(tester, find.text('Eliminar'));
    expect((await db.collection('products').doc('taco-a').get()).exists, isFalse);
  });

  testWidgets('statistics distinguish empty and pending-only orders', (tester) async {
    final db = FakeFirebaseFirestore();
    await showScreen(tester, StatisticsScreen(businessId: businessId, firestore: db));
    expect(find.text('Aún no tienes estadísticas'), findsOneWidget);
    await db.collection('orders').doc(orderId).set(order('pending'));
    await tester.pumpAndSettle();
    expect(find.text('Aún no tienes estadísticas'), findsOneWidget);
  });

  testWidgets('statistics aggregate delivered totals and show all chart sections', (tester) async {
    final db = FakeFirebaseFirestore();
    await db.collection('orders').doc(orderId).set({
      ...order('completed'), 'completedAt': Timestamp.fromDate(DateTime.now()),
    });
    await db.collection('orders').doc('pending').set(order('pending'));
    await showScreen(tester, StatisticsScreen(businessId: businessId, firestore: db));
    expect(find.text('Importe entregado'), findsOneWidget);
    expect(find.text('\$50.00'), findsWidgets);
    expect(find.text('Pedidos Completados:'), findsOneWidget);
    expect(find.text('Productos Más Vendidos'), findsOneWidget);
    expect(find.text('Métodos de Pago'), findsOneWidget);
    expect(find.text('Efectivo (100%)'), findsOneWidget);
  });

  testWidgets('business home retries missing membership and changes availability', (tester) async {
    final db = FakeFirebaseFirestore();
    final auth = ownerAuth();
    await showScreen(tester, BusinessHomeScreen(firestore: db, auth: auth));
    expect(find.text('Error al cargar el negocio'), findsOneWidget);
    await db.collection('businesses').doc(businessId).set({
      'ownerId': 'owner-a', 'name': 'Cafetería de Ana', 'isOpen': true,
    });
    await tapVisible(tester, find.text('Reintentar'));
    expect(find.text('Cafetería de Ana'), findsOneWidget);
    expect(find.text('Abierto'), findsOneWidget);
    await tapVisible(tester, find.byType(Switch));
    expect((await db.collection('businesses').doc(businessId).get()).data()!['isOpen'],
      isFalse);
    expect(find.text('Cerrado'), findsOneWidget);
    await tapVisible(tester, find.text('Menú'));
    expect(find.text('Tu menú está vacío'), findsOneWidget);
    await tapVisible(tester, find.text('Estadísticas').last);
    expect(find.text('Aún no tienes estadísticas'), findsOneWidget);
  });

  testWidgets('business logout dialog cancels or signs out the active owner', (tester) async {
    final db = await businessStore();
    final auth = ownerAuth();
    await showScreen(tester, BusinessHomeScreen(firestore: db, auth: auth));
    await tapVisible(tester, find.byTooltip('Cerrar Sesión'));
    await tapVisible(tester, find.text('Cancelar'));
    expect(auth.currentUser, isNotNull);
    await tapVisible(tester, find.byTooltip('Cerrar Sesión'));
    await tapVisible(tester, find.text('Cerrar Sesión').last);
    expect(auth.currentUser, isNull);
  });
  testWidgets('new order alert sounds once and opens pending orders', (tester) async {
    final db = await businessStore();
    var soundCalls = 0;
    await showScreen(tester, BusinessHomeScreen(firestore: db, auth: ownerAuth(),
      playNewOrderSound: () async { soundCalls++; }));
    await tapVisible(tester, find.text('Menú'));
    await db.collection('orders').doc(orderId).set(order('pending'));
    await tester.pumpAndSettle();
    expect(find.text('¡Nuevo Pedido!'), findsOneWidget);
    expect(find.text('Pedidos pendientes: 1'), findsOneWidget);
    expect(soundCalls, 1);
    await tapVisible(tester, find.text('Ver Pedidos'));
    expect(find.text('Pedido de Ana López'), findsOneWidget);
    await db.collection('orders').doc(orderId).update({'status': 'preparing'});
    await tester.pumpAndSettle();
    expect(find.text('¡Nuevo Pedido!'), findsNothing);
    expect(soundCalls, 1, reason: 'A status update is not a new pending order');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

}
