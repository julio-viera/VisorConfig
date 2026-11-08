# Visor Config

[English](README.md) · [Español](README.es.md) · [Français](README.fr.md) · [Português](README.pt.md) · [Deutsch](README.de.md)

[Versioni e download](RELEASES.md)

<img src="docs/images/visor-config.svg" width="300" alt="Visor Config">

Visor Config è un’applicazione semplice e multipiattaforma per visualizzare, modificare, convalidare e confrontare file di configurazione in diversi formati. Offre evidenziazione della sintassi ed esportazione in più formati.

## File e schede

- **Formati** — JSON, JSONC, YAML (`.yaml`, `.yml`), TOML, INI (`.ini`, `.cfg`), dotenv (`.env`, `.env.local`) e Java Properties (`.properties`).
- **Schede** — Apri più file in schede separate. Ogni scheda mantiene il proprio formato e schema.
- **Confronto** - Confronta due schede affiancate, con le differenze evidenziate e comandi per passare dall’una all’altra.

## Viste e modifica

| Vista | Uso |
| --- | --- |
| Testo | Modifica il file con evidenziazione della sintassi e numeri di riga. Formatta o minimizza il documento. |
| Albero | Espandi le sezioni, modifica i valori e copia valori o percorsi. |
| Grafo / Radiale | Esplora la struttura del documento. Espandi i rami, sposta la vista e regola lo zoom. |
| Tabella | Consulta e modifica le righe di un elenco di oggetti con gli stessi campi. |

![Vista ad albero con due profili di esempio](docs/images/tree.png)

Cerca nel documento attivo per testo o JSONPath. La barra di stato mostra gli errori di sintassi. Per JSON, usa l’opzione dello schema per convalidare il documento con un JSON Schema. Per confrontare due versioni, apri i file in schede separate e avvia il confronto JSON. Le modifiche sono evidenziate una accanto all’altra.

## Esportazione

- Converti i dati in JSON, YAML, TOML, INI, dotenv o Java Properties se il formato di destinazione supporta la struttura.
- Esporta i dati tabulari in CSV. Ad esempio, apri un elenco di profili con gli stessi campi, passa alla vista **Tabella** e scegli CSV nel menu di esportazione.
- Esporta il grafo visibile in PNG o SVG. Espandi i rami da includere prima dell’esportazione.

![Vista tabellare dei profili di esempio](docs/images/table.png)

![Grafo dei profili di esempio](docs/images/graph.png)

## Aspetto

L’aspetto segue il tema di sistema e può anche essere impostato su chiaro o scuro. Puoi scegliere la tavolozza dei colori, il carattere e la sua dimensione.

[Licenza GPL 3](LICENSE)
