# Certificados TLS

Esta carpeta recibe los certificados del servidor y **nunca** debe contener
llaves reales dentro de Git.

Archivos esperados al desplegar:

- `fullchain.pem`: certificado y cadena pública.
- `privkey.pem`: llave privada con permisos de lectura restringidos.

Para una instalación real se recomienda emitirlos con Certbot o con el
servicio de certificados administrado por el proveedor. Antes de iniciar
Compose, copie los archivos aquí únicamente en el servidor:

```bash
sudo install -m 0644 /etc/letsencrypt/live/DOMINIO/fullchain.pem deploy/certs/
sudo install -m 0600 /etc/letsencrypt/live/DOMINIO/privkey.pem deploy/certs/
```

No use certificados autofirmados para la entrega final.
