# Recetas de edición dentro de Canva

`latest.json` es la receta que lee la app **ChatGPT Canva Editor** dentro del editor de Canva.

La receta solo se aplica cuando el usuario pulsa **Aplicar receta** en Canva. Esto deja una acción de deshacer clara y evita cambios sorpresivos.

Operaciones soportadas por la app:

- `replace_text`
- `format_text`
- `move`
- `resize`
- `set_transparency`
- `set_background_color`
- `set_rect_color`
- `set_shape_color`
- `delete_elements`
- `add_text`

Los números de página son **1-based**. Si se omite `page`, la operación puede aplicarse a todas las páginas editables.
