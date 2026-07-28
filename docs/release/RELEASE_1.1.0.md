# Plan de liberación SnackUp 1.1.0

Estado: candidato; no publicado
Tipo SemVer: versión menor

Se incrementa de 1.0.0 a 1.1.0 porque añade controles, pruebas y capacidad de
despliegue compatibles con la funcionalidad existente. El número de compilación
Flutter es `2`.

## Criterios de aceptación

- PR aprobado sin cambios directos en `main`.
- Formato, análisis, pruebas y compilación Flutter en verde.
- Imagen Docker construida sin publicación.
- k6 aprobado con 50-100 usuarios: errores menores a 1 % y p95 menor a 2 s.
- Lighthouse con rendimiento y accesibilidad de al menos 85.
- Revisión de privacidad y lista de seguridad incluidas.
- Dominio, TLS y servidor validados si se autoriza el despliegue externo.

## Liberación

Después de aprobar y fusionar el PR:

```bash
git switch main
git pull --ff-only origin main
git tag -a v1.1.0 -m "SnackUp 1.1.0"
git push origin v1.1.0
```

La etiqueta no debe crearse antes de que todos los criterios estén aprobados.
El despliegue se realiza siguiendo `docs/deployment/DEPLOYMENT.md`.

## Rollback

La versión base inmediatamente anterior a la práctica es el commit `b7abff6`
(`Merge pull request #1 from Gabino-RG/docs/update-readme-guide`). Si 1.1.0
falla, se reconstruye ese commit en el servidor, sin reescribir el historial:

```bash
git fetch origin --tags
git switch --detach b7abff6
docker compose build --no-cache web
docker compose up -d --force-recreate web edge
```

Después se valida `/healthz`, HTTPS y el flujo de acceso. El rollback de código
no restaura Firestore. Una restauración de datos sólo se ejecuta ante pérdida
confirmada, desde el respaldo verificado y con autorización expresa.

## Registro posterior

Documentar versión, commit, hora, responsable, resultado de las pruebas,
incidentes y decisión de continuar o revertir.
