# Visor Config 1.0.0-beta.2

This beta improves editing and saving configuration files and adds AppImage packaging for Linux.

- New tabs start with a valid empty JSON object, with the cursor between the braces and the tab marked as clean until you edit it.
- The editor pairs braces and indents new lines. Choose tabs or two spaces for indentation. YAML uses spaces for indentation even when tabs are selected.
- Syntax highlighting distinguishes more token types. Optional, theme-aware marks show spaces and tabs.
- The status bar shows when a save is in progress, including on remote files. Edits made during a save remain marked as unsaved until written.
- Linux packaging now supports AppImage. The build and packaging scripts share application metadata from a single JSON file.

[Release history and downloads](../RELEASES.md)
