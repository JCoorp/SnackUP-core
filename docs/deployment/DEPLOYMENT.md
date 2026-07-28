# Despliegue de SnackUp con Docker, Nginx y HTTPS

Esta guía prepara un despliegue reproducible sin modificar Firebase ni
incluir credenciales en el repositorio.

## Arquitectura

1. La etapa de compilación genera Flutter Web con Flutter 3.32.8.
2. El servicio `web` entrega archivos estáticos por el puerto interno 8080.
3. El servicio `edge` funciona como proxy inverso.
4. Nginx redirige HTTP a HTTPS y termina TLS en los puertos 80 y 443.
5. Firebase Authentication y Firestore continúan como servicios externos.

## Requisitos del servidor

- Linux de 64 bits.
- Docker Engine y Docker Compose v2.
- Dominio con registro DNS `A` o `AAAA` apuntando al servidor.
- Certificado TLS válido para ese dominio.
- Puertos públicos 80/TCP y 443/TCP.

## Preparación segura

```bash
git clone https://github.com/JCoorp/SnackUP-core.git
cd SnackUP-core
git switch --detach v1.1.0
export SNACKUP_DOMAIN=snackup.ejemplo.edu.mx
```

Los certificados se copian en `deploy/certs/` según
`deploy/certs/README.md`. Nunca deben confirmarse en Git.

## Firewall

En Ubuntu con UFW:

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable
sudo ufw status verbose
```

El puerto 22 solo debe permitirse desde las direcciones administrativas
autorizadas cuando la infraestructura lo permita. No publique el puerto
interno 8080 en producción.

## Validación local

La variante local no usa TLS y solo sirve para comprobar la imagen:

```bash
docker compose -f compose.yaml -f compose.local.yaml up --build web
curl --fail http://localhost:8080/healthz
```

## Despliegue HTTPS

```bash
docker compose build --pull
docker compose up -d
docker compose ps
curl --fail --proto '=https' --tlsv1.2 \
  "https://${SNACKUP_DOMAIN}/"
```

Validaciones posteriores:

```bash
curl -I "http://${SNACKUP_DOMAIN}/"
curl -I "https://${SNACKUP_DOMAIN}/"
openssl s_client -connect "${SNACKUP_DOMAIN}:443" \
  -servername "${SNACKUP_DOMAIN}" </dev/null
```

El primer comando debe redirigir a HTTPS. El segundo debe devolver `200` e
incluir HSTS y los encabezados de seguridad.

## Operación

```bash
docker compose logs --tail=100 edge web
docker compose pull
docker compose up -d
```

No ejecute pruebas de carga contra producción durante el horario de servicio.
Use un entorno de staging o una ventana autorizada.

## Rollback rápido

```bash
git fetch origin --tags
git switch --detach b7abff6
docker compose build --no-cache web
docker compose up -d --force-recreate web edge
curl --fail "https://${SNACKUP_DOMAIN}/"
```

`b7abff6` es el estado de `main` inmediatamente anterior a la práctica. Una vez
que exista una etiqueta aprobada para esa versión, puede usarse la etiqueta
equivalente. El rollback de código no modifica Firestore. Si una versión incluye
una migración de datos, debe ejecutarse primero el plan específico descrito en
la documentación de la versión.

## Referencias técnicas

- Docker Compose en producción:
  <https://docs.docker.com/compose/how-tos/production/>
- Configuración HTTPS de Nginx:
  <https://nginx.org/en/docs/http/configuring_https_servers.html>
