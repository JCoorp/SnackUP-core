import 'package:flutter_test/flutter_test.dart';
import 'package:snackup/core/validation/auth_validators.dart';

void main() {
  group('AuthValidators', () {
    test('acepta un nombre y apellido', () {
      expect(AuthValidators.fullName('Ana López'), isNull);
    });

    test('rechaza un nombre incompleto', () {
      expect(AuthValidators.fullName('Ana'), isNotNull);
    });

    test('acepta correo institucional sin distinguir mayúsculas', () {
      expect(AuthValidators.institutionalEmail('ALUMNO@UTSJR.EDU.MX'), isNull);
    });

    test('rechaza correo externo', () {
      expect(
        AuthValidators.institutionalEmail('alumno@example.com'),
        isNotNull,
      );
    });

    test('acepta número de control de 8 a 12 dígitos', () {
      expect(AuthValidators.controlNumber('202314096'), isNull);
    });

    test('rechaza caracteres no numéricos en número de control', () {
      expect(AuthValidators.controlNumber('2023A4096'), isNotNull);
    });

    test('exige contraseña con longitud, letra y número', () {
      expect(AuthValidators.password('Snackup2026'), isNull);
      expect(AuthValidators.password('12345678'), isNotNull);
      expect(AuthValidators.password('Snackup'), isNotNull);
    });

    test('confirma contraseñas iguales', () {
      expect(
        AuthValidators.confirmPassword('Snackup2026', 'Snackup2026'),
        isNull,
      );
      expect(AuthValidators.confirmPassword('otra', 'Snackup2026'), isNotNull);
    });
  });
}
