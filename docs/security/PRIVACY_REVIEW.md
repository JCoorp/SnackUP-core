# Revisión de privacidad y protección de datos

Fecha de revisión: 28 de julio de 2026
Versión revisada: 1.1.0 propuesta

Este documento es una evaluación técnica y académica; no sustituye asesoría
jurídica.

## Alcance normativo

La referencia mexicana es la Ley Federal de Protección de Datos Personales en
Posesión de los Particulares (LFPDPPP) vigente. Como referencia adicional se
consideran los principios del Reglamento General de Protección de Datos (RGPD)
de la Unión Europea cuando exista tratamiento relacionado con personas en su
ámbito territorial. La aplicabilidad definitiva debe confirmarla el responsable
legal de la institución.

Fuentes oficiales:

- <https://www.diputados.gob.mx/LeyesBiblio/pdf/LFPDPPP.pdf>
- <https://eur-lex.europa.eu/eli/reg/2016/679/oj/spa>

## Inventario observado

| Área | Datos | Finalidad funcional | Riesgo |
|---|---|---|---|
| Authentication | UID, correo, credencial cifrada por Firebase | Acceso y recuperación de cuenta | Alto |
| Perfil | Nombre, correo institucional, número de control, rol | Identificación y autorización | Alto |
| Pedidos | Usuario, productos, importes, estado, fechas, forma de pago | Preparación, entrega e historial | Alto |
| QR | Identificador asociado al usuario o pedido | Entrega y validación | Alto si se expone |
| Carrito y favoritos | Preferencias y productos | Continuidad de compra | Medio |
| Reseñas | Calificación, comentario y referencia de usuario | Retroalimentación | Medio |
| Negocios y menú | Datos del establecimiento y productos | Operación del servicio | Bajo/medio |

No se observó una necesidad funcional para almacenar números completos de
tarjeta, contraseñas en Firestore, documentos oficiales, ubicación precisa ni
datos sensibles. No deben añadirse sin una nueva evaluación.

## Principios y controles

| Control | Estado | Acción |
|---|---|---|
| Finalidad definida | Parcial | Publicar un aviso aprobado antes de la liberación |
| Minimización | Parcial | Evitar duplicar correo, nombre y número de control en pedidos |
| Consentimiento/aviso | Pendiente | Mostrar el aviso y registrar su versión cuando corresponda |
| Acceso, rectificación, cancelación y oposición | Pendiente | Definir canal, responsable y plazos operativos |
| Retención y eliminación | Pendiente | Aprobar plazos y automatizar depuración |
| Seguridad en tránsito | Preparado | HTTPS/TLS en Nginx; validar certificado en el servidor real |
| Autorización de Firestore | No verificable en Git | Importar y revisar las reglas exactas respaldadas antes de desplegar |
| Secretos | Conforme en esta rama | No hay cuentas de servicio, certificados ni exportaciones |
| Respuesta a incidentes | Parcial | Asignar responsables y procedimiento institucional |

## Riesgos encontrados

1. El rol está almacenado en el documento del usuario. La interfaz no constituye
   autorización; las reglas de Firestore deben impedir que una persona cambie su
   propio rol o acceda a pedidos ajenos.
2. El número de control y los identificadores usados en QR no deben mostrarse en
   registros, URL públicas ni capturas innecesarias.
3. El repositorio no contiene las reglas e índices actualmente desplegados. No
   es seguro reemplazarlos por una suposición. Deben incorporarse desde el
   respaldo verificado y revisarse en un emulador.
4. Los mensajes de error enviados a consola pueden contener información
   operativa. En producción deben ser mínimos y no incluir datos personales.
5. Firebase Storage aparece como dependencia, pero el servicio no está habilitado
   en el proyecto actual. No debe habilitarse ni cambiarse el plan sin
   autorización y reglas específicas.

## Recomendaciones previas a producción

1. Aprobar y publicar el aviso de privacidad propuesto.
2. Designar al responsable del tratamiento y un canal para solicitudes ARCO.
3. Importar `firestore.rules` y `firestore.indexes.json` desde el respaldo
   validado; probar reglas con Firebase Emulator Suite.
4. Aplicar mínimo privilegio por rol, propietario y pedido.
5. Definir plazos de retención. Propuesta inicial: carrito 30 días inactivo,
   registros técnicos 90 días y pedidos sólo durante el plazo administrativo
   aprobado.
6. Probar exportación y eliminación de la información de una persona.
7. Mantener copias cifradas, con acceso restringido y prueba periódica de
   restauración.

## Dictamen

La versión 1.1.0 mejora validación, HTTPS y disciplina de pruebas, pero no debe
declararse “cumplimiento legal completo” hasta cerrar los controles marcados
como pendientes y revisar las reglas reales de Firestore.
