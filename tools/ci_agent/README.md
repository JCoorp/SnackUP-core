# SnackUP CI Agent

Agente basado en reglas que muestra las etapas reales de GitHub Actions y explica por qué una etapa falla, cuáles quedan bloqueadas y cuándo el artefacto está listo. El análisis SonarQube y la notificación se obtienen de los registros y comprobantes de la misma ejecución.

Para consultar ejecuciones públicas de este repositorio:

```bash
python3 tools/ci_agent/server.py
```

Abrir `http://127.0.0.1:8765`, pulsar **Consultar GitHub**, buscar las ejecuciones de `JCoorp/SnackUP-core` y seleccionar la ejecución. La demostración local se identifica como demo; no acredita SonarQube ni notificaciones externas.

Para el video académico, `tools/ci_evidence/collect_part2.py` comprueba una ejecución aprobada y una fallida del mismo repositorio. `record_part2.cjs` sirve esta interfaz con esos datos verificados y reproduce sus marcas de tiempo de forma acelerada. Ver `docs/ci-parte-2/README.md`.
