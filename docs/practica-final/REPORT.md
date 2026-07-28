# Reporte técnico de práctica final - SnackUp

Fecha: 28 de julio de 2026
Repositorio: <https://github.com/JCoorp/SnackUP-core>
Rama de trabajo: `agent/practica-final`
Versión propuesta: 1.1.0+2
Sitio vigente: <https://snackup-8fe96.web.app>

## Objetivo

Preparar una liberación segura de SnackUp mediante Docker, Nginx, HTTPS,
pruebas de software, versionamiento semántico, rollback y revisión de
privacidad, sin modificar `main` ni los datos de Firebase de producción.

## Trabajo realizado

| Requisito | Implementación | Evidencia |
|---|---|---|
| Docker | Compilación multietapa Flutter Web y Nginx sin servidor de desarrollo | `Dockerfile` |
| Proxy inverso | Servicio `edge`, redirección HTTP y terminación TLS | `compose.yaml`, `deploy/nginx/` |
| Firewall | Procedimiento UFW para 80/443 y SSH restringido | `docs/deployment/DEPLOYMENT.md` |
| Unitarias | Validadores de registro | `test/unit/auth_validators_test.dart` |
| Caja blanca | Ramas del flujo de estados de pedido | `test/white_box/order_status_test.dart` |
| Integración | Repositorio y almacén en memoria sin Firebase real | `test/integration/order_repository_test.dart` |
| Carga | Rampa de 50 a 100 usuarios virtuales | `tests/performance/k6-smoke.js` |
| Usabilidad | Lighthouse, tres ejecuciones, meta mínima 85 | `.lighthouserc.json` |
| SemVer | Cambio compatible de 1.0.0 a 1.1.0+2 | `pubspec.yaml`, `CHANGELOG.md` |
| Rollback | Regreso al commit base sin reescribir historial | `docs/release/RELEASE_1.1.0.md` |
| Privacidad | Inventario, brechas y acciones LFPDPPP/RGPD | `docs/security/PRIVACY_REVIEW.md` |

## Seguridad aplicada

- Todo el trabajo permanece en una rama independiente.
- GitHub Actions sólo tiene permiso de lectura y no contiene pasos de despliegue.
- Las pruebas usan datos ficticios y un almacén en memoria.
- No se incluyen llaves de servicio, exportaciones de Firestore/Auth,
  certificados o variables de entorno.
- No se ejecutan pruebas de carga contra Firebase ni contra el sitio vigente.
- La inicialización duplicada de Firebase Web fue eliminada.

## Resultados

Los resultados definitivos se registrarán desde el Pull Request:

| Verificación | Criterio | Resultado |
|---|---|---|
| Formato y análisis Flutter | Sin errores | Pendiente de CI |
| Pruebas Flutter | 100 % aprobadas | Pendiente de CI |
| Compilación web | Correcta | Pendiente de CI |
| Imagen Docker | Construye sin publicar | Pendiente de CI |
| k6 | error <1 %, p95 <2 s | Pendiente de CI |
| Lighthouse rendimiento | ≥85 | Pendiente de CI |
| Lighthouse accesibilidad | ≥85 | Pendiente de CI |

Los artefactos `flutter-quality` y `lighthouse-k6` quedan disponibles durante
14 días en GitHub Actions. No se inventarán resultados antes de esa ejecución.

## Límites y acciones manuales

El repositorio puede demostrar compilación, pruebas y configuración, pero un
despliegue Docker público necesita un servidor, dominio, DNS y certificado
autorizados. No se modificó Firebase Hosting ni el proyecto Firebase.

Las reglas reales de Firestore no estaban versionadas. Deben incorporarse desde
el respaldo validado, revisarse con Emulator Suite y aprobarse antes de cualquier
despliegue. No se sustituyeron por reglas supuestas.

## Conclusión

La rama entrega una base reproducible y reversible para evaluar la práctica. La
liberación y el despliegue permanecen deliberadamente bloqueados hasta que el
PR, el CI, la seguridad de Firestore y la infraestructura externa sean
aprobados.
