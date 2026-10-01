import 'package:flutter_test/flutter_test.dart';
import 'package:snackup/utils/email_validator.dart';

void main() {
  group('Email Validator', () {
    test('acepta un correo electrónico válido', () {
      expect(isValidEmail('usuario@snackup.com'), isTrue);
    });

    test('rechaza un correo sin arroba', () {
      expect(isValidEmail('usuariosnackup.com'), isFalse);
    });

    test('rechaza un correo vacío', () {
      expect(isValidEmail(''), isFalse);
    });

    test('rechaza un correo sin dominio válido', () {
      expect(isValidEmail('usuario@snackup'), isFalse);
    });
  });
}
