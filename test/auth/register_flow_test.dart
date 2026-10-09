import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snackup/features/auth/auth_repository.dart';
import 'package:snackup/features/auth/register_screen.dart';

import 'auth_flow_test.dart' show FakeAuthRepository;

class RegistrationRepository extends FakeAuthRepository {
  int registrationCalls = 0;
  String? registrationEmail;
  String? registrationPassword;
  StudentProfileInput? registrationProfile;
  Object? registrationError;
  Completer<void>? registrationRequest;

  @override
  Future<void> registerStudent(
    String email,
    String password,
    StudentProfileInput input,
  ) async {
    registrationCalls++;
    registrationEmail = email;
    registrationPassword = password;
    registrationProfile = input;
    input.validate();
    await registrationRequest?.future;
    final error = registrationError;
    if (error != null) throw error;
  }
}

Finder registrationField(int index) => find.byType(TextFormField).at(index);
Finder get createAccount => find.widgetWithText(ElevatedButton, 'Crear Mi Cuenta');

Future<void> openRegistration(
  WidgetTester tester,
  RegistrationRepository repository,
) async {
  tester.view.physicalSize = const Size(1000, 2200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(repository.close);
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => RegisterScreen(repository: repository),
              ),
            ),
            child: const Text('Entrar al registro'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Entrar al registro'));
  await tester.pumpAndSettle();
}

Future<void> fillRegistration(
  WidgetTester tester, {
  String name = 'Alumno Uno',
  String email = 'alumno@utsjr.edu.mx',
  String control = '202314096',
  String password = 'clave segura ',
  String? confirmation,
}) async {
  final values = [name, email, control, password, confirmation ?? password];
  for (var index = 0; index < values.length; index++) {
    await tester.ensureVisible(registrationField(index));
    await tester.enterText(registrationField(index), values[index]);
  }
  await tester.pump();
}

Future<void> acceptRegistrationTerms(WidgetTester tester) async {
  await tester.ensureVisible(find.byType(Checkbox));
  await tester.tap(find.byType(Checkbox));
  await tester.pump();
}

Future<void> submitRegistration(WidgetTester tester) async {
  await tester.ensureVisible(createAccount);
  await tester.tap(createAccount);
  await tester.pump();
}

void main() {
  testWidgets('creating an account requires explicit privacy consent', (
    tester,
  ) async {
    final repository = RegistrationRepository();
    await openRegistration(tester, repository);
    await fillRegistration(tester);
    expect(tester.widget<ElevatedButton>(createAccount).onPressed, isNull);
    expect(repository.registrationCalls, 0);

    await acceptRegistrationTerms(tester);
    expect(tester.widget<ElevatedButton>(createAccount).onPressed, isNotNull);
    await acceptRegistrationTerms(tester);
    expect(tester.widget<ElevatedButton>(createAccount).onPressed, isNull);
    expect(repository.registrationCalls, 0);
  });

  testWidgets('empty identity fields never reach the repository', (tester) async {
    final repository = RegistrationRepository();
    await openRegistration(tester, repository);
    await acceptRegistrationTerms(tester);
    await submitRegistration(tester);
    expect(find.text('Por favor, ingresa tu nombre'), findsOneWidget);
    expect(find.text('Por favor, ingresa tu correo'), findsOneWidget);
    expect(find.text('Ingresa tu número de control'), findsOneWidget);
    expect(
      find.text('La contraseña debe tener al menos 6 caracteres'),
      findsOneWidget,
    );
    expect(repository.registrationCalls, 0);
  });

  testWidgets('invalid student identity and mismatched passwords are rejected', (
    tester,
  ) async {
    final repository = RegistrationRepository();
    await openRegistration(tester, repository);
    await fillRegistration(
      tester,
      name: 'Alumno',
      email: 'alumno@example.com',
      control: 'ABC12345',
      password: '12345',
      confirmation: 'otra clave',
    );
    await acceptRegistrationTerms(tester);
    await submitRegistration(tester);
    expect(find.text('Ingresa al menos nombre y apellido'), findsOneWidget);
    expect(find.text('Debe ser un correo @utsjr.edu.mx'), findsOneWidget);
    expect(
      find.text('Usa entre 8 y 20 dígitos para el número de control'),
      findsOneWidget,
    );
    expect(
      find.text('La contraseña debe tener al menos 6 caracteres'),
      findsOneWidget,
    );
    expect(find.text('Las contraseñas no coinciden'), findsOneWidget);
    expect(repository.registrationCalls, 0);
  });

  testWidgets('oversized names and control numbers block registration', (
    tester,
  ) async {
    final repository = RegistrationRepository();
    await openRegistration(tester, repository);
    await fillRegistration(
      tester,
      name: 'Alumno ${List.filled(121, 'a').join()}',
      control: '123456789012345678901',
    );
    await acceptRegistrationTerms(tester);
    await submitRegistration(tester);
    expect(find.text('Ingresa al menos nombre y apellido'), findsOneWidget);
    expect(
      find.text('Usa entre 8 y 20 dígitos para el número de control'),
      findsOneWidget,
    );
    expect(repository.registrationCalls, 0);
  });

  testWidgets('successful signup submits the student profile and returns home', (
    tester,
  ) async {
    final repository = RegistrationRepository();
    await openRegistration(tester, repository);
    await fillRegistration(
      tester,
      name: '  Alumno Uno  ',
      email: ' Alumno@UTSJR.EDU.MX ',
      control: ' 202314096 ',
    );
    await acceptRegistrationTerms(tester);
    await submitRegistration(tester);
    await tester.pumpAndSettle();

    expect(repository.registrationCalls, 1);
    expect(repository.registrationEmail, ' Alumno@UTSJR.EDU.MX ');
    expect(repository.registrationPassword, 'clave segura ');
    expect(repository.registrationProfile!.name, '  Alumno Uno  ');
    expect(repository.registrationProfile!.controlNumber, ' 202314096 ');
    expect(repository.registrationProfile!.acceptedTerms, isTrue);
    expect(find.byType(RegisterScreen), findsNothing);
    expect(find.text('Entrar al registro'), findsOneWidget);
  });

  testWidgets('pending signup shows progress and prevents duplicate submissions', (
    tester,
  ) async {
    final repository = RegistrationRepository()
      ..registrationRequest = Completer<void>();
    await openRegistration(tester, repository);
    await fillRegistration(tester);
    await acceptRegistrationTerms(tester);
    await submitRegistration(tester);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(createAccount, findsNothing);
    expect(repository.registrationCalls, 1);
    await tester.pump(const Duration(seconds: 1));
    expect(repository.registrationCalls, 1);

    repository.registrationRequest!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Entrar al registro'), findsOneWidget);
    expect(repository.registrationCalls, 1);
  });

  testWidgets('signup failure preserves the form and supports a successful retry', (
    tester,
  ) async {
    final repository = RegistrationRepository()
      ..registrationError = const AuthActionException(
        'Tu cuenta existe, reintenta para completar el perfil.',
      );
    await openRegistration(tester, repository);
    await fillRegistration(tester);
    await acceptRegistrationTerms(tester);
    await submitRegistration(tester);
    await tester.pumpAndSettle();
    expect(
      find.text('Tu cuenta existe, reintenta para completar el perfil.'),
      findsOneWidget,
    );
    expect(repository.registrationCalls, 1);
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
    expect(find.text('alumno@utsjr.edu.mx'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    repository.registrationError = null;
    await submitRegistration(tester);
    await tester.pumpAndSettle();
    expect(repository.registrationCalls, 2);
    expect(repository.registrationProfile!.name, 'Alumno Uno');
    expect(find.text('Entrar al registro'), findsOneWidget);
  });

  testWidgets('Firebase duplicate-account errors show recovery guidance', (
    tester,
  ) async {
    final repository = RegistrationRepository()
      ..registrationError = FirebaseAuthException(code: 'email-already-in-use');
    await openRegistration(tester, repository);
    await fillRegistration(tester);
    await acceptRegistrationTerms(tester);
    await submitRegistration(tester);
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Este correo ya tiene una cuenta. Inicia sesión o recupera tu contraseña.',
      ),
      findsOneWidget,
    );
    expect(repository.registrationCalls, 1);
    expect(tester.widget<ElevatedButton>(createAccount).onPressed, isNotNull);
  });

  testWidgets('password and confirmation visibility can be changed independently', (
    tester,
  ) async {
    final repository = RegistrationRepository();
    await openRegistration(tester, repository);
    Finder editable(int index) => find.descendant(
      of: registrationField(index),
      matching: find.byType(EditableText),
    );
    Finder visibilityButton(int index) => find.descendant(
      of: registrationField(index),
      matching: find.byType(IconButton),
    );
    expect(tester.widget<EditableText>(editable(3)).obscureText, isTrue);
    expect(tester.widget<EditableText>(editable(4)).obscureText, isTrue);
    await tester.ensureVisible(visibilityButton(3));
    await tester.tap(visibilityButton(3));
    await tester.pump();
    expect(tester.widget<EditableText>(editable(3)).obscureText, isFalse);
    expect(tester.widget<EditableText>(editable(4)).obscureText, isTrue);
    await tester.ensureVisible(visibilityButton(4));
    await tester.tap(visibilityButton(4));
    await tester.pump();
    expect(tester.widget<EditableText>(editable(4)).obscureText, isFalse);
    await tester.tap(visibilityButton(3));
    await tester.tap(visibilityButton(4));
    await tester.pump();
    expect(tester.widget<EditableText>(editable(3)).obscureText, isTrue);
    expect(tester.widget<EditableText>(editable(4)).obscureText, isTrue);
    expect(repository.registrationCalls, 0);
  });

  testWidgets('both privacy documents can be read without implicitly consenting', (
    tester,
  ) async {
    final repository = RegistrationRepository();
    await openRegistration(tester, repository);
    await tester.ensureVisible(find.text('Protección de Datos'));
    await tester.tap(find.text('Protección de Datos'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Protección de Datos Personales'), findsOneWidget);
    expect(find.textContaining('No son reseñas anónimas.'), findsOneWidget);
    await tester.tap(find.text('Cerrar'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Política de Privacidad'));
    await tester.tap(find.text('Política de Privacidad'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.textContaining('Soporte.snackup@gmail.com'), findsOneWidget);
    await tester.tap(find.text('Cerrar'));
    await tester.pumpAndSettle();
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);
    expect(tester.widget<ElevatedButton>(createAccount).onPressed, isNull);
    expect(repository.registrationCalls, 0);
  });

  for (final requestFails in [false, true]) {
    testWidgets(
      'leaving signup before ${requestFails ? 'failure' : 'success'} never updates disposed state',
      (tester) async {
        final repository = RegistrationRepository()
          ..registrationRequest = Completer<void>()
          ..registrationError = requestFails
              ? const AuthActionException('La solicitud no se pudo completar.')
              : null;
        await openRegistration(tester, repository);
        await fillRegistration(tester);
        await acceptRegistrationTerms(tester);
        await submitRegistration(tester);
        // Replacing only MaterialApp.home preserves its Navigator and pushed
        // signup route. Remove the whole tree to exercise actual disposal.
        await tester.pumpWidget(const SizedBox.shrink());
        expect(find.byType(RegisterScreen), findsNothing);
        await tester.pumpWidget(const MaterialApp(home: Text('Otra pantalla')));
        expect(find.text('Otra pantalla'), findsOneWidget);
        repository.registrationRequest!.complete();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Otra pantalla'), findsOneWidget);
      },
    );
  }
}
