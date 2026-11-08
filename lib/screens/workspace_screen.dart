import '../models/json_standard.dart';

import 'dart:async';
import 'dart:io';
import 'dart:ui' show AppExitResponse;

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/document_file_controller.dart';
import '../controllers/editor_document_controller.dart';
import '../controllers/workspace_controller.dart';
import '../l10n/app_strings.dart';
import '../models/config_format.dart';
import '../models/font_preferences.dart';
import '../models/json_document.dart';
import '../models/launch_request.dart';
import '../services/graph_renderer.dart';
import '../themes/code_palette.dart';
import '../themes/editor_text_metrics.dart';
import '../widgets/dialogs/about_dialog.dart';
import '../widgets/dialogs/comparison_dialog.dart';
import '../widgets/dialogs/json_input_dialog.dart';
import '../widgets/dialogs/settings_dialog.dart';
import '../widgets/editor/document_tabs.dart';
import '../widgets/editor/document_toolbar.dart';
import '../widgets/editor/graph_document_view.dart';
import '../widgets/editor/raw_editor.dart';
import '../widgets/editor/table_document_view.dart';
import '../widgets/editor/tree_document_view.dart';
import '../widgets/workspace_status_bar.dart';

class WorkspaceScreen extends StatefulWidget {
  const WorkspaceScreen({
    super.key,
    required this.language,
    required this.fontSize,
    this.font = const FontPreferences(),
    this.onFont,
    required this.theme,
    required this.onSettings,
    this.colorTheme = 'jade',
    this.onColorTheme,
    this.lastOpenDirectory,
    this.onOpenDirectory,
    this.beforeExit,
    this.launch = const LaunchResult(),
    this.externalLaunches,
    this.desktopTitleBar = false,
  });
  final bool desktopTitleBar;
  final String language;
  final double fontSize;
  final FontPreferences font;
  final Future<bool> Function(FontPreferences)? onFont;
  final ThemeMode theme;
  final String colorTheme;
  final String? lastOpenDirectory;
  final Future<void> Function(String)? onOpenDirectory;
  final ValueChanged<String>? onColorTheme;
  final Future<void> Function()? beforeExit;
  final LaunchResult launch;
  final Stream<LaunchResult>? externalLaunches;
  final void Function(ThemeMode, String, double) onSettings;
  @override
  State<WorkspaceScreen> createState() => _WorkspaceState();
}

class _WorkspaceState extends State<WorkspaceScreen>
    with WidgetsBindingObserver {
  late final DocumentFileController fileController;
  final workspace = WorkspaceController();
  StreamSubscription<void>? launchSubscription;
  List<EditorDocumentController> get docs => workspace.documents;
  int get active => workspace.active;
  final tabsScroll = ScrollController();
  bool dropping = false;
  EditorDocumentController get doc => workspace.current;
  String get languageCode => resolveLanguage(
    widget.language,
    WidgetsBinding.instance.platformDispatcher.locale.languageCode,
  );
  bool get spanish => languageCode == 'es';
  String tr(String es, String en) => AppStrings(languageCode).tr(es, en);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    workspace.addListener(changed);
    fileController = DocumentFileController(
      workspace: workspace,
      lastOpenDirectory: widget.lastOpenDirectory,
      onOpenDirectory: (directory) async =>
          widget.onOpenDirectory?.call(directory),
      canDiscard: canDiscard,
      confirmReload: confirmReload,
      message: message,
      changed: changed,
      revealActiveTab: revealActiveTab,
      disposeDetached: (document) => WidgetsBinding.instance
          .addPostFrameCallback((_) => document.dispose()),
    );
    openLaunch(widget.launch);
    if (docs.isEmpty) addDocument();
    launchSubscription = widget.externalLaunches
        ?.asyncMap(openExternalLaunch)
        .listen(null);
  }

  Future<void> openExternalLaunch(LaunchResult launch) async {
    final issues = <LaunchIssue>[];
    for (final document in launch.documents) {
      if (!mounted) return;
      if (await fileController.focusOpenFileAsync(document.path)) continue;
      if (!mounted) return;
      try {
        final text = document.deferred
            ? await fileController.files.readPath(document.path!)
            : document.text;
        if (!mounted) return;
        if (document.deferred &&
            await fileController.focusOpenFileAsync(document.path)) {
          continue;
        }
        if (!mounted) return;
        addDocument(
          name: document.name,
          text: text,
          path: document.path,
          unsaved: document.unsaved,
        );
      } catch (error) {
        issues.add(
          LaunchIssue(document.path ?? '', switch (error) {
            FileSystemException(:final message) => message,
            FormatException(:final message) => message,
            _ => error.toString(),
          }, path: document.path),
        );
      }
    }
    final unresolved = <LaunchIssue>[];
    for (final issue in [...launch.issues, ...issues]) {
      if (!mounted) return;
      if (!await fileController.focusOpenFileAsync(issue.path) && mounted) {
        unresolved.add(issue);
      }
    }
    if (mounted) showLaunchIssues(unresolved);
  }

  void openLaunch(LaunchResult launch) {
    for (final document in launch.documents) {
      if (fileController.focusOpenFile(document.path)) continue;
      addDocument(
        name: document.name,
        text: document.text,
        path: document.path,
        unsaved: document.unsaved,
      );
    }
    final issues = launch.issues
        .where((issue) => !fileController.focusOpenFile(issue.path))
        .toList();
    showLaunchIssues(issues);
  }

  void showLaunchIssues(List<LaunchIssue> issues) {
    if (issues.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        message(
          issues
              .map(
                (issue) =>
                    '${tr('No se pudo abrir', 'Could not open')}: ${issue.input} — ${AppStrings(languageCode).error(issue.message)}',
              )
              .join('\n'),
        );
      });
    }
  }

  void changed() {
    if (mounted) setState(() {});
  }

  void addDocument({
    String? name,
    String text = '',
    String? path,
    bool unsaved = false,
  }) {
    final d = workspace.add(
      untitledLabel: tr('Sin título', 'Untitled'),
      name: name,
      text: text,
      path: path,
      unsaved: unsaved,
    );
    revealActiveTab();
    if (path != null && !Platform.isAndroid) watch(d);
  }

  void revealActiveTab() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !tabsScroll.hasClients) return;
      final widths = DocumentTabs.measureWidths(context, docs);
      final start = widths.take(active).fold(0.0, (sum, width) => sum + width);
      final end = start + widths[active];
      final position = tabsScroll.position;
      final target =
          widths[active] > position.viewportDimension || start < position.pixels
          ? start
          : end > position.pixels + position.viewportDimension
          ? end - position.viewportDimension
          : position.pixels;
      tabsScroll.animateTo(
        target.clamp(0, position.maxScrollExtent),
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    });
  }

  void selectDocument(int index) {
    workspace.select(index);
    revealActiveTab();
  }

  void scrollTabs(int direction) {
    if (!tabsScroll.hasClients) return;
    tabsScroll.animateTo(
      (tabsScroll.offset +
              direction * tabsScroll.position.viewportDimension * .8)
          .clamp(0, tabsScroll.position.maxScrollExtent),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    launchSubscription?.cancel();
    tabsScroll.dispose();
    fileController.dispose();
    workspace.removeListener(changed);
    workspace.dispose();
    super.dispose();
  }

  @override
  Future<AppExitResponse> didRequestAppExit() async {
    for (final d in List.of(docs)) {
      if (!await canDiscard(d)) return AppExitResponse.cancel;
    }
    await widget.beforeExit?.call();
    return AppExitResponse.exit;
  }

  void message(Object text) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$text')));
    }
  }

  Future<bool> canDiscard(EditorDocumentController d) async {
    final pending = fileController.pendingSave(d);
    if (pending != null) await pending;
    if (!mounted || d.closed) return false;
    if (!d.dirty) return true;
    final answer = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('Cambios sin guardar', 'Unsaved changes')),
        content: Text(d.name),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'cancel'),
            child: Text(tr('Cancelar', 'Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'discard'),
            child: Text(tr('Descartar', 'Discard')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'save'),
            child: Text(tr('Guardar', 'Save')),
          ),
        ],
      ),
    );
    if (answer == 'save') return await save(d) && !d.dirty;
    return answer == 'discard';
  }

  Future<void> close(EditorDocumentController d) async {
    if (!await canDiscard(d) || !mounted) return;
    workspace.remove(d);
    if (docs.isEmpty) {
      addDocument();
    } else {
      revealActiveTab();
    }
  }

  Future<void> open([List<XFile>? files]) => fileController.open(files);
  Future<bool> save(EditorDocumentController d, {bool saveAs = false}) =>
      fileController.save(d, saveAs: saveAs);
  Future<void> export(String kind) => fileController.export(
    kind,
    palette: CodePalette.of(context),
    confirmTruncation: (total) async =>
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(tr('Exportación parcial', 'Partial export')),
            content: Text('2000 / $total'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(tr('Cancelar', 'Cancel')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(tr('Exportar', 'Export')),
              ),
            ],
          ),
        ) ??
        false,
  );
  void watch(EditorDocumentController d) => fileController.watch(d);

  Future<bool?> confirmReload(EditorDocumentController d) => showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(
        tr('Archivo modificado externamente', 'File changed externally'),
      ),
      content: Text(
        '${d.name}\n${tr('¿Recargar? Se reemplazarán los cambios locales.', 'Reload? Local changes will be replaced.')}',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(tr('Conservar', 'Keep')),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(tr('Recargar', 'Reload')),
        ),
      ],
    ),
  );

  Future<void> editNode(JsonNode node) async {
    final d = doc;
    final revision = d.revision;
    final result = d.result;
    if (result == null || result.byPath[node.path] != node) return;
    final format = result.format;
    final String initial;
    try {
      initial = d.nodeSource(node);
    } catch (error) {
      message(error);
      return;
    }
    String? edited;
    final replacement = await showDialog<String>(
      context: context,
      builder: (_) => JsonInputDialog(
        title: node.path,
        copyPathLabel: tr('Copiar ruta', 'Copy path'),
        initialText: initial,
        validateSyntax: format == ConfigFormat.json,
        validate: format == ConfigFormat.json
            ? null
            : (source) {
                if (!d.closed && d.revision == revision && source != initial) {
                  edited = d.editedConfig(node, source);
                }
              },
        helper: format == ConfigFormat.toml && node.keyStart == null
            ? tr(
                'La edición estructurada de TOML vuelve a formatear el documento y elimina sus comentarios.',
                'Structured TOML edits reformat the document and remove its comments.',
              )
            : null,
        cancelLabel: tr('Cancelar', 'Cancel'),
        applyLabel: tr('Aplicar', 'Apply'),
      ),
    );
    if (replacement == null || replacement == initial || d.closed) return;
    if (d.revision != revision) {
      message(
        tr(
          'El documento cambió; vuelve a abrir el editor del nodo.',
          'Document changed; reopen the node editor.',
        ),
      );
      return;
    }
    if (edited case final text?) {
      d.editor.text = text;
    } else {
      d.replaceNode(node, replacement);
    }
  }

  Future<void> editSchema() async {
    final d = doc;
    final schema = await showDialog<String>(
      context: context,
      builder: (_) => JsonInputDialog(
        title: tr('Esquema de validación', 'Validation schema'),
        initialText: d.schema,
        cancelLabel: tr('Cancelar', 'Cancel'),
        applyLabel: tr('Validar', 'Validate'),
        validateSyntax: false,
        hint: '{"type":"object","required":["name"]}',
        helper: tr(
          'Draft 7 por defecto. Usa \$schema para otro draft. Vacío: solo sintaxis. Sin referencias remotas.',
          'Draft 7 by default. Use \$schema for another draft. Empty: syntax only. No remote references.',
        ),
      ),
    );
    if (schema != null && !d.closed) {
      d.schema = schema;
      d.validate();
    }
  }

  Future<void> compare() async {
    final left = doc;
    final others = docs
        .where((d) => d != left && d.result?.error == null && d.result != null)
        .toList();
    if (others.isEmpty || left.result == null || left.result!.error != null) {
      message(
        tr(
          'Abre dos documentos JSON válidos para comparar.',
          'Open two valid JSON documents to compare.',
        ),
      );
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (_) => ComparisonDialog(
        left: ComparisonSource(left.name, left.editor.text),
        others: others
            .map((d) => ComparisonSource(d.name, d.editor.text))
            .toList(),
        spanish: spanish,
        language: languageCode,
      ),
    );
  }

  void about() => showDialog<void>(
    context: context,
    builder: (_) => AppAboutDialog(language: languageCode),
  );

  Future<void> settings() => showDialog<void>(
    context: context,
    builder: (_) => SettingsDialog(
      theme: widget.theme,
      language: widget.language,
      fontSize: widget.fontSize,
      font: widget.font,
      onFont: widget.onFont,
      colorTheme: widget.colorTheme,
      onSettings: widget.onSettings,
      onColorTheme: widget.onColorTheme,
    ),
  );

  final _graphViewportKey = GlobalKey();

  void navigateMatch(int delta) {
    final d = doc;
    if (d.matches.isEmpty) return;
    d.currentMatch = (d.currentMatch + delta) % d.matches.length;
    final node = d.matches[d.currentMatch];
    d.editor.selection = TextSelection(
      baseOffset: node.start,
      extentOffset: node.end,
    );
    final nodes = d.result?.nodes ?? [];
    var parent = node.parent;
    while (parent >= 0) {
      d.expanded.add(nodes[parent].path);
      parent = nodes[parent].parent;
    }
    if (d.mode == 'tree' && d.scroll.hasClients) {
      final index = d.visible.indexWhere((n) => n.path == node.path);
      d.scroll.animateTo(
        (index * 44.0).clamp(0, d.scroll.position.maxScrollExtent),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
    if (d.mode == 'raw' && d.rawScroll.hasClients) {
      final line = d.editor.text.length > 1000000
          ? d.sourceSegments.indexWhere((segment) => segment.end >= node.start)
          : '\n'.allMatches(d.editor.text.substring(0, node.start)).length;
      final height = EditorTextMetrics(context).lineHeight;
      d.rawScroll.animateTo(
        (line * height).clamp(0, d.rawScroll.position.maxScrollExtent),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
    if (d.mode == 'graph' || d.mode == 'radial' || d.mode == 'diagram') {
      d.graphRoot = r'$';
      final layout = GraphLayout(
        d.graphNodes.take(2000).toList(),
        radial: d.mode == 'radial',
        diagram: d.mode == 'diagram',
      );
      final box = layout.boxes[node.path];
      if (box != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted ||
              d.closed ||
              doc != d ||
              (d.mode != 'graph' &&
                  d.mode != 'radial' &&
                  d.mode != 'diagram') ||
              d.matches.isEmpty ||
              d.matches[d.currentMatch] != node) {
            return;
          }
          final size = _graphViewportKey.currentContext?.size;
          if (size == null || size.isEmpty) return;
          final scale = d.graphTransform.value.getMaxScaleOnAxis();
          final center = size.center(Offset.zero) - box.center * scale;
          d.graphTransform.value = Matrix4.translationValues(
            center.dx,
            center.dy,
            0,
          )..scaleByDouble(scale, scale, scale, 1);
        });
      } else {
        message(
          tr(
            'El resultado supera el límite del grafo; consúltalo en Árbol.',
            'Match is beyond the graph limit; view it in Tree.',
          ),
        );
      }
    }
    if (d.mode == 'table' && d.tableScroll.hasClients) {
      final match = RegExp(r'^\$\[(\d+)\]').firstMatch(node.path);
      if (match != null) {
        d.tableScroll.animateTo(
          (int.parse(match.group(1)!) * 48.0).clamp(
            0,
            d.tableScroll.position.maxScrollExtent,
          ),
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    }
    setState(() {});
  }

  Widget action(
    IconData icon,
    String title,
    VoidCallback callback, {
    Color? color,
  }) => IconButton(
    tooltip: title,
    onPressed: callback,
    icon: Icon(icon, size: 20, color: color),
  );
  @override
  Widget build(BuildContext context) {
    final d = doc;
    final compact =
        !widget.desktopTitleBar && MediaQuery.sizeOf(context).width < 760;
    final result = d.result;
    final palette = CodePalette.of(context);
    final hasError = !d.parsing && result != null && !result.valid;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyN, control: true): () =>
            addDocument(),
        const SingleActivator(LogicalKeyboardKey.keyO, control: true): () =>
            open(),
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): () =>
            save(doc),
        const SingleActivator(
          LogicalKeyboardKey.keyS,
          control: true,
          shift: true,
        ): () =>
            save(doc, saveAs: true),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          drawer: compact
              ? Drawer(
                  child: SafeArea(
                    child: Column(
                      children: [
                        Expanded(
                          child: ListView.builder(
                            itemCount: docs.length,
                            itemBuilder: (_, i) => ListTile(
                              selected: i == active,
                              selectedColor: Colors.white,
                              selectedTileColor: palette.selectedTab,
                              title: Text(
                                '${docs[i].dirty ? '● ' : ''}${docs[i].name}',
                              ),
                              trailing: action(
                                Icons.close,
                                tr('Cerrar', 'Close'),
                                () => close(docs[i]),
                                color: i == active
                                    ? Colors.white
                                    : palette.inactiveTabText,
                              ),
                              onTap: () {
                                workspace.select(i);
                                Navigator.pop(context);
                              },
                            ),
                          ),
                        ),
                        ListTile(
                          leading: const Icon(Icons.add),
                          title: Text(tr('Nuevo documento', 'New document')),
                          onTap: () {
                            addDocument();
                            Navigator.pop(context);
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.settings_outlined),
                          title: Text(tr('Configuración', 'Settings')),
                          onTap: () {
                            Navigator.pop(context);
                            settings();
                          },
                        ),
                      ],
                    ),
                  ),
                )
              : null,
          body: DropTarget(
            onDragEntered: (_) => setState(() => dropping = true),
            onDragExited: (_) => setState(() => dropping = false),
            onDragDone: (details) {
              setState(() => dropping = false);
              open(details.files);
            },
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: dropping
                    ? Border.all(
                        color: Theme.of(context).colorScheme.primary,
                        width: 3,
                      )
                    : null,
              ),
              child: Column(
                children: [
                  if (!compact)
                    DocumentTabs(
                      desktopTitleBar: widget.desktopTitleBar,
                      documents: docs,
                      active: active,
                      controller: tabsScroll,
                      language: languageCode,
                      onScroll: scrollTabs,
                      onSelect: selectDocument,
                      onClose: close,
                      onNew: () => addDocument(),
                      onSettings: settings,
                      comparisonButton: comparisonButton(),
                    ),
                  if (compact)
                    SizedBox(
                      height: 48,
                      child: Row(
                        children: [
                          Builder(
                            builder: (context) => IconButton(
                              tooltip: tr('Pestañas', 'Tabs'),
                              onPressed: () =>
                                  Scaffold.of(context).openDrawer(),
                              icon: const Icon(Icons.menu),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              '${d.dirty ? '● ' : ''}${d.name}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          action(
                            Icons.add,
                            tr('Nuevo', 'New'),
                            () => addDocument(),
                          ),
                          comparisonButton(),
                          action(
                            Icons.settings_outlined,
                            tr('Configuración', 'Settings'),
                            settings,
                          ),
                        ],
                      ),
                    ),
                  DocumentToolbar(
                    document: d,
                    language: languageCode,
                    onOpen: () => open(),
                    onSave: () => save(d),
                    onSaveAs: () => save(d, saveAs: true),
                    onSchema: editSchema,
                    onExport: export,
                    onNavigateMatch: navigateMatch,
                    onChanged: changed,
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: KeyedSubtree(
                      key: ObjectKey(d),
                      child: d.mode == 'raw'
                          ? rawView(d)
                          : result == null ||
                                result.error != null ||
                                result.hasDuplicateKeys
                          ? Center(
                              child: Text(
                                result?.hasDuplicateKeys == true
                                    ? result!.issues.first
                                    : d.parsing
                                    ? tr('Validando…', 'Validating…')
                                    : tr(
                                        'Corrige el documento en la vista Texto',
                                        'Fix the document in Raw view',
                                      ),
                              ),
                            )
                          : d.mode == 'tree'
                          ? TreeDocumentView(
                              document: d,
                              language: languageCode,
                              onEdit: editNode,
                            )
                          : d.mode == 'table'
                          ? TableDocumentView(
                              document: d,
                              language: languageCode,
                              onEdit: editNode,
                            )
                          : GraphDocumentView(
                              viewportKey: _graphViewportKey,
                              document: d,
                              language: languageCode,
                              onEdit: editNode,
                            ),
                    ),
                  ),
                  WorkspaceStatusBar(
                    status: status(d),
                    parsing: d.parsing,
                    valid: result?.valid == true,
                    hasError: hasError,
                    characters: d.editor.text.length,
                    language: languageCode,
                    onAbout: about,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget comparisonButton() => IconButton(
    key: const Key('fixed-compare-tab'),
    tooltip: tr('Comparar JSON', 'Compare JSON'),
    onPressed: compare,
    icon: const Icon(Icons.compare_arrows),
  );

  String status(EditorDocumentController d) {
    final r = d.result;
    if (d.parsing) return tr('Validando…', 'Validating…');
    if (r?.error != null) {
      final offset = (r!.offset ?? 0).clamp(0, d.editor.text.length);
      final before = d.editor.text.substring(0, offset);
      return '${tr('Línea', 'Line')} ${'\n'.allMatches(before).length + 1}, ${tr('columna', 'column')} ${offset - before.lastIndexOf('\n')}: ${AppStrings(languageCode).error(r.error!)}';
    }
    if (r == null) return '';
    if (r.issues.isNotEmpty) return r.issues.join(' · ');
    if (r.format != ConfigFormat.json) {
      final valid = r.format == ConfigFormat.yaml
          ? tr('YAML válido', 'Valid YAML')
          : r.format == ConfigFormat.toml
          ? tr('TOML válido', 'Valid TOML')
          : r.format.label;
      return '$valid · ${r.nodes.length} ${tr('nodos', 'nodes')}';
    }
    return '${tr('JSON válido', 'Valid JSON')} · ${r.nodes.length} ${tr('nodos', 'nodes')}${usesJsonSchema(d.standard) && d.schema.trim().isEmpty ? ' · ${tr('Sin esquema: sintaxis validada', 'No schema: syntax validated')}' : ' · ${d.standard}'}';
  }

  Widget rawView(EditorDocumentController d) => RawEditor(
    document: d,
    hint: tr(
      'Pega una configuración aquí o abre un archivo…',
      'Paste configuration here or open a file…',
    ),
    largeNotice: tr(
      'Documento grande: Texto en solo lectura. Edita nodos en Árbol, Grafo o Tabla.',
      'Large document: Raw is read-only. Edit nodes in Tree, Graph or Table.',
    ),
  );
}
