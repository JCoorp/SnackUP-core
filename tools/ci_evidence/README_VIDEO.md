# Video de evidencia de CI · segunda parte

La evidencia de esta entrega procede de **JCoorp/SnackUP-core**. `record_part2.cjs` utiliza dos ejecuciones CI reales terminadas del mismo repositorio: una aprobada y otra fallida con aviso confirmado. No ejecuta el pipeline ni envía avisos.

Antes de grabar, configurar `SONAR_TOKEN` y `CI_FAILURE_WEBHOOK_URL` en JCoorp. Los secretos de otro repositorio no se transfieren. El proyecto SonarQube utiliza organización `jcoorp` y clave `JCoorp_SnackUP-core`. No reutilizar ejecuciones anteriores como prueba de este repositorio.

## Ruta recomendada: workflow de video

Después de verificar ambos runs reales, guardar sus IDs como `success_run` y `failure_run` en `docs/ci-parte-2/evidence-runs.json`. Hacer commit de ese archivo en `feature/ci-sonar-notifications` activa **SnackUP CI parte 2 - video de evidencia real**. El workflow obtiene las fuentes usando `$GITHUB_REPOSITORY`, instala las dependencias de grabación y conserva `snackup-ci-part2-video`.

El proyecto Flutter está en la raíz. Los controles analizan `lib/` y `test/`, importan `coverage/lcov.info` y conservan `build/web`; el colector no depende de una carpeta `app/`. La auditoría mantiene los nombres `snackup-ci-audit`, `snackup-ci-notification` y `snackup-integrated-web`.

## Grabación local

Requisitos: Python 3, Node.js 20 o posterior, Playwright con Chromium y FFmpeg con `libx264`. Se necesitan los archivos `tools/ci_agent/web/index.html`, `styles.css` y `app.js`. El grabador sirve la interfaz y los datos reales en `127.0.0.1`; no requiere iniciar el backend del agente ni cargar evidencia histórica.

Con un `GITHUB_TOKEN` ya configurado en el entorno y permiso de lectura de Actions, ejecutar el colector sustituyendo los dos IDs de ejemplo por los reales:

```bash
python3 tools/ci_evidence/collect_part2.py \
  --repo JCoorp/SnackUP-core \
  --success-run 123456789 \
  --failure-run 123456790 \
  --outdir evidencia-parte2

npm install --prefix .ci-video --no-package-lock --no-save playwright@1.58.2
.ci-video/node_modules/.bin/playwright install chromium
NODE_PATH="$PWD/.ci-video/node_modules" node tools/ci_evidence/record_part2.cjs \
  --success evidencia-parte2/success.json \
  --failure evidencia-parte2/failure.json \
  --agent-root tools/ci_agent \
  --outdir video-parte2
```

No imprimir tokens ni escribirlos en los JSON. El workflow ya proporciona un token de lectura para recopilar sus propios artefactos.

| Argumento del grabador | Función |
| --- | --- |
| `--success archivo.json` | Ejecución aprobada con SonarQube y Quality Gate real `OK`. |
| `--failure archivo.json` | Ejecución fallida con notificación posterior y acuse real. |
| `--outdir carpeta` | MP4, capturas y manifiesto de verificación. |
| `--agent-root carpeta` | Directorio que contiene la interfaz `web/`. |
| `--validate-only` | Comprueba los JSON sin cargar Playwright ni crear video. |

## Comprobaciones de procedencia

El colector produce este contrato:

```text
{
  state: {repository, run_id, sha, url, status, conclusion, stages, ...},
  sonar: {analysis_id, gate_status, scan_executed, scan_stage_id, gate_stage_id, ...},
  notification: {status, provider, http_status, notification_stage_id, ...},
  source: {repository, run_id, sha, url, run_attempt, artifacts, ...}
}
```

Cada etapa conserva `id`, `name`, `status`, `logs` y sus marcas de tiempo originales. El análisis, el Gate y el recibo deben corresponder al mismo repositorio, commit y run/intento. Los IDs acreditados señalan las etapas reales: comprobar la configuración, descargar el notificador o guardar un comprobante no equivale a analizar código ni enviar un mensaje.

La ejecución aprobada necesita tarea Sonar exitosa, `analysis_id`, Gate `OK` y paquete de aplicación disponible. La ejecución fallida necesita un fallo observado y un aviso posterior aprobado con `DELIVERED`. Discord exige mensaje creado mediante `wait=true`; Slack exige HTTP 200 y cuerpo `ok`. Un HTTP 2xx aislado, una etapa omitida o una respuesta simulada no acreditan el requisito. `DELIVERED` demuestra aceptación por el servidor, no lectura humana.

Para el caso previsto, el marcador de fallo se activa únicamente después de aprobar SonarQube y el Gate. Restaurar `docs/ci-parte-2/failure-test.json` a `"enabled": false` al terminar. Si se reintenta una ejecución, ejecutar todos los jobs para no mezclar comprobantes de intentos diferentes.

## Video y salidas

El video dura **80 segundos**, tiene resolución **1600 × 1000** y formato MP4 H.264. Reconstruye los estados con tiempos originales, oculta resultados futuros y desplaza la lista siguiendo la etapa activa. Muestra primero el fallo y el aviso; termina con el CI aprobado y Gate `OK`. Sus leyendas identifican una reproducción acelerada de ejecuciones reales.

- `SnackUP_Pipeline_CI_Parte2.mp4`
- `ci2-fallo-notificacion.png`
- `ci2-sonarqube.png`
- `ci2-quality-gate.png`
- `ci2-aprobado-final.png`
- `verificacion-video-parte2.json`, con enlaces, analysis ID, acuse público y hashes SHA-256 de entradas y video.

El script redacta formatos comunes de tokens y webhooks. La evidencia debe llegar ya sin credenciales; la redacción no sustituye guardar los secretos correctamente.

## Pruebas de la implementación

```bash
python3 -m unittest discover -s tools/ci_evidence/tests -v
node --test tools/ci_evidence/test_record_part2.cjs
node tools/ci_evidence/record_part2.cjs --success aprobado.json --failure fallido.json --validate-only
```

Las fixtures son artificiales y prueban rechazo, concordancia y cronología. No se publican como ejecuciones del proyecto ni se usan para el video final. Las 50 pruebas de implementación aprobaron localmente tras la adaptación. Las 59 pruebas Flutter aprobadas en el trabajo previo son un antecedente; la aprobación remota de JCoorp debe acreditarse con sus propias ejecuciones nuevas.
