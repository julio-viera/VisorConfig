# Visor Config

[English](README.md) · [Español](README.es.md) · [Français](README.fr.md) · [Português](README.pt.md) · [Italiano](README.it.md)

<img src="docs/images/visor-config.svg" width="300" alt="Visor Config">

Visor Config ist eine einfache, plattformübergreifende Anwendung zum Anzeigen, Bearbeiten, Validieren und Vergleichen von Konfigurationsdateien in verschiedenen Formaten. Sie bietet Syntaxhervorhebung und den Export in mehrere Formate.

## Dateien und Tabs

- **Formate** — JSON, JSONC, YAML (`.yaml`, `.yml`), TOML, INI (`.ini`, `.cfg`), dotenv (`.env`, `.env.local`) und Java Properties (`.properties`).
- **Tabs** — Öffnen Sie mehrere Dateien in getrennten Tabs. Jeder Tab behält sein eigenes Format und Schema.
- **Vergleich** - Vergleichen Sie zwei Tabs nebeneinander. Unterschiede werden hervorgehoben und lassen sich einzeln anspringen.

## Ansichten und Bearbeitung

| Ansicht | Verwendung |
| --- | --- |
| Text | Bearbeiten Sie die Datei mit Syntaxhervorhebung und Zeilennummern. Formatieren oder minifizieren Sie das Dokument. |
| Baum | Klappen Sie Abschnitte auf, bearbeiten Sie Werte und kopieren Sie Werte oder Pfade. |
| Graph / Radialgraph | Erkunden Sie die Dokumentstruktur. Klappen Sie Zweige auf, verschieben Sie die Ansicht und ändern Sie den Zoom. |
| Tabelle | Lesen und bearbeiten Sie Zeilen einer Objektliste mit gleichen Feldern. |

![Baumansicht mit zwei Beispielprofilen](docs/images/tree.png)

Durchsuchen Sie das aktive Dokument nach Text oder per JSONPath. Die Statusleiste zeigt Syntaxfehler an. Über die Schema-Option können Sie JSON-Dokumente anhand eines JSON-Schemas validieren. Zum Vergleichen öffnen Sie beide Dateien in getrennten Tabs und starten den JSON-Vergleich. Änderungen werden nebeneinander hervorgehoben.

## Export

- Konvertieren Sie Daten nach JSON, YAML, TOML, INI, dotenv oder Java Properties, sofern das Zielformat die Struktur unterstützt.
- Exportieren Sie Tabellendaten als CSV. Öffnen Sie beispielsweise eine Profilliste mit gleichen Feldern, wechseln Sie zur **Tabelle** und wählen Sie CSV im Exportmenü.
- Exportieren Sie den sichtbaren Graphen als PNG oder SVG. Klappen Sie vor dem Export die gewünschten Zweige auf.

![Tabellenansicht der Beispielprofile](docs/images/table.png)

![Graphansicht der Beispielprofile](docs/images/graph.png)

## Darstellung

Die Darstellung richtet sich nach dem Systemdesign und kann auch auf hell oder dunkel eingestellt werden. Farbschema, Schriftart und Schriftgröße sind wählbar.

[GPL-3-Lizenz](LICENSE)
