// Canonical application metadata. Packaging scripts read this file as well.
const appName = 'Visor Config';
const appVersion = '1.0.0-beta.1';
const appAuthor = 'Julio Viera';
const appLicenseName = 'GPL 3';
const appLicenseSpdx = 'GPL-3.0-only';
const appLicenseUrl = 'https://www.gnu.org/licenses/gpl-3.0.html';
const appRepositoryUrl = 'https://github.com/julio-viera/VisorConfig';
const appIssuesUrl = 'https://github.com/julio-viera/VisorConfig/issues';
const appId = 'io.github.julio_viera.VisorConfig';
const appPackageName = 'visor-config';
const appBinaryName = 'visor-config';

const appDescriptions = <String, String>{
  'es': 'Visor Config es una aplicación para visualizar, editar, validar y comparar documentos JSON, YAML y TOML, con vistas de texto, árbol, grafo y tabla, y exportación a JSON, YAML, TOML, CSV, PNG y SVG.',
  'en': 'Visor Config is an application for viewing, editing, validating and comparing JSON, YAML and TOML documents, with text, tree, graph and table views, and JSON, YAML, TOML, CSV, PNG and SVG export.',
  'fr': 'Visor Config permet de visualiser, modifier, valider et comparer des documents JSON, YAML et TOML, avec des vues texte, arbre, graphe et tableau, et des exports JSON, YAML, TOML, CSV, PNG et SVG.',
  'pt': 'Visor Config é um aplicativo para visualizar, editar, validar e comparar documentos JSON, YAML e TOML, com vistas de texto, árvore, grafo e tabela, e exportação para JSON, YAML, TOML, CSV, PNG e SVG.',
  'de': 'Visor Config ist eine Anwendung zum Anzeigen, Bearbeiten, Validieren und Vergleichen von JSON-, YAML- und TOML-Dokumenten mit Text-, Baum-, Graph- und Tabellenansicht sowie Export als JSON, YAML, TOML, CSV, PNG und SVG.',
  'it': 'Visor Config è un’applicazione per visualizzare, modificare, convalidare e confrontare documenti JSON, YAML e TOML, con viste testo, albero, grafo e tabella ed esportazione in JSON, YAML, TOML, CSV, PNG e SVG.',
};
String appDescriptionFor(String languageCode) =>
    appDescriptions[languageCode] ?? appDescriptions['en']!;
