# Visor Config

[English](README.md) · [Français](README.fr.md) · [Português](README.pt.md) · [Deutsch](README.de.md) · [Italiano](README.it.md)

<img src="docs/images/visor-config.svg" width="300" alt="Visor Config">

Visor Config es una aplicación simple múltiplataforma para ver, edita, valida y compara archivos de configuración en varios formatos. Resaltado de sintansis y exportación a varios formatos.

## Archivos y pestañas

- **Formatos** — JSON, JSONC, YAML (`.yaml`, `.yml`), TOML, INI (`.ini`, `.cfg`), dotenv (`.env`, `.env.local`) y Java Properties (`.properties`).
- **Pestañas** — Permite abrirar varios archivos por pestañas. Cada pestaña mantiene su formato y esquema.  
- **Comparación** - Compara dos pestañas lado a lado con resaltado de diferencias y navegación.

## Vistas y edición

| Vista | Uso |
| --- | --- |
| Texto | Edita con resaltado de sintaxis y números de línea. Formatea o minifica el documento. |
| Árbol | Despliega secciones, edita valores y copia valores o rutas. |
| Grafo / Radial | Explora la estructura del documento. Despliega ramas, desplázate y ajusta el zoom. |
| Tabla | Consulta y edita filas de una lista de objetos con los mismos campos. |

![Vista de árbol con dos perfiles de ejemplo](docs/images/tree.png)

Busca en el documento activo por texto o JSONPath. La barra de estado muestra los errores de sintaxis. Para JSON, usa **Esquema** para validar con un JSON Schema. Para comparar versiones, abre ambos archivos en pestañas separadas y selecciona **Comparar JSON** para ver los cambios resaltados lado a lado.

## Exportación

- Convierte datos a JSON, YAML, TOML, INI, dotenv o Java Properties cuando el formato de destino admite su estructura.
- Exporta datos tabulares a CSV. Por ejemplo, abre una lista de perfiles con los mismos campos, cambia a **Tabla** y elige CSV en **Exportar**.
- Exporta el grafo visible a PNG o SVG. Despliega las ramas que quieras incluir antes de exportar.

![Vista de tabla de los perfiles de ejemplo](docs/images/table.png)

![Vista de grafo de los perfiles de ejemplo](docs/images/graph.png)

## Apariencia

Apariencia adaptada al tema del sistema, claro y oscuro. Pero también permite seleccionar esquema de colores, fuentes y tamaños.

[Licencia GPL 3](LICENSE)
