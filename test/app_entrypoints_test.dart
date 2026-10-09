import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snackup/features/auth/auth_gate.dart';
import 'package:snackup/features/auth/login_screen.dart';
import 'package:snackup/main.dart';
import 'package:snackup/main_admin_demo.dart' as admin_demo;
import 'auth/auth_flow_test.dart' show FakeAuthRepository;

void main() {
  testWidgets('la aplicación integrada usa su tema y dirige al acceso sin sesión',
      (tester) async {
    final repository = FakeAuthRepository();
    addTearDown(repository.close);
    await tester.pumpWidget(SnackUpApp(authRepository: repository));
    await tester.pumpAndSettle();
    expect(find.byType(AuthWrapper), findsOneWidget);
    expect(find.byType(LoginScreen), findsOneWidget);
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp).first);
    expect(app.title, 'SnackUp UTSJR');
    expect(app.debugShowCheckedModeBanner, isFalse);
    expect(app.theme!.useMaterial3, isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('la entrada de demostración identifica explícitamente sus datos',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    admin_demo.main();
    await tester.pumpAndSettle();
    expect(find.text('DEMO · DATOS SIMULADOS'), findsOneWidget);
    expect(find.text('Cafetería Central'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
