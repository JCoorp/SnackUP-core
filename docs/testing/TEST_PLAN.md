# Plan de pruebas de la versión 1.1.0

## Alcance

El plan cubre el registro de estudiantes, el flujo de estados de un pedido,
la entrega de Flutter Web, el rendimiento del sitio y la accesibilidad de la
página inicial. Las pruebas automatizadas no utilizan datos de producción.

## Matriz

| Categoría | Objetivo | Implementación | Criterio |
|---|---|---|---|
| Unitarias | Validar nombre, correo institucional, número de control y contraseña | `test/unit/auth_validators_test.dart` | 100 % de casos aprobados |
| Caja blanca | Recorrer decisiones y estados terminales del pedido | `test/white_box/order_status_test.dart` | Todas las ramas previstas |
| Integración | Integrar repositorio, reglas de transición y almacenamiento | `test/integration/order_repository_test.dart` | Escritura válida y rechazo sin mutación |
| Rendimiento | Simular 50 y 100 usuarios | `tests/performance/k6-smoke.js` | errores <1 %, p95 <2 s |
| Usabilidad/accesibilidad | Auditar la compilación web con Lighthouse | `.lighthouserc.json` | rendimiento y accesibilidad ≥85 |

## Datos de prueba

Se usan nombres, correos y pedidos ficticios. La integración usa una
implementación en memoria de `OrderDataStore`. No se carga la llave de servicio,
no se conecta a `snackup-8fe96` y no se altera Firestore.

## Automatización

El flujo `.github/workflows/practica-final.yml` ejecuta:

1. formato y análisis estático;
2. pruebas Flutter con cobertura;
3. compilación web;
4. construcción de la imagen Docker;
5. Lighthouse;
6. k6 con 50-100 usuarios virtuales;
7. publicación de evidencias como artefacto de GitHub Actions.

## Evidencia esperada

- `coverage/lcov.info`
- `artifacts/lighthouse/`
- `artifacts/k6-summary.json`
- registro de la ejecución de GitHub Actions

Los resultados definitivos deben copiarse al reporte final después de que el
flujo de la rama termine correctamente.
