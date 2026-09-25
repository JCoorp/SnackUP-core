# SnackUp Canva Bridge

Puente preparado para trabajar **desde ChatGPT + GitHub** con la cuenta Canva del usuario sin compartir contraseñas ni tokens por el chat.

## Qué resuelve

### 1. Automatización Canva REST desde tu PC

El daemon local mantiene de forma segura la sesión OAuth y consulta los trabajos que ChatGPT deja en GitHub. Puede:

- listar y buscar diseños;
- consultar un diseño;
- crear presentaciones en blanco;
- importar PPTX/PDF/DOCX/XLSX como diseños editables de Canva;
- importar desde una URL pública;
- exportar diseños a PPTX/PDF/PNG/JPG/GIF/MP4 según lo que Canva permita.

Los refresh tokens de Canva son de un solo uso; por eso el daemon los rota **localmente** en `.data/` y nunca los guarda en GitHub.

### 2. Edición directa dentro del editor de Canva

La carpeta `canva-editor/` contiene una app de Canva que lee `recipes/latest.json` desde GitHub y aplica operaciones de edición sobre el diseño abierto usando `openDesign`.

Puede reemplazar/formatear texto, mover y redimensionar elementos, cambiar transparencias y colores, cambiar fondos, eliminar elementos y agregar texto.

Canva exige que una app dentro del editor se ejecute en la sesión del usuario. Por eso la aplicación muestra la receta y requiere un clic explícito en **Aplicar receta**. No modifica diseños silenciosamente.

## Seguridad

Nunca publiques ni pegues en ChatGPT:

- `CANVA_CLIENT_SECRET`;
- access tokens o refresh tokens;
- `GITHUB_TOKEN`.

Todos esos valores viven en `.env` o `.data/`, ambos ignorados por Git.

## Instalación rápida en Windows

Desde esta carpeta:

```powershell
powershell -ExecutionPolicy Bypass -File .\setup.ps1
```

El script te pedirá completar `.env`, abrirá el OAuth de Canva, descargará el starter kit oficial y preparará la app de edición.

Después puedes iniciar ambos componentes con:

```powershell
powershell -ExecutionPolicy Bypass -File .\start-all.ps1
```

## Configuración Canva necesaria

En Canva Developer Portal crea una app y habilita la superficie **Outside Canva / Canva for your platform** con estos scopes mínimos:

- `design:meta:read`
- `design:content:read`
- `design:content:write`

Agrega como redirect URL:

`http://127.0.0.1:8787/oauth/callback`

Para edición dentro de Canva, habilita también **Inside Canva** y usa el Design Editor intent. Durante desarrollo, la URL local será `http://localhost:8080`.

## Flujo diario

1. Ejecutas `start-all.ps1`.
2. Me dices en ChatGPT qué diseño crear o modificar.
3. Yo escribo un job o una receta en la rama `feat/canva-bridge-v1`.
4. El daemon ejecuta acciones REST automáticamente.
5. Para cambios de elementos dentro de un diseño, abres el diseño y pulsas **Aplicar receta** en la app ChatGPT Canva Editor.

## Nota técnica

El REST API de Canva puede crear/importar/exportar diseños, pero la edición arbitraria de elementos de un diseño existente requiere la Design Editing API, que corre dentro de una app incrustada en Canva. Por eso el proyecto combina ambos mecanismos.
