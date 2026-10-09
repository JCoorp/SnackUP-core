# SnackUP · CI con SonarQube y notificaciones

La segunda parte de la actividad pide **el enlace del repositorio y un video corto** que muestre los pasos del pipeline, el análisis SonarQube y el aviso automático cuando falla.

El repositorio de esta entrega es [JCoorp/SnackUP-core](https://github.com/JCoorp/SnackUP-core), en la rama [feature/ci-sonar-notifications](https://github.com/JCoorp/SnackUP-core/tree/feature/ci-sonar-notifications). Los cambios se revisan mediante un PR hacia `main`; preparar la evidencia no requiere integrar la rama.

**Estado verificado:** [la ejecución aprobada 37871800187](https://github.com/JCoorp/SnackUP-core/actions/runs/37871800187) pasó las **188 pruebas Flutter**, la compilación Web y el análisis SonarQube. Su Quality Gate devolvió **OK**, con **86.5% de cobertura del código nuevo** frente al 80% requerido, duplicación de 1.4%, calificaciones A en seguridad, fiabilidad y mantenibilidad, y hotspots revisados al 100%. El artefacto `snackup-integrated-web` quedó disponible.

[La ejecución real fallida 37869730221, intento 2](https://github.com/JCoorp/SnackUP-core/actions/runs/37869730221) había aprobado 59 pruebas Flutter y la compilación. SonarQube rechazó su Gate por cobertura nueva de 45.0% frente al 80% requerido: se bloqueó el artefacto y **Discord confirmó el mensaje con HTTP 200 e ID público**. Este fallo real y el nuevo CI aprobado son las fuentes del video. Los secretos ya están verificados y el marcador de fallo controlado permanece desactivado.

[Las **52 pruebas de implementación** aprobaron en GitHub Actions](https://github.com/JCoorp/SnackUP-core/actions/runs/37872594372): notificador, consulta SonarQube, procedencia de evidencia y grabador. [El video de 80 segundos ya fue generado y verificado](https://github.com/JCoorp/SnackUP-core/actions/runs/37872594393). Muestra el fallo real y su aviso, y termina con el CI aprobado. `ESTADO_VERIFICADO.json` y `VIDEO_VERIFICADO.json` conservan los enlaces, IDs y hashes de los resultados observados.

## Pipeline y alcance de la actividad

El proyecto Flutter está en la **raíz del repositorio**: `pubspec.yaml`, `lib/`, `test/`, `sonar-project.properties` y `coverage/lcov.info`. Los comandos no se ejecutan desde `app/`.

| Etapa | Qué se comprueba |
| --- | --- |
| Checkout y configuración | Descarga el SHA real de la rama fuente del PR y verifica los identificadores y secretos obligatorios. |
| Entorno y dependencias | Configura Flutter 3.32.0 con Dart 3.8.0 y ejecuta `flutter pub get`. |
| Análisis estático Flutter | `flutter analyze --no-fatal-infos --no-fatal-warnings`: los errores bloquean; información y advertencias no bloquean en este comando. |
| Pruebas y cobertura | `flutter test --coverage` y LCOV no vacío. La suite contiene pruebas unitarias y de widgets. |
| Compilación | `flutter build web --no-web-resources-cdn --target lib/main.dart`; produce `build/web`. |
| SonarQube | Analiza `lib/` y `test/` en SonarQube Cloud e importa `coverage/lcov.info`. |
| Quality Gate | Espera la tarea del scanner y consulta el resultado de su `analysisId`. Solo `OK` permite continuar. |
| Artefacto | Conserva el paquete validado como `snackup-integrated-web`. |
| Notificación de fallo | Un job independiente se ejecuta ante `failure` y exige el acuse real de Slack o Discord. |

**Fail Fast:** el primer error detiene las siguientes etapas de validación. La auditoría y la notificación se conservan para comunicar el fallo. Una etapa omitida no se presenta como aprobada.

**CI** valida cambios y genera el artefacto. **Continuous Delivery** prepara un despliegue con aprobación manual para producción; **Continuous Deployment** lo ejecuta automáticamente. Esta actividad implementa CI y sus avisos; no incluye despliegue a producción.

## Configuración en JCoorp

Abrir [Settings → Secrets and variables → Actions](https://github.com/JCoorp/SnackUP-core/settings/secrets/actions) y configurar en **este repositorio**:

| Tipo | Nombre | Valor |
| --- | --- | --- |
| Repository secret | `SONAR_TOKEN` | Token real con permiso para analizar y consultar el proyecto SonarQube. |
| Repository secret | `CI_FAILURE_WEBHOOK_URL` | Webhook real del canal Slack o Discord del equipo. |
| Repository variable opcional | `SONAR_ORGANIZATION` | Valor por defecto: `jcoorp`. |
| Repository variable opcional | `SONAR_PROJECT_KEY` | Valor por defecto: `JCoorp_SnackUP-core`. |
| Repository variable opcional | `SONAR_HOST_URL` | Valor por defecto: `https://sonarcloud.io`. |

El proyecto SonarQube debe estar vinculado a **JCoorp/SnackUP-core**, con acceso de la app SonarQubeCloud a ese repositorio y análisis mediante CI habilitado. El workflow usa PR hacia la rama principal para este escenario. No convertir artificialmente una feature en `main` mediante `sonar.branch.name`.

Los tokens y el webhook se guardan únicamente como secretos. No incluirlos en el código, capturas, video ni documentación. Las claves de organización y proyecto son identificadores públicos. SonarQube se consulta con el identificador del análisis de esta ejecución; un resultado de otro commit no sustituye su Quality Gate.

## Cómo se acredita la notificación

El mensaje incluye SnackUP, rama, commit, primera etapa fallida, ID/intento de ejecución y enlace al registro.

- **Discord:** el notificador añade `wait=true` y exige el ID del mensaje creado.
- **Slack:** exige HTTP 200 y cuerpo de respuesta `ok`.
- Una configuración ausente, un error HTTP o una respuesta inesperada genera un resultado fallido.
- Un pipeline aprobado no envía un aviso de fallo.

`DELIVERED` significa aceptación del mensaje por el servidor del proveedor. No significa que una persona lo haya leído. Se guardan `snackup-ci-audit` con los resultados de CI/SonarQube y `snackup-ci-notification` con el acuse público. El paquete de aplicación aprobado se conserva por separado como `snackup-integrated-web`.

## Usar las dos ejecuciones reales

1. Usar como evidencia del fallo real [la ejecución 37869730221, intento 2](https://github.com/JCoorp/SnackUP-core/actions/runs/37869730221): SonarQube devolvió Gate `ERROR` por cobertura nueva de 45.0% frente al 80.0% requerido, bloqueó el artefacto y Discord confirmó la notificación con HTTP 200 e ID de mensaje. Este fallo ya acredita la alerta; no requiere provocar otro fallo artificial.
2. Usar como caso aprobado [la ejecución 37871800187, intento 1](https://github.com/JCoorp/SnackUP-core/actions/runs/37871800187): 188 pruebas, compilación, SonarQube, Gate `OK`, cobertura nueva 86.5% y artefacto validado. Sus resultados corresponden al mismo commit y análisis.
3. Mantener `docs/ci-parte-2/failure-test.json` con `"enabled": false` durante esta entrega. Recopilar ambos resultados y generar el video a partir de sus tiempos originales.

El fallo controlado queda como opción para demostraciones futuras: solo después de aprobar SonarQube y el Gate, un marcador `"enabled": true` en la rama de evidencia autorizada provoca una detención identificada expresamente en el aviso. Restaurarlo a `false` al terminar. Para esta entrega se conserva el fallo real del Gate y el marcador permanece desactivado.

Usar **Re-run all jobs** cuando sea necesario reintentar: tarea Sonar, auditoría y recibo deben corresponder al mismo `run_attempt`. No mezclar ejecuciones de repositorios, commits o intentos diferentes.

## Generar el video y entregar

Los dos IDs verificados ya se han guardado en `docs/ci-parte-2/evidence-runs.json` con `success_run: 37871800187` y `failure_run: 37869730221`. Su commit en la rama de evidencia activa el workflow **SnackUP CI parte 2 - video de evidencia real**.

El recolector verifica repositorio, SHA, run/intento, análisis SonarQube y recibo de la notificación. El grabador utiliza la interfaz del agente y reconstruye las etapas según sus tiempos originales. La reproducción es acelerada; no se presenta como una ejecución en vivo.

[El artefacto `snackup-ci-part2-video` de la ejecución 37872594393](https://github.com/JCoorp/SnackUP-core/actions/runs/37872594393) contiene:

- `SnackUP_Pipeline_CI_Parte2.mp4`: 80 segundos, H.264, 1600 × 1000.
- Capturas del análisis, Gate, fallo y notificación, y cierre aprobado.
- JSON de las ejecuciones y manifiesto con enlaces y hashes SHA-256.

El video muestra primero el fallo con su alerta y termina con el CI aprobado. Para la entrega, adjuntar ese MP4 y el [enlace de la rama de JCoorp](https://github.com/JCoorp/SnackUP-core/tree/feature/ci-sonar-notifications). Los dos requisitos ya están verificados en los servicios reales y sus fuentes constan en `ESTADO_VERIFICADO.json`. La grabación fue revisada visualmente y su SHA-256 coincide con `VIDEO_VERIFICADO.json`.

## Archivos y comprobación del código

| Archivo | Función |
| --- | --- |
| `.github/workflows/flutter-ci.yml` | CI, scanner, Gate y aviso independiente. |
| `sonar-project.properties` | Fuentes Dart, pruebas, exclusiones y cobertura LCOV desde la raíz. |
| `tools/ci_sonar/quality_gate.py` | Consulta la tarea exacta y bloquea un Gate sin aprobación. Lee `.scannerwork/report-task.txt` desde la raíz. |
| `tools/ci_notifications/notify_failure.py` | Envía el aviso y comprueba su acuse sin revelar secretos. |
| `tools/ci_evidence/collect_part2.py` | Verifica la procedencia de los resultados reales. |
| `tools/ci_evidence/record_part2.cjs` | Genera el video con estados y tiempos observados. |
| `tools/ci_agent/web/` | Interfaz gráfica del agente usada por el grabador. |

```bash
python3 -m unittest discover -s tools/ci_notifications/tests -v
python3 -m unittest discover -s tools/ci_sonar/tests -v
python3 -m unittest discover -s tools/ci_evidence/tests -v
node --test tools/ci_evidence/test_record_part2.cjs
```

Estas pruebas comprueban la implementación con respuestas simuladas; no envían mensajes ni sustituyen una ejecución SonarQube. El workflow **SnackUP CI parte 2 - verificar implementación** vuelve a ejecutarlas en el repositorio de esta entrega.

Referencias oficiales: [análisis Dart](https://docs.sonarsource.com/sonarqube-cloud/analyzing-source-code/languages/dart), [cobertura Dart](https://docs.sonarsource.com/sonarqube-cloud/analyzing-source-code/test-coverage/dart-test-coverage), [webhooks Slack](https://docs.slack.dev/messaging/sending-messages-using-incoming-webhooks/) y [webhooks Discord](https://docs.discord.com/developers/resources/webhook#execute-webhook).
