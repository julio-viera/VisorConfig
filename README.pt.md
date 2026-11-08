# Visor Config

[English](README.md) · [Español](README.es.md) · [Français](README.fr.md) · [Deutsch](README.de.md) · [Italiano](README.it.md)

<img src="docs/images/visor-config.svg" width="300" alt="Visor Config">

O Visor Config é um aplicativo simples e multiplataforma para visualizar, editar, validar e comparar arquivos de configuração em vários formatos. Oferece realce de sintaxe e exportação para vários formatos.

## Arquivos e abas

- **Formatos** — JSON, JSONC, YAML (`.yaml`, `.yml`), TOML, INI (`.ini`, `.cfg`), dotenv (`.env`, `.env.local`) e Java Properties (`.properties`).
- **Abas** — Abra vários arquivos em abas separadas. Cada aba mantém seu próprio formato e esquema.
- **Comparação** - Compare duas abas lado a lado, com destaque das diferenças e navegação entre elas.

## Visualizações e edição

| Visualização | Uso |
| --- | --- |
| Texto | Edite com realce de sintaxe e números de linha. Formate ou minifique o documento. |
| Árvore | Expanda seções, edite valores e copie valores ou caminhos. |
| Grafo / Radial | Explore a estrutura do documento. Expanda ramos, desloque a visualização e ajuste o zoom. |
| Tabela | Consulte e edite linhas de uma lista de objetos com os mesmos campos. |

![Árvore com dois perfis de exemplo](docs/images/tree.png)

Busque no documento ativo por texto ou JSONPath. A barra de status mostra erros de sintaxe. Para JSON, use a opção de esquema para validar o documento com um JSON Schema. Para comparar versões, abra os arquivos em abas separadas e inicie a comparação JSON. As alterações aparecem destacadas lado a lado.

## Exportação

- Converta os dados para JSON, YAML, TOML, INI, dotenv ou Java Properties quando o formato de destino aceitar a estrutura.
- Exporte dados tabulares para CSV. Por exemplo, abra uma lista de perfis com os mesmos campos, mude para **Tabela** e escolha CSV no menu de exportação.
- Exporte o grafo visível para PNG ou SVG. Expanda os ramos que deseja incluir antes de exportar.

![Tabela dos perfis de exemplo](docs/images/table.png)

![Grafo dos perfis de exemplo](docs/images/graph.png)

## Aparência

A aparência segue o tema do sistema e também pode ser definida como clara ou escura. Você pode escolher a paleta de cores, a fonte e seu tamanho.

[Licença GPL 3](LICENSE)
