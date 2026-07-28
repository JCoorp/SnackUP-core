class AuthValidators {
  const AuthValidators._();

  static String? fullName(String? value) {
    final normalized = value?.trim() ?? '';
    if (normalized.isEmpty) {
      return 'Por favor, ingresa tu nombre';
    }
    if (normalized.split(RegExp(r'\s+')).length < 2) {
      return 'Ingresa al menos nombre y apellido';
    }
    return null;
  }

  static String? institutionalEmail(String? value) {
    final normalized = value?.trim().toLowerCase() ?? '';
    if (normalized.isEmpty) {
      return 'Por favor, ingresa tu correo';
    }
    if (!RegExp(r'^[^@\s]+@utsjr\.edu\.mx$').hasMatch(normalized)) {
      return 'Debe ser un correo @utsjr.edu.mx';
    }
    return null;
  }

  static String? controlNumber(String? value) {
    final normalized = value?.trim() ?? '';
    if (normalized.isEmpty) {
      return 'Ingresa tu número de control';
    }
    if (!RegExp(r'^\d{8,12}$').hasMatch(normalized)) {
      return 'Usa entre 8 y 12 dígitos';
    }
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.length < 8) {
      return 'La contraseña debe tener al menos 8 caracteres';
    }
    if (!RegExp(r'[A-Za-z]').hasMatch(value) ||
        !RegExp(r'\d').hasMatch(value)) {
      return 'Incluye al menos una letra y un número';
    }
    return null;
  }

  static String? confirmPassword(String? value, String password) {
    if (value != password) {
      return 'Las contraseñas no coinciden';
    }
    return null;
  }
}
