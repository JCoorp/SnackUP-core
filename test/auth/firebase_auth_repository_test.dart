import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snackup/features/auth/auth_repository.dart';

// Firebase SDK doubles keep these tests offline while exercising the actual
// repository, including its Firestore transactions and account retry behavior.
class RecordingAuth extends MockFirebaseAuth {
  RecordingAuth({super.signedIn = false, super.mockUser});

  String? signInEmail, signInPassword, createdEmail, createdPassword, resetEmail;
  int creations = 0;
  FirebaseAuthException? resetFailure;
  final tokenEvents = StreamController<User?>.broadcast();

  @override
  Stream<User?> idTokenChanges() => tokenEvents.stream;

  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    signInEmail = email;
    signInPassword = password;
    final credential = await super.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    tokenEvents.add(credential.user);
    return credential;
  }

  @override
  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    creations++;
    createdEmail = email;
    createdPassword = password;
    return super.createUserWithEmailAndPassword(email: email, password: password);
  }

  @override
  Future<void> sendPasswordResetEmail({
    required String email,
    ActionCodeSettings? actionCodeSettings,
  }) async {
    resetEmail = email;
    if (resetFailure != null) throw resetFailure!;
    await super.sendPasswordResetEmail(
      email: email,
      actionCodeSettings: actionCodeSettings,
    );
  }

  @override
  Future<void> signOut() async {
    await super.signOut();
    tokenEvents.add(null);
  }
}

class FailingDisplayNameUser extends MockUser {
  FailingDisplayNameUser()
    : super(uid: 'student-1', email: 'alumno@utsjr.edu.mx');

  @override
  Future<void> updateDisplayName(String? displayName) async {
    throw FirebaseAuthException(code: 'network-request-failed');
  }
}

class RetryableFirestore extends FakeFirebaseFirestore {
  bool unavailable = true;

  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> transactionHandler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) async {
    if (unavailable) {
      throw FirebaseException(plugin: 'cloud_firestore', code: 'unavailable');
    }
    return super.runTransaction(
      transactionHandler,
      timeout: timeout,
      maxAttempts: maxAttempts,
    );
  }
}

const validProfile = StudentProfileInput(
  name: '  Alumno Uno  ',
  controlNumber: ' 202314096 ',
  acceptedTerms: true,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late RecordingAuth auth;
  late FakeFirebaseFirestore db;
  late FirebaseSnackAuthRepository repository;

  void configure({MockUser? user, bool signedIn = false}) {
    auth = RecordingAuth(mockUser: user, signedIn: signedIn);
    db = FakeFirebaseFirestore();
    repository = FirebaseSnackAuthRepository(auth: auth, firestore: db);
    addTearDown(auth.tokenEvents.close);
  }

  test('account conversion keeps identity and handles a signed-out account', () {
    configure(
      user: MockUser(
        uid: 'student-1',
        email: 'alumno@utsjr.edu.mx',
        displayName: 'Alumno Uno',
      ),
      signedIn: true,
    );
    expect(repository.currentAccount?.uid, 'student-1');
    expect(repository.currentAccount?.email, 'alumno@utsjr.edu.mx');
    expect(repository.currentAccount?.displayName, 'Alumno Uno');
  });

  test('anonymous SDK fields map to empty strings, never null', () {
    configure(user: MockUser(uid: 'anonymous', isAnonymous: true), signedIn: true);
    expect(repository.currentAccount?.email, '');
    expect(repository.currentAccount?.displayName, '');
  });

  test('sign-in normalizes email, preserves password and streams sign-out', () async {
    configure(user: MockUser(uid: 'student-1', email: 'alumno@utsjr.edu.mx'));
    expect(repository.currentAccount, isNull);
    final events = <SnackAccount?>[];
    final subscription = repository.watchAccount().listen(events.add);
    addTearDown(subscription.cancel);
    await repository.signIn('  Alumno@UTSJR.EDU.MX  ', '  secret password  ');
    await Future<void>.delayed(Duration.zero);
    expect(auth.signInEmail, 'alumno@utsjr.edu.mx');
    expect(auth.signInPassword, '  secret password  ');
    expect(events.single?.uid, 'student-1');
    await repository.signOut();
    await Future<void>.delayed(Duration.zero);
    expect(repository.currentAccount, isNull);
    expect(events.length, 2);
    expect(events.last, isNull);
  });

  test('claims come from the current Firebase token', () async {
    configure(
      user: MockUser(
        uid: 'student-1',
        email: 'alumno@utsjr.edu.mx',
        customClaim: {'admin': true, 'team': 'cafeteria'},
      ),
      signedIn: true,
    );
    expect(await repository.loadClaims('student-1'), {
      'admin': true,
      'team': 'cafeteria',
    });
  });

  test('claims fail closed when uid belongs to another session', () async {
    configure(user: MockUser(uid: 'student-1'), signedIn: true);
    await expectLater(
      repository.loadClaims('another-user'),
      throwsA(isA<AuthActionException>()),
    );
  });

  test('claims require a signed-in user', () async {
    configure();
    await expectLater(
      repository.loadClaims('student-1'),
      throwsA(isA<AuthActionException>()),
    );
  });

  test('profile stream distinguishes absent and persisted profiles', () async {
    configure();
    expect(await repository.watchProfile('student-1').first, isNull);
    await db.collection('users').doc('student-1').set({
      'role': 'user',
      'displayName': 'Alumno Uno',
    });
    expect(await repository.watchProfile('student-1').first, {
      'role': 'user',
      'displayName': 'Alumno Uno',
    });
  });

  test('business ownership requires a matching owner, not another business', () async {
    configure();
    await db.collection('businesses').doc('other').set({'ownerId': 'someone-else'});
    expect(await repository.ownsBusiness('student-1'), false);
    await db.collection('businesses').doc('ours').set({'ownerId': 'student-1'});
    expect(await repository.ownsBusiness('student-1'), true);
  });

  test('password reset normalizes email before handing it to Firebase', () async {
    configure();
    await repository.sendPasswordReset('  Alumno@UTSJR.EDU.MX  ');
    expect(auth.resetEmail, 'alumno@utsjr.edu.mx');
  });

  test('password reset rejects invalid input before contacting Firebase', () async {
    configure();
    await expectLater(
      repository.sendPasswordReset('invalid email'),
      throwsA(isA<AuthActionException>()),
    );
    expect(auth.resetEmail, isNull);
  });

  test('password reset hides account existence but preserves network errors', () async {
    configure();
    auth.resetFailure = FirebaseAuthException(code: 'user-not-found');
    await repository.sendPasswordReset('unknown@utsjr.edu.mx');
    auth.resetFailure = FirebaseAuthException(code: 'network-request-failed');
    await expectLater(
      repository.sendPasswordReset('unknown@utsjr.edu.mx'),
      throwsA(isA<FirebaseAuthException>().having(
        (error) => error.code,
        'code',
        'network-request-failed',
      )),
    );
  });

  test('registration creates one normalized account and a student-only profile', () async {
    configure(user: MockUser(uid: 'student-1', email: 'alumno@utsjr.edu.mx'));
    await repository.registerStudent('  Alumno@UTSJR.EDU.MX  ', ' secret ', validProfile);
    expect(auth.creations, 1);
    expect(auth.createdEmail, 'alumno@utsjr.edu.mx');
    expect(auth.createdPassword, ' secret ');
    final uid = auth.currentUser!.uid;
    final profile = (await db.collection('users').doc(uid).get()).data()!;
    expect(profile['role'], 'user');
    expect(profile['displayName'], 'Alumno Uno');
    expect(profile['numeroDeControl'], '202314096');
    expect(profile['email'], 'alumno@utsjr.edu.mx');
    expect(profile['privacyVersion'], '2');
    expect(profile['createdAt'], isA<Timestamp>());
    expect(profile['privacyAcceptedAt'], isA<Timestamp>());
    expect(profile.containsKey('admin'), false);
    expect(auth.currentUser?.displayName, 'Alumno Uno');
  });

  test('registration rejects external email and short password before account creation', () async {
    configure();
    await expectLater(
      repository.registerStudent('user@example.com', 'secret', validProfile),
      throwsA(isA<AuthActionException>()),
    );
    await expectLater(
      repository.registerStudent('alumno@utsjr.edu.mx', 'short', validProfile),
      throwsA(isA<AuthActionException>()),
    );
    expect(auth.creations, 0);
  });

  test('registration cannot replace an unrelated authenticated account', () async {
    configure(user: MockUser(uid: 'other', email: 'otro@utsjr.edu.mx'), signedIn: true);
    await expectLater(
      repository.registerStudent('alumno@utsjr.edu.mx', 'secret', validProfile),
      throwsA(isA<AuthActionException>()),
    );
    expect(auth.currentUser?.uid, 'other');
    expect(auth.creations, 0);
    expect((await db.collection('users').get()).docs, isEmpty);
  });

  test('registration retry completes the same account after a Firestore outage', () async {
    configure(user: MockUser(uid: 'student-1', email: 'alumno@utsjr.edu.mx'));
    final retryDb = RetryableFirestore();
    repository = FirebaseSnackAuthRepository(auth: auth, firestore: retryDb);
    await expectLater(
      repository.registerStudent('alumno@utsjr.edu.mx', 'secret', validProfile),
      throwsA(isA<AuthActionException>().having(
        (error) => error.message,
        'message',
        contains('Tu cuenta ya existe'),
      )),
    );
    final registeredUid = auth.currentUser!.uid;
    expect(auth.creations, 1);
    retryDb.unavailable = false;
    await repository.registerStudent('alumno@utsjr.edu.mx', 'secret', validProfile);
    expect(auth.creations, 1);
    expect(auth.currentUser?.uid, registeredUid);
    expect((await retryDb.collection('users').doc(registeredUid).get()).data()?['role'], 'user');
  });

  test('profile completion requires authentication and an institutional account', () async {
    configure();
    await expectLater(repository.completeStudentProfile(validProfile), throwsA(isA<AuthActionException>()));
    configure(user: MockUser(uid: 'business-1', email: 'business@example.com'), signedIn: true);
    await expectLater(repository.completeStudentProfile(validProfile), throwsA(isA<AuthActionException>()));
    expect((await db.collection('users').get()).docs, isEmpty);
  });

  test('profile completion preserves all existing student fields and authoritative name', () async {
    configure(user: MockUser(uid: 'student-1', email: 'alumno@utsjr.edu.mx'), signedIn: true);
    final previous = {
      'role': 'user',
      'displayName': 'Nombre Guardado',
      'numeroDeControl': '202300001',
      'customField': 'keep',
    };
    await db.collection('users').doc('student-1').set(previous);
    await repository.completeStudentProfile(validProfile);
    expect((await db.collection('users').doc('student-1').get()).data(), previous);
    expect(auth.currentUser?.displayName, 'Nombre Guardado');
    expect(auth.creations, 0);
  });

  test('profile completion cannot convert an existing business or admin profile', () async {
    configure(user: MockUser(uid: 'student-1', email: 'alumno@utsjr.edu.mx'), signedIn: true);
    for (final role in ['business', 'admin']) {
      await db.collection('users').doc('student-1').set({'role': role});
      await expectLater(
        repository.registerStudent('alumno@utsjr.edu.mx', 'secret', validProfile),
        throwsA(isA<AuthActionException>().having(
          (error) => error.message,
          'message',
          contains('revisión de administración'),
        )),
      );
      expect((await db.collection('users').doc('student-1').get()).data()?['role'], role);
    }
  });

  test('a missing saved display name does not erase Firebase display name', () async {
    configure(user: MockUser(uid: 'student-1', email: 'alumno@utsjr.edu.mx', displayName: 'Keep'), signedIn: true);
    await db.collection('users').doc('student-1').set({'role': 'user', 'displayName': 17});
    await repository.completeStudentProfile(validProfile);
    expect(auth.currentUser?.displayName, 'Keep');
  });

  test('a cosmetic Firebase display-name failure does not discard the committed profile', () async {
    configure(user: FailingDisplayNameUser(), signedIn: true);
    await repository.completeStudentProfile(validProfile);
    expect((await db.collection('users').doc('student-1').get()).data()?['displayName'], 'Alumno Uno');
    expect(auth.currentUser?.uid, 'student-1');
  });

  test('profile validation rejects incomplete identity, excessive names and invalid control numbers', () {
    for (final input in [
      const StudentProfileInput(name: 'Alumno', controlNumber: '202314096', acceptedTerms: true),
      StudentProfileInput(name: '${List.filled(121, 'a').join()} Apellido', controlNumber: '202314096', acceptedTerms: true),
      const StudentProfileInput(name: 'Alumno Uno', controlNumber: '1234', acceptedTerms: true),
      const StudentProfileInput(name: 'Alumno Uno', controlNumber: '2023abc96', acceptedTerms: true),
      const StudentProfileInput(name: 'Alumno Uno', controlNumber: '202314096', acceptedTerms: false),
    ]) {
      expect(input.validate, throwsA(isA<AuthActionException>()));
    }
  });

  test('authentication errors expose useful messages without provider internals', () {
    const expected = {
      'user-not-found': 'Correo o contraseña incorrectos.',
      'wrong-password': 'Correo o contraseña incorrectos.',
      'invalid-credential': 'Correo o contraseña incorrectos.',
      'invalid-email': 'Escribe un correo válido.',
      'email-already-in-use': 'Este correo ya tiene una cuenta. Inicia sesión o recupera tu contraseña.',
      'weak-password': 'La contraseña debe tener al menos 6 caracteres.',
      'network-request-failed': 'Sin conexión. Revisa tu red y vuelve a intentar.',
      'too-many-requests': 'Hubo demasiados intentos. Espera unos minutos y vuelve a intentar.',
      'user-disabled': 'La cuenta está deshabilitada. Contacta a administración.',
      'unknown-code': 'No se pudo completar la solicitud. Vuelve a intentar.',
    };
    for (final entry in expected.entries) {
      expect(authErrorMessage(FirebaseAuthException(code: entry.key, message: 'private provider error')), entry.value);
    }
    expect(authErrorMessage(const AuthActionException('Specific action')), 'Specific action');
    expect(authErrorMessage(StateError('private details')), 'No se pudo completar la solicitud. Revisa tu conexión y vuelve a intentar.');
  });
}
