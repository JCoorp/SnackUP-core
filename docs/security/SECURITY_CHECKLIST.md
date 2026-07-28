# Lista de seguridad antes de liberar

- [x] La rama no contiene cuentas de servicio, exportaciones ni certificados.
- [x] El CI tiene permiso de repositorio sólo de lectura.
- [x] El CI no despliega ni escribe en Firebase.
- [x] La imagen de aplicación no ejecuta un servidor de desarrollo.
- [x] Nginx redirige HTTP a HTTPS y admite TLS 1.2/1.3.
- [x] Sólo se documentan los puertos públicos 80 y 443, además del SSH
  administrativo restringido.
- [ ] Revisar en emulador las reglas reales de Firestore respaldadas.
- [ ] Validar certificado, encabezados y DNS en el servidor autorizado.
- [ ] Aprobar aviso de privacidad, retención y procedimiento ARCO.
- [ ] Revisar dependencias y alertas de seguridad antes de etiquetar.
- [ ] Confirmar respaldo y restauración con una prueba aislada.
- [ ] Obtener revisión y aprobación del Pull Request.
