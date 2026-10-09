import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:snackup/features/home/user_dashboard_screen.dart';
import 'package:snackup/features/home/user_home_screen.dart';
import 'package:snackup/features/user/cart_screen.dart';
import 'package:snackup/features/user/menu_screen.dart';
import 'package:snackup/features/user/product_detail_screen.dart';
import 'package:snackup/features/user/profile_orders_screen.dart';
import 'package:snackup/features/user/rate_order_screen.dart';
import 'package:snackup/features/user/search_screen.dart';
import 'package:snackup/features/user/show_qr_screen.dart';

void main() {
  late FakeFirebaseFirestore db;
  late MockFirebaseAuth auth;

  setUp(() {
    db = FakeFirebaseFirestore();
    auth = MockFirebaseAuth(
      mockUser: MockUser(uid: 'student', email: 'student@utsjr.edu.mx',
          displayName: 'Alumno'),
      signedIn: true,
    );
  });

  Future<void> mount(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: screen));
    await tester.pumpAndSettle();
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    final target = find.text(text).last;
    await tester.ensureVisible(target);
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  Map<String, dynamic> product({int stock = 5, bool available = true}) => {
    'businessId': 'cafeteria', 'name': 'Taco', 'name_searchable': 'taco',
    'price': 12.5, 'priceCents': 1250, 'stock': stock,
    'isAvailable': available, 'isFeatured': true, 'category': 'Comida',
    'description': 'Taco preparado al momento', 'imageUrl': '',
  };

  Map<String, dynamic> order(String status, {String owner = 'student'}) => {
    'userId': owner, 'businessId': 'cafeteria', 'status': status,
    'totalPrice': 25.0, 'pickupCode': 'SNACK-TEST-123',
    'createdAt': Timestamp.fromDate(DateTime(2026, 10, 8, 13, 30)),
    'items': [
      {'productId': 'taco', 'name': 'Taco', 'quantity': 2, 'notes': ''},
    ],
  };

  Future<void> catalog() async {
    await db.collection('users').doc('student').set({
      'displayName': 'Alumno', 'numeroDeControl': '20260001',
    });
    await db.collection('businesses').doc('cafeteria').set({
      'name': 'Cafetería UTSJR', 'isOpen': true, 'category': 'Comida',
    });
    await db.collection('products').doc('taco').set(product());
  }

  Future<void> chooseRatings(WidgetTester tester) async {
    for (final label in ['Experiencia general', 'Servicio y atención',
      'Calidad de los alimentos']) {
      final stars = find.byTooltip('$label: 5 estrellas');
      await tester.ensureVisible(stars);
      await tester.tap(stars);
      await tester.pump();
    }
  }

  RateOrderScreen ratingScreen() => RateOrderScreen(
    orderId: 'order', businessId: 'cafeteria',
    businessName: 'Cafetería UTSJR', firestore: db, auth: auth,
  );

  testWidgets('a signed-out student cannot review an order', (tester) async {
    auth = MockFirebaseAuth(signedIn: false);
    await mount(tester, ratingScreen());
    await tapText(tester, 'Enviar reseña');
    expect(find.text('Inicia sesión para enviar tu reseña.'), findsOneWidget);
    expect((await db.collection('reviews').get()).docs, isEmpty);
  });

  testWidgets('all three ratings are required before any review is stored',
      (tester) async {
    await mount(tester, ratingScreen());
    await tapText(tester, 'Enviar reseña');
    expect(find.text('Selecciona de 1 a 5 estrellas en las tres calificaciones.'),
        findsOneWidget);
    expect((await db.collection('reviews').get()).docs, isEmpty);
  });

  testWidgets('a completed owned order stores normalized academic review data',
      (tester) async {
    await db.collection('users').doc('student').set({
      'career': '  Desarrollo   de Software  ', 'group': ' ds02sv-25 ',
    });
    await db.collection('orders').doc('order').set(order('completed'));
    await mount(tester, ratingScreen());
    final fields = find.byType(TextFormField);
    expect(tester.widget<TextFormField>(fields.at(0)).controller!.text,
        'Desarrollo de Software');
    expect(tester.widget<TextFormField>(fields.at(1)).controller!.text,
        'DS02SV-25');
    await chooseRatings(tester);
    await tester.enterText(fields.at(0), '  Ingeniería   de Software ');
    await tester.enterText(fields.at(1), ' ds-2 ');
    await tester.enterText(fields.at(2), '  Buen servicio y alimentos.  ');
    await tapText(tester, 'Enviar reseña');
    final review = (await db.collection('reviews').doc('order').get()).data()!;
    expect(review['rating'], 5);
    expect(review['serviceRating'], 5);
    expect(review['foodRating'], 5);
    expect(review['career'], 'Ingeniería de Software');
    expect(review['group'], 'DS-2');
    expect(review['comment'], 'Buen servicio y alimentos.');
    expect(review['userId'], 'student');
    expect(review.containsKey('name'), isFalse);
  });

  testWidgets('a prior legacy review prevents duplicate submission', (tester) async {
    await db.collection('orders').doc('order').set(order('completed'));
    await db.collection('reviews').doc('legacy').set({
      'userId': 'student', 'orderId': 'order', 'rating': 4,
    });
    await mount(tester, ratingScreen());
    await chooseRatings(tester);
    await tapText(tester, 'Enviar reseña');
    expect(find.text('Ya enviaste una reseña para este pedido.'), findsOneWidget);
    expect((await db.collection('reviews').get()).docs, hasLength(1));
  });

  testWidgets('a preparing order cannot receive a review', (tester) async {
    await db.collection('orders').doc('order').set(order('preparing'));
    await mount(tester, ratingScreen());
    await chooseRatings(tester);
    await tapText(tester, 'Enviar reseña');
    expect(find.text('Podrás calificar el pedido cuando esté completado.'),
        findsOneWidget);
    expect((await db.collection('reviews').get()).docs, isEmpty);
  });

  testWidgets('review rejects an order owned by another student', (tester) async {
    await db.collection('orders').doc('order').set(
      order('completed', owner: 'another-student'),
    );
    await mount(tester, ratingScreen());
    await chooseRatings(tester);
    await tapText(tester, 'Enviar reseña');
    expect(find.text('No se encontró un pedido tuyo para esta reseña.'),
        findsOneWidget);
    expect((await db.collection('reviews').get()).docs, isEmpty);
  });

  testWidgets('QR screen requires a signed-in student', (tester) async {
    await mount(tester, ShowQrScreen(orderId: 'order', firestore: db,
      auth: MockFirebaseAuth(signedIn: false)));
    expect(find.text('Inicia sesión para ver tu pedido.'), findsOneWidget);
    expect(find.byType(QrImageView), findsNothing);
  });

  testWidgets('QR screen hides another students order', (tester) async {
    await db.collection('orders').doc('order').set(order('ready', owner: 'other'));
    await mount(tester, ShowQrScreen(orderId: 'order', firestore: db, auth: auth));
    expect(find.text('Pedido no disponible'), findsOneWidget);
    expect(find.byType(QrImageView), findsNothing);
  });

  for (final state in {
    'pending': 'Esperando al local',
    'preparing': 'Preparando tu pedido',
    'completed': 'Pedido entregado',
    'cancelled': 'Pedido cancelado',
  }.entries) {
    testWidgets('QR stays hidden when order is ${state.key}', (tester) async {
      await db.collection('orders').doc('order').set(order(state.key));
      await mount(tester, ShowQrScreen(orderId: 'order', firestore: db, auth: auth));
      expect(find.text(state.value), findsOneWidget);
      expect(find.byType(QrImageView), findsNothing);
      await tapText(tester, 'Volver a mis pedidos');
    });
  }

  testWidgets('ready order displays its live code and total, not caller data',
      (tester) async {
    await db.collection('orders').doc('order').set(order('ready'));
    await mount(tester, ShowQrScreen(orderId: 'order', qrData: 'forged-code',
      firestore: db, auth: auth));
    expect(find.text('Tu pedido está listo'), findsOneWidget);
    expect(find.text('SNACK-TEST-123'), findsOneWidget);
    expect(find.text('Total: \$25.00'), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('forged-code'), findsNothing);
  });

  testWidgets('cart shows total and confirms deletion before removing an item',
      (tester) async {
    await db.collection('users').doc('student').collection('cart').doc('taco')
      .set({...product(), 'productId': 'taco', 'quantity': 2, 'notes': 'Sin salsa'});
    await mount(tester, CartScreen(firestore: db, auth: auth));
    expect(find.text('Sin salsa'), findsOneWidget);
    expect(find.text('Subtotal: \$25.00'), findsOneWidget);
    expect(find.text('\$25.00'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.delete_outline_rounded));
    await tester.pumpAndSettle();
    await tapText(tester, 'Cancelar');
    expect((await db.collection('users').doc('student').collection('cart').get())
      .docs, hasLength(1));
    await tester.tap(find.byIcon(Icons.delete_outline_rounded));
    await tester.pumpAndSettle();
    await tapText(tester, 'Confirmar');
    expect(find.text('Tu carrito está vacío'), findsOneWidget);
  });

  testWidgets('cart refuses stale stock before showing checkout confirmation',
      (tester) async {
    await catalog();
    await db.collection('products').doc('taco').update({'stock': 1});
    await db.collection('users').doc('student').collection('cart').doc('taco')
      .set({...product(), 'productId': 'taco', 'quantity': 2, 'notes': ''});
    await mount(tester, CartScreen(firestore: db, auth: auth));
    await tapText(tester, 'Confirmar Pedido');
    expect(find.text('Taco no tiene disponibilidad para 2 unidades.'),
        findsOneWidget);
    expect((await db.collection('orders').get()).docs, isEmpty);
  });

  testWidgets('checkout uses current catalog price and persists the order',
      (tester) async {
    await catalog();
    await db.collection('users').doc('student').collection('cart').doc('taco')
      .set({...product(), 'price': 1.0, 'productId': 'taco',
        'quantity': 2, 'notes': 'Sin salsa'});
    await mount(tester, CartScreen(firestore: db, auth: auth));
    await tapText(tester, 'Confirmar Pedido');
    expect(find.textContaining('Los precios se actualizaron.'), findsOneWidget);
    expect(find.textContaining('Total actual: \$25.00.'), findsOneWidget);
    await tapText(tester, 'Confirmar');
    final orders = (await db.collection('orders').get()).docs;
    expect(orders, hasLength(1));
    expect(orders.single.data()['totalPrice'], 25.0);
    expect(orders.single.data()['status'], 'pending');
    expect(orders.single.data()['userId'], 'student');
    expect(find.text('Tu carrito está vacío'), findsOneWidget);
  });

  testWidgets('signed-out cart displays a session instruction', (tester) async {
    await mount(tester, CartScreen(firestore: db,
      auth: MockFirebaseAuth(signedIn: false)));
    expect(find.text('Debes iniciar sesión para ver tu carrito'), findsOneWidget);
  });

  testWidgets('product quantity respects stock and favorite writes are reversible',
      (tester) async {
    await catalog();
    await mount(tester, ProductDetailScreen(productId: 'taco',
      product: product(stock: 2), firestore: db, auth: auth));
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pump();
    expect(find.text('Añadir 2 al Carrito - \$25.00'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pump();
    expect(find.text('Añadir 2 al Carrito - \$25.00'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.remove_rounded));
    await tester.pump();
    expect(find.text('Añadir 1 al Carrito - \$12.50'), findsOneWidget);
    await tester.tap(find.byTooltip('Añadir a Favoritos'));
    await tester.pumpAndSettle();
    final favorite = db.collection('users').doc('student')
      .collection('favorites').doc('taco');
    expect((await favorite.get()).data()?['productId'], 'taco');
    await tester.tap(find.byTooltip('Quitar de Favoritos'));
    await tester.pumpAndSettle();
    expect((await favorite.get()).exists, isFalse);
  });

  testWidgets('sold out product cannot be added to cart', (tester) async {
    await mount(tester, ProductDetailScreen(productId: 'taco',
      product: product(stock: 0), firestore: db, auth: auth));
    expect(find.text('Producto Agotado'), findsOneWidget);
    final button = tester.widget<ElevatedButton>(find.ancestor(
      of: find.text('Producto Agotado'), matching: find.byType(ElevatedButton)));
    expect(button.onPressed, isNull);
  });

  testWidgets('menu filters unavailable products and opens a product detail',
      (tester) async {
    await catalog();
    await db.collection('products').doc('hidden').set({
      ...product(available: false), 'name': 'No disponible',
    });
    await mount(tester, MenuScreen(businessId: 'cafeteria',
      businessName: 'Cafetería UTSJR', firestore: db, auth: auth));
    expect(find.text('No disponible'), findsNothing);
    expect(find.text('Taco'), findsOneWidget);
    await tapText(tester, 'Taco');
    expect(find.byType(ProductDetailScreen), findsOneWidget);
  });

  testWidgets('empty menu gives a visible unavailable state', (tester) async {
    await mount(tester, MenuScreen(businessId: 'cafeteria',
      businessName: 'Cafetería UTSJR', firestore: db, auth: auth));
    expect(find.text('Menú no disponible'), findsOneWidget);
  });

  testWidgets('search debounces, filters by prefix, and clears results',
      (tester) async {
    await catalog();
    await mount(tester, SearchScreen(firestore: db, auth: auth));
    expect(find.text('Busca tus productos favoritos'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 't');
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Busca tus productos favoritos'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'tac');
    await tester.pump(const Duration(milliseconds: 550));
    await tester.pumpAndSettle();
    expect(find.text('Taco'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.clear_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Busca tus productos favoritos'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'pizza');
    await tester.pump(const Duration(milliseconds: 550));
    await tester.pumpAndSettle();
    expect(find.text('No se encontraron resultados'), findsOneWidget);
  });

  testWidgets('order tabs separate active orders, history and favorites',
      (tester) async {
    await db.collection('orders').doc('ready').set(order('ready'));
    await db.collection('orders').doc('done').set(order('completed'));
    await db.collection('orders').doc('cancelled').set(order('cancelled'));
    await db.collection('reviews').doc('done').set({
      'userId': 'student', 'orderId': 'done',
    });
    await db.collection('users').doc('student').collection('favorites')
      .doc('taco').set({...product(), 'productId': 'taco',
        'addedAt': Timestamp.now()});
    await mount(tester, ProfileOrdersScreen(firestore: db, auth: auth));
    expect(find.text('¡Listo!'), findsOneWidget);
    expect(find.text('2x Taco'), findsOneWidget);
    await tapText(tester, 'Historial');
    expect(find.text('Completado'), findsOneWidget);
    expect(find.text('Cancelado'), findsOneWidget);
    final reviewed = tester.widget<IconButton>(find.ancestor(
      of: find.byTooltip('Pedido calificado'),
      matching: find.byType(IconButton),
    ));
    expect(reviewed.onPressed, isNull);
    await tapText(tester, 'Favoritos');
    expect(find.text('Taco'), findsOneWidget);
  });

  testWidgets('empty order tabs explain how to start a first order',
      (tester) async {
    await mount(tester, ProfileOrdersScreen(firestore: db, auth: auth));
    expect(find.text('No tienes pedidos activos'), findsOneWidget);
    await tapText(tester, 'Historial');
    expect(find.text('No hay historial de pedidos'), findsOneWidget);
    await tapText(tester, 'Favoritos');
    expect(find.text('No tienes favoritos'), findsOneWidget);
  });


  testWidgets('ready active order opens its owned pickup QR', (tester) async {
    await db.collection('orders').doc('ready').set(order('ready'));
    await mount(tester, ProfileOrdersScreen(firestore: db, auth: auth));
    await tapText(tester, 'Mostrar QR para Recoger');
    expect(find.byType(ShowQrScreen), findsOneWidget);
    expect(find.text('SNACK-TEST-123'), findsOneWidget);
  });

  testWidgets('history reorders and favorites add current catalog products',
      (tester) async {
    await catalog();
    await db.collection('orders').doc('done').set(order('completed'));
    await db.collection('users').doc('student').collection('favorites')
      .doc('taco').set({...product(), 'productId': 'taco', 'notes': 'Sin salsa',
        'addedAt': Timestamp.now()});
    await mount(tester, ProfileOrdersScreen(firestore: db, auth: auth));
    await tapText(tester, 'Historial');
    await tester.tap(find.byTooltip('Volver a Pedir'));
    await tester.pumpAndSettle();
    final cart = db.collection('users').doc('student').collection('cart').doc('taco');
    expect((await cart.get()).data()?['quantity'], 2);
    expect((await cart.get()).data()?['price'], 12.5);
    await tapText(tester, 'Favoritos');
    await tester.tap(find.byTooltip('Añadir al Carrito'));
    await tester.pumpAndSettle();
    expect((await cart.get()).data()?['quantity'], 3);
    expect((await cart.get()).data()?['notes'], 'Sin salsa');
  });

  testWidgets('history opens the correct local when a review is not yet stored',
      (tester) async {
    await catalog();
    await db.collection('orders').doc('done').set(order('completed'));
    await mount(tester, ProfileOrdersScreen(firestore: db, auth: auth));
    await tapText(tester, 'Historial');
    await tester.tap(find.byTooltip('Calificar pedido'));
    await tester.pumpAndSettle();
    expect(find.byType(RateOrderScreen), findsOneWidget);
    expect(find.text('Cafetería UTSJR'), findsOneWidget);
  });

  testWidgets('orders require a session instead of exposing history', (tester) async {
    await mount(tester, ProfileOrdersScreen(firestore: db,
      auth: MockFirebaseAuth(signedIn: false)));
    expect(find.text('Inicia sesión para ver tus pedidos.'), findsOneWidget);
  });

  testWidgets('home loads live promotions and only open businesses',
      (tester) async {
    await catalog();
    await db.collection('businesses').doc('closed').set({
      'name': 'Local cerrado', 'isOpen': false,
    });
    await mount(tester, UserHomeScreen(firestore: db, auth: auth));
    expect(find.text('¡Hola, Alumno!'), findsOneWidget);
    expect(find.text('Taco'), findsOneWidget);
    expect(find.text('Cafetería UTSJR'), findsOneWidget);
    expect(find.text('Local cerrado'), findsNothing);
    await tapText(tester, 'Cafetería UTSJR');
    expect(find.byType(MenuScreen), findsOneWidget);
  });

  testWidgets('home explains empty promotions and closed businesses',
      (tester) async {
    await mount(tester, UserHomeScreen(firestore: db, auth: auth));
    expect(find.text('No hay promociones hoy'), findsOneWidget);
    expect(find.text('Todas las tiendas están cerradas'), findsOneWidget);
  });

  testWidgets('dashboard navigation and logout require explicit confirmation',
      (tester) async {
    await mount(tester, UserDashboardScreen(firestore: db, auth: auth));
    final nav = tester.widget<BottomNavigationBar>(find.byType(BottomNavigationBar));
    nav.onTap!(1);
    await tester.pumpAndSettle();
    expect(find.text('Buscar Comida'), findsOneWidget);
    await tester.tap(find.byTooltip('Cerrar Sesión'));
    await tester.pumpAndSettle();
    await tapText(tester, 'Cancelar');
    expect(auth.currentUser, isNotNull);
    await tester.tap(find.byTooltip('Cerrar Sesión'));
    await tester.pumpAndSettle();
    // The dialog action shares its label with the title.
    final action = find.widgetWithText(ElevatedButton, 'Cerrar Sesión');
    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(auth.currentUser, isNull);
  });
}
