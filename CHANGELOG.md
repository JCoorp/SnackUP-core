# Historial de cambios

El proyecto usa [versionamiento semántico](https://semver.org/lang/es/).

## [1.1.0] - Propuesta

### Añadido

- Validadores reutilizables para registro.
- Modelo de estados y repositorio de pedidos con transiciones controladas.
- Pruebas unitarias, de caja blanca y de integración.
- Imagen Docker multietapa para Flutter Web.
- Proxy inverso Nginx con HTTPS y encabezados de seguridad.
- Pruebas k6 para 50-100 usuarios virtuales y auditoría Lighthouse.
- Flujo de GitHub Actions sin acceso de escritura ni despliegue.
- Guías de despliegue, rollback, privacidad y evidencias.

### Corregido

- Inicialización duplicada de Firebase en la versión web.
- Configuración Firebase Web ausente en `firebase_options.dart`.
- Validación de datos de registro y cambios inválidos de estado de pedido.
- Accesibilidad básica y metadatos del documento web.

### Seguridad

- Se excluyen certificados, variables de entorno, coberturas y evidencias
  generadas.
- Las pruebas automatizadas no utilizan credenciales ni datos de producción.

## [1.0.0] - 2026-07-24

- Versión inicial del repositorio.
