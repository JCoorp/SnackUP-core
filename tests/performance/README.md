# Prueba de rendimiento con k6

El escenario sube gradualmente de 0 a 50 usuarios virtuales y después a 100.
Solo solicita la página principal; no inicia sesión ni escribe en Firebase.

## Criterios de aceptación

- Al menos 99 % de verificaciones correctas.
- Menos de 1 % de solicitudes fallidas.
- Percentil 95 menor a 2 segundos.

## Ejecución local

Inicie primero la versión Docker local:

```bash
docker compose -f compose.yaml -f compose.local.yaml up -d --build web
mkdir -p artifacts
k6 run tests/performance/k6-smoke.js
```

Para evaluar staging:

```bash
TARGET_URL=https://staging.ejemplo.edu.mx \
  k6 run tests/performance/k6-smoke.js
```

No apunte la prueba a producción sin una ventana y autorización explícitas.
La salida estructurada queda en `artifacts/k6-summary.json`.

Referencias:

- <https://grafana.com/docs/k6/latest/using-k6/scenarios/executors/ramping-vus/>
- <https://grafana.com/docs/k6/latest/using-k6/thresholds/>
