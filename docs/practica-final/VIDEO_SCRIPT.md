# Guion de video - máximo 5 minutos

## 0:00-0:30 - Contexto

Mostrar el repositorio `JCoorp/SnackUP-core`, la rama
`agent/practica-final` y explicar que `main` y Firebase de producción no fueron
modificados.

## 0:30-1:20 - Aplicación y calidad

Mostrar los validadores, el flujo controlado de estados de pedido y las tres
carpetas de pruebas: unitarias, caja blanca e integración. Aclarar que la
integración usa memoria y no Firestore real.

## 1:20-2:10 - Docker y seguridad de red

Mostrar `Dockerfile`, `compose.yaml` y Nginx. Explicar la compilación multietapa,
los puertos 80/443, la red interna 8080, la redirección HTTPS y los certificados
fuera de Git.

## 2:10-3:10 - Pruebas no funcionales

Abrir la ejecución de GitHub Actions y mostrar:

- pruebas Flutter y compilación;
- imagen Docker;
- k6 con 50-100 usuarios y p95;
- Lighthouse, con rendimiento y accesibilidad de al menos 85.

## 3:10-4:10 - Liberación y privacidad

Mostrar `CHANGELOG.md`, la versión 1.1.0+2 y el rollback al commit `c8c6d2c`.
Resumir el inventario de datos, el aviso propuesto y la revisión pendiente de
las reglas reales de Firestore.

## 4:10-5:00 - Evidencia y cierre

Mostrar el Pull Request, sus comprobaciones y artefactos. Indicar la URL vigente
`https://snackup-8fe96.web.app` y aclarar que un despliegue Docker público
requiere servidor y dominio autorizados. Cerrar con la conclusión del reporte.
