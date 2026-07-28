# SnackUp

Aplicación Flutter para consultar menús, realizar pedidos y administrar la
operación de la cafetería de la UTSJR.

[![Flutter](https://img.shields.io/badge/Flutter-3.32.8-02569B?logo=flutter)](https://flutter.dev)
[![Firebase](https://img.shields.io/badge/Firebase-snackup--8fe96-FFCA28?logo=firebase&logoColor=black)](https://firebase.google.com)
[![Version](https://img.shields.io/badge/version-1.1.0--rc-orange)](CHANGELOG.md)

## Entorno

- Flutter 3.32.8 y Dart 3.8 o posterior.
- Firebase Authentication y Cloud Firestore.
- Proyecto Firebase: `snackup-8fe96`.
- Sitio vigente: <https://snackup-8fe96.web.app>.

La configuración web de Firebase es configuración pública del cliente. Las
llaves de cuenta de servicio, certificados TLS y archivos `.env` nunca deben
guardarse en Git.

## Ejecución local

```bash
flutter pub get
flutter run -d chrome
```

No es necesario ejecutar `flutterfire configure` para compilar la configuración
actual. Si se regenera, debe seleccionarse únicamente `snackup-8fe96` y revisarse
el cambio antes de confirmarlo.

## Calidad

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test --coverage
flutter build web --release
```

La práctica final añade pruebas unitarias, de caja blanca, de integración,
Lighthouse, k6 con 50-100 usuarios virtuales y una compilación Docker sin
publicación. Consulte [el plan de pruebas](docs/testing/TEST_PLAN.md).

## Docker

Validación local de la imagen, sin TLS:

```bash
docker compose -f compose.yaml -f compose.local.yaml up --build web
curl --fail http://localhost:8080/healthz
```

El despliegue con Nginx, HTTPS y firewall se describe en
[DEPLOYMENT.md](docs/deployment/DEPLOYMENT.md). Esos pasos requieren un servidor,
dominio y certificado autorizados.

## Flujo Git

`main` no recibe cambios directos. Cada mejora se implementa en una rama y se
integra mediante Pull Request revisado. Los prefijos recomendados son `feat/`,
`fix/`, `docs/` y `agent/`.

## Documentación

- [Plan de pruebas](docs/testing/TEST_PLAN.md)
- [Despliegue y rollback](docs/deployment/DEPLOYMENT.md)
- [Revisión de privacidad](docs/security/PRIVACY_REVIEW.md)
- [Aviso de privacidad propuesto](docs/security/PRIVACY_NOTICE.md)
- [Liberación 1.1.0](docs/release/RELEASE_1.1.0.md)
- [Reporte de práctica final](docs/practica-final/REPORT.md)
- [PDF final verificado de la práctica](output/pdf/Practica_Final_SnackUp_1.1.0.pdf)

## Estructura principal

```text
lib/
├── core/       # Reglas de negocio y validación
├── features/   # Pantallas agrupadas por función
└── theme/      # Colores y tipografía
test/           # Pruebas Flutter
tests/          # Pruebas externas, como k6
deploy/         # Configuración de Nginx
docs/           # Operación, seguridad y evidencias
```
