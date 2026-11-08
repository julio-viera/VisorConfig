# Visor Config

[Español](README.es.md) · [Français](README.fr.md) · [Português](README.pt.md) · [Deutsch](README.de.md) · [Italiano](README.it.md)

<img src="docs/images/visor-config.svg" width="300" alt="Visor Config">

Visor Config is a simple, cross-platform application for viewing, editing, validating, and comparing configuration files in several formats. It supports syntax highlighting and export to several formats.

## Files and tabs

- **Formats** — JSON, JSONC, YAML (`.yaml`, `.yml`), TOML, INI (`.ini`, `.cfg`), dotenv (`.env`, `.env.local`), and Java Properties (`.properties`).
- **Tabs** — Open multiple files in separate tabs. Each tab keeps its own format and schema.
- **Comparison** - Compare two tabs side by side, with highlighted differences and controls to move between them.

## Views and editing

| View | Use |
| --- | --- |
| Text | Edit with syntax highlighting and line numbers. Format or minify the document. |
| Tree | Expand sections, edit values, and copy values or paths. |
| Graph / Radial | Explore the document structure. Expand branches, pan, and zoom. |
| Table | View and edit rows in a list of objects with matching fields. |

![Tree view with two example profiles](docs/images/tree.png)

Search within the active document by text or JSONPath. The status bar shows syntax errors. For JSON, use **Schema** to validate against a JSON Schema. To compare revisions, open both files in separate tabs and select **Compare JSON** to see highlighted changes side by side.

## Export

- Convert data to JSON, YAML, TOML, INI, dotenv, or Java Properties when the target format supports its structure.
- Export tabular data as CSV. For example, open a list of profiles with matching fields, switch to **Table**, and choose CSV under **Export**.
- Export the visible graph as PNG or SVG. Expand the branches you want to include before exporting.

![Table view of the example profiles](docs/images/table.png)

![Graph view of the example profiles](docs/images/graph.png)

## Appearance

The appearance follows the system theme and can also be set to light or dark. You can choose the color scheme, font, and font size.

[GPL 3 license](LICENSE)
