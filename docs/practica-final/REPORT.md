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
| Rendimiento inicial | Paneles autenticados cargados bajo demanda | `lib/features/auth/auth_gate.dart` |
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

Ejecución verificada:
[GitHub Actions 30403096066](https://github.com/JCoorp/SnackUP-core/actions/runs/30403096066).
Commit funcional evaluado: `e8d7a01a9ea062e4a673e97469a86a194ec76d1d`.

| Verificación | Criterio | Resultado |
|---|---|---|
| Formato y análisis Flutter | Sin errores | Aprobado |
| Pruebas Flutter | 100 % aprobadas | Aprobado con cobertura |
| Compilación web | Correcta | Aprobada |
| Imagen Docker | Construye sin publicar | Aprobada |
| k6 | error <1 %, p95 <2 s | 7,031 solicitudes, 0 % de error, p95 0.744 ms, 100 VU |
| Lighthouse rendimiento | ≥85 | CI aprobado; ejecuciones 69, 86 y 84 |
| Lighthouse accesibilidad | ≥85 | 93 en las tres ejecuciones |

Lighthouse obtuvo además 81 en buenas prácticas y 92 en SEO. Buenas prácticas
permanece como advertencia no bloqueante; se recomienda continuar reduciendo
JavaScript inicial y corregir los avisos heredados antes de una publicación.

La primera medición de rendimiento fue una ejecución fría con mayor variación.
Las dos siguientes alcanzaron 86 y 84, y la política de Lighthouse CI aprobó el
objetivo configurado sin reducir el umbral de 85.

Los tres trabajos finalizaron en verde. Los artefactos `flutter-quality`
(`8705501500`) y `lighthouse-k6` (`8705571142`) conservan la compilación,
cobertura, tres reportes Lighthouse y el resumen k6 hasta el 11 de agosto de
2026.

## Límites y acciones manuales

El repositorio puede demostrar compilación, pruebas y configuración, pero un
despliegue Docker público necesita un servidor, dominio, DNS y certificado
autorizados. No se modificó Firebase Hosting ni el proyecto Firebase.

Las reglas reales de Firestore no estaban versionadas. Deben incorporarse desde
el respaldo validado, revisarse con Emulator Suite y aprobarse antes de cualquier
despliegue. No se sustituyeron por reglas supuestas.

## Conclusión

La rama entrega una base reproducible y reversible, con CI aprobado y evidencias
reales. La liberación y el despliegue permanecen deliberadamente bloqueados
hasta que el PR, la seguridad de Firestore y la infraestructura externa sean
aprobados. El PR continúa en borrador y no se modificó `main`.
