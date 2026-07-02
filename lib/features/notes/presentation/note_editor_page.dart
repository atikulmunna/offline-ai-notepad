import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../../security/providers/app_lock_providers.dart';
import '../domain/note_body_text.dart';
import 'note_image_embed.dart';
import '../../ai/domain/note_suggestions.dart';
import '../../ai/providers/ai_actions.dart';
import '../../ai/providers/ai_providers.dart';
import '../../ai/providers/model_download_controller.dart';
import '../../ai/providers/note_assistant_providers.dart';
import '../../ai/providers/related_notes_providers.dart';
import '../../appearance/presentation/glass_surface.dart';
import '../../appearance/providers/appearance_providers.dart';
import '../domain/note_document.dart';
import '../domain/note_folder.dart';
import '../domain/note_preview.dart';
import '../domain/note_tag.dart';
import '../providers/notes_actions.dart';
import '../providers/notes_providers.dart';

class NoteEditorPage extends ConsumerStatefulWidget {
  const NoteEditorPage({
    super.key,
    this.noteId,
  });

  final String? noteId;

  @override
  ConsumerState<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends ConsumerState<NoteEditorPage> {
  static const List<Color> _textColorPalette = [
    Color(0xFF0A0908),
    Color(0xFF22333B),
    Color(0xFF5E503F),
    Color(0xFF8A7259),
    Color(0xFFA98B6A),
    Color(0xFF6D4C41),
    Color(0xFF4A5A48),
    Color(0xFF8C6239),
  ];
  static const List<Color> _highlightPalette = [
    Color(0xFFEAE0D5),
    Color(0xFFDCC8AF),
    Color(0xFFC6AC8F),
    Color(0xFFB89F83),
    Color(0xFFD7C6B4),
    Color(0xFFCDBA9E),
  ];
  final _titleController = TextEditingController();
  final _bodyController = QuillController.basic();
  final _bodyFocusNode = FocusNode();
  Timer? _autosaveTimer;
  Timer? _assistTimer;
  bool _didLoadInitialData = false;
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isGeneratingSummary = false;
  bool _showFormattingToolbar = false;
  bool _showInlineSummary = false;
  String? _activeNoteId;
  String? _selectedFolderId;
  String? _summary;
  NoteSuggestions _suggestions = const NoteSuggestions.none();
  List<NotePreview> _related = const [];
  List<NoteTag> _selectedTags = const [];

  @override
  void initState() {
    super.initState();
    _activeNoteId = widget.noteId;
    _titleController.addListener(_onEdited);
    _bodyController.addListener(_onEdited);
    _warmAttachments();
    _loadInitialNote();
  }

  /// Prepares the attachments directory so the inline image embed builder can
  /// resolve stored file names synchronously. Rebuilds once ready so any images
  /// in an existing note render on first frame.
  Future<void> _warmAttachments() async {
    await ref.read(attachmentStoreProvider).ensureReady();
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadInitialNote() async {
    if (widget.noteId == null) {
      _didLoadInitialData = true;
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final note = await ref.read(notesActionsProvider).loadNote(widget.noteId!);
    if (note != null && mounted) {
      _applyNote(note);
    }

    if (mounted) {
      setState(() {
        _didLoadInitialData = true;
        _isLoading = false;
      });
      unawaited(_refreshRelated());
    } else {
      _didLoadInitialData = true;
    }
  }

  void _applyNote(NoteDocument note) {
    _activeNoteId = note.id;
    _titleController.text = note.title ?? '';
    _bodyController.document = _documentFromStoredContent(
      body: note.body,
      bodyDelta: note.bodyDelta,
    );
    _bodyController.updateSelection(
      const TextSelection.collapsed(offset: 0),
      ChangeSource.local,
    );
    _selectedFolderId = note.folderId;
    _summary = note.summary;
    _selectedTags = List<NoteTag>.from(note.tags);
  }

  void _onEdited() {
    _scheduleAutosave();
    _scheduleAssist();
  }

  void _scheduleAutosave() {
    if (!_didLoadInitialData || _isLoading) {
      return;
    }

    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(const Duration(milliseconds: 900), () async {
      await _persist(closeAfterSave: false);
    });
  }

  /// Recomputes title/folder suggestions after the user pauses typing. Longer
  /// debounce than autosave so we don't run the embedder on every keystroke.
  void _scheduleAssist() {
    if (!_didLoadInitialData || _isLoading) {
      return;
    }

    _assistTimer?.cancel();
    _assistTimer = Timer(const Duration(milliseconds: 1500), _runAssistPass);
  }

  Future<void> _runAssistPass() async {
    await _refreshSuggestions();
    await _refreshRelated();
  }

  /// Loads notes semantically related to the current one for the "See also"
  /// strip. Uses the stored embedding (no model call) with a lexical fallback.
  Future<void> _refreshRelated() async {
    if (!mounted) {
      return;
    }
    final noteId = _activeNoteId;
    if (noteId == null) {
      if (_related.isNotEmpty) {
        setState(() => _related = const []);
      }
      return;
    }

    try {
      final related = await ref
          .read(relatedNotesServiceProvider)
          .relatedTo(noteId: noteId, body: _plainBody);
      if (!mounted) {
        return;
      }
      setState(() => _related = related);
    } catch (_) {
      // "See also" is a best-effort enhancement; ignore failures.
    }
  }

  Future<void> _openRelated(String noteId) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (context) => NoteEditorPage(noteId: noteId)),
    );
  }

  Future<void> _openTagPicker() async {
    final result = await showModalBottomSheet<List<NoteTag>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TagPickerSheet(selected: _selectedTags),
    );
    if (result != null && mounted) {
      setState(() => _selectedTags = result);
      _scheduleAutosave();
    }
  }

  Future<void> _refreshSuggestions() async {
    if (!mounted) {
      return;
    }

    final enabled = ref.read(appearanceControllerProvider).smartSuggestions;
    final body = _plainBody;

    if (!enabled || body.isEmpty) {
      if (_suggestions.isNotEmpty) {
        setState(() => _suggestions = const NoteSuggestions.none());
      }
      return;
    }

    try {
      final assistant = await ref.read(noteAssistantProvider.future);
      final result = await assistant.suggest(
        noteId: _activeNoteId ?? '',
        currentTitle: _titleController.text,
        body: body,
        currentFolderId: _selectedFolderId,
        currentTags: _selectedTags,
      );
      if (!mounted) {
        return;
      }
      setState(() => _suggestions = result);
    } catch (_) {
      // Suggestions are a best-effort enhancement; ignore failures.
    }
  }

  void _applyTitleSuggestion(String title) {
    _titleController.text = title;
    _titleController.selection = TextSelection.collapsed(offset: title.length);
    setState(() {
      _suggestions = NoteSuggestions(
        folder: _suggestions.folder,
        tags: _suggestions.tags,
      );
    });
    _scheduleAutosave();
  }

  void _applyFolderSuggestion(FolderSuggestion folder) {
    setState(() {
      _selectedFolderId = folder.id;
      _suggestions = NoteSuggestions(
        title: _suggestions.title,
        tags: _suggestions.tags,
      );
    });
    _scheduleAutosave();
  }

  void _applyTagSuggestion(NoteTag tag) {
    setState(() {
      _selectedTags = [..._selectedTags, tag];
      _suggestions = NoteSuggestions(
        title: _suggestions.title,
        folder: _suggestions.folder,
        tags: _suggestions.tags
            .where((t) => t.id != tag.id)
            .toList(growable: false),
      );
    });
    _scheduleAutosave();
  }

  @override
  void dispose() {
    _autosaveTimer?.cancel();
    _assistTimer?.cancel();
    _titleController.dispose();
    _bodyController.dispose();
    _bodyFocusNode.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await _persist(closeAfterSave: true);
  }

  Future<void> _generateSummary() async {
    final body = _plainBody;
    if (body.isEmpty || _isGeneratingSummary) {
      return;
    }

    if (_activeNoteId == null) {
      await _persist(closeAfterSave: false);
    }

    if (_activeNoteId == null) {
      return;
    }

    setState(() {
      _isGeneratingSummary = true;
    });

    try {
      final summary = await ref.read(aiActionsProvider).generateSummary(
            noteId: _activeNoteId!,
            title: _titleController.text.trim().isEmpty
                ? null
                : _titleController.text.trim(),
            body: body,
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _summary = summary;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingSummary = false;
        });
      }
    }
  }

  Future<void> _persist({required bool closeAfterSave}) async {
    final body = _plainBody;
    if (body.isEmpty) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final title = _titleController.text.trim().isEmpty
          ? null
          : _titleController.text.trim();

      if (_activeNoteId == null) {
        _activeNoteId = await ref.read(notesActionsProvider).createNote(
              title: title,
              body: body,
              bodyDelta: _encodedBodyDelta,
              folderId: _selectedFolderId,
            );
      } else {
        await ref.read(notesActionsProvider).updateNote(
              id: _activeNoteId!,
              title: title,
              body: body,
              bodyDelta: _encodedBodyDelta,
              folderId: _selectedFolderId,
            );
      }

      await ref.read(notesActionsProvider).setNoteTags(
            noteId: _activeNoteId!,
            tagIds: _selectedTags.map((tag) => tag.id).toList(growable: false),
          );

      if (!mounted || !closeAfterSave) {
        return;
      }
      Navigator.of(context).pop(true);
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  String get _plainBody =>
      normalizeNoteBodyText(_bodyController.document.toPlainText());

  /// Picks an image, copies it into the attachment store, and inserts it as an
  /// inline block embed at the cursor. Guarded by the app-lock external-
  /// interaction pause so the picker doesn't trip the lock screen.
  Future<void> _insertImage() async {
    final appLock = ref.read(appLockControllerProvider.notifier);
    final store = ref.read(attachmentStoreProvider);
    final messenger = ScaffoldMessenger.of(context);
    try {
      appLock.beginExternalInteraction();
      final result = await FilePicker.platform.pickFiles(type: FileType.image);
      final path = result?.files.single.path;
      if (path == null) {
        return;
      }
      final fileName = await store.importImage(path);
      if (!mounted) {
        return;
      }
      final selection = _bodyController.selection;
      final index = selection.baseOffset < 0 ? 0 : selection.baseOffset;
      final length = selection.isValid ? selection.extentOffset - index : 0;
      _bodyController.replaceText(
        index,
        length < 0 ? 0 : length,
        BlockEmbed.image(fileName),
        TextSelection.collapsed(offset: index + 1),
      );
      setState(() {});
      _scheduleAutosave();
    } catch (_) {
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Could not insert that image.')),
        );
      }
    } finally {
      appLock.endExternalInteraction();
    }
  }

  String get _encodedBodyDelta =>
      jsonEncode(_bodyController.document.toDelta().toJson());

  Document _documentFromStoredContent({
    required String body,
    String? bodyDelta,
  }) {
    if (bodyDelta != null && bodyDelta.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(bodyDelta);
        if (decoded is List) {
          return Document.fromJson(decoded);
        }
      } catch (_) {}
    }

    final seed = body.trim().isEmpty ? '\n' : '${body.trim()}\n';
    return Document()..insert(0, seed);
  }

  Future<void> _showStyledColorPicker(
    QuillController controller,
    bool isBackground,
  ) async {
    final palette = isBackground ? _highlightPalette : _textColorPalette;
    final selected = await showModalBottomSheet<Color?>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final theme = Theme.of(context);
        final surfaces = theme.extension<AppSurfaces>()!;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Container(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: surfaces.cardBorder),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x22000000),
                    blurRadius: 28,
                    offset: Offset(0, 14),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isBackground
                                ? const [
                                    Color(0xFFC6AC8F),
                                    Color(0xFF5E503F),
                                  ]
                                : const [
                                    Color(0xFF22333B),
                                    Color(0xFF5E503F),
                                  ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Icon(
                          isBackground
                              ? Icons.format_color_fill_rounded
                              : Icons.palette_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isBackground
                                  ? 'Highlight style'
                                  : 'Text color',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: theme.colorScheme.onSurface,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isBackground
                                  ? 'Pick a soft highlight for the selected text.'
                                  : 'Choose a color that still reads beautifully on the page.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: surfaces.mutedText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final color in palette)
                        _ColorSwatchButton(
                          color: color,
                          onTap: () => Navigator.of(context).pop(color),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.of(context).pop(null),
                          icon: const Icon(Icons.format_color_reset_rounded),
                          label: const Text('Clear'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.check_rounded),
                          label: const Text('Done'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (!mounted) {
      return;
    }

    if (selected == null) {
      controller.formatSelection(
        isBackground
            ? const BackgroundAttribute(null)
            : const ColorAttribute(null),
      );
      return;
    }

    final hex = '#${selected.toARGB32().toRadixString(16).substring(2)}';
    controller.formatSelection(
      isBackground ? BackgroundAttribute(hex) : ColorAttribute(hex),
    );
  }

  Future<void> _toggleInlineSummary() async {
    setState(() {
      _showInlineSummary = !_showInlineSummary;
    });
    if (_showInlineSummary &&
        (_summary == null || _summary!.trim().isEmpty) &&
        !_isGeneratingSummary) {
      await _generateSummary();
    }
  }
  Future<void> _showFolderPickerSheet(List<NoteFolder> folders) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return _FolderPickerSheet(
          folders: folders,
          selectedFolderId: _selectedFolderId,
          onSelected: (value) {
            setState(() {
              _selectedFolderId = value;
            });
          },
        );
      },
    );
  }

  void _cycleAlignment() {
    final current = _currentAlignmentValue;
    final next = switch (current) {
      'center' => Attribute.rightAlignment,
      'right' => Attribute.justifyAlignment,
      'justify' => Attribute.leftAlignment,
      _ => Attribute.centerAlignment,
    };
    _bodyController.formatSelection(next);
    setState(() {});
  }

  void _cycleIndent() {
    final currentLevel = _currentIndentLevel;
    final nextAttribute = switch (currentLevel) {
      0 => Attribute.indentL1,
      1 => Attribute.indentL2,
      2 => Attribute.indentL3,
      _ => const IndentAttribute(level: null),
    };
    _bodyController.formatSelection(nextAttribute);
    setState(() {});
  }

  String? get _currentAlignmentValue {
    return _bodyController
        .getSelectionStyle()
        .attributes[Attribute.align.key]
        ?.value as String?;
  }

  int get _currentIndentLevel {
    final value = _bodyController
        .getSelectionStyle()
        .attributes[Attribute.indent.key]
        ?.value;
    return value is int ? value : 0;
  }

  IconData get _currentAlignmentIcon {
    return switch (_currentAlignmentValue) {
      'center' => Icons.format_align_center_rounded,
      'right' => Icons.format_align_right_rounded,
      'justify' => Icons.format_align_justify_rounded,
      _ => Icons.format_align_left_rounded,
    };
  }

  IconData get _currentIndentIcon {
    return switch (_currentIndentLevel) {
      1 => Icons.looks_one_rounded,
      2 => Icons.looks_two_rounded,
      3 => Icons.looks_3_rounded,
      _ => Icons.format_indent_increase_rounded,
    };
  }

  bool _hasInlineAttribute(Attribute attribute) {
    return _bodyController
            .getSelectionStyle()
            .attributes[attribute.key]
            ?.value !=
        null;
  }

  bool get _isBulletActive {
    return _bodyController
            .getSelectionStyle()
            .attributes[Attribute.list.key]
            ?.value ==
        Attribute.ul.value;
  }

  void _toggleInlineAttribute(Attribute attribute) {
    final isActive = _hasInlineAttribute(attribute);
    _bodyController.formatSelection(
      isActive ? Attribute.clone(attribute, null) : attribute,
    );
    setState(() {});
  }

  void _toggleBullets() {
    _bodyController.formatSelection(
      _isBulletActive ? Attribute.clone(Attribute.ul, null) : Attribute.ul,
    );
    setState(() {});
  }

  bool get _isChecklistActive {
    final value = _bodyController
        .getSelectionStyle()
        .attributes[Attribute.list.key]
        ?.value;
    return value == Attribute.unchecked.value ||
        value == Attribute.checked.value;
  }

  void _toggleChecklist() {
    _bodyController.formatSelection(
      _isChecklistActive
          ? Attribute.clone(Attribute.unchecked, null)
          : Attribute.unchecked,
    );
    setState(() {});
  }

  void _clearFormatting() {
    final clearAttributes = <Attribute>[
      Attribute.clone(Attribute.bold, null),
      Attribute.clone(Attribute.italic, null),
      Attribute.clone(Attribute.underline, null),
      Attribute.clone(Attribute.strikeThrough, null),
      Attribute.clone(Attribute.ul, null),
      Attribute.clone(Attribute.align, null),
      const IndentAttribute(level: null),
      const ColorAttribute(null),
      const BackgroundAttribute(null),
    ];
    for (final attribute in clearAttributes) {
      _bodyController.formatSelection(attribute);
    }
    setState(() {});
  }

  Future<void> _exportMarkdown() async {
    final title = _titleController.text.trim();
    await ref.read(markdownIoServiceProvider).shareNoteAsMarkdown(
          title: title.isEmpty ? null : title,
          deltaOps: _bodyController.document.toDelta().toJson(),
        );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    final isEditingExisting = _activeNoteId != null;
    final foldersAsync = ref.watch(noteFoldersProvider);
    final aiSnapshotAsync = _activeNoteId == null
        ? null
        : ref.watch(noteAiSnapshotProvider(_activeNoteId!));
    final effectiveSummary = (_summary != null && _summary!.trim().isNotEmpty)
        ? _summary!.trim()
        : aiSnapshotAsync?.valueOrNull?.summary;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditingExisting ? 'Edit note' : 'New note'),
        actions: [
          IconButton(
            onPressed: _exportMarkdown,
            icon: const Icon(Icons.ios_share_rounded),
            tooltip: 'Export as Markdown',
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
              onPressed: _isSaving ? null : _save,
              child: Text(_isSaving ? 'Saving...' : 'Save'),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (_isLoading) ...[
            const LinearProgressIndicator(),
            const SizedBox(height: 16),
          ],
          Row(
            children: [
              const Spacer(),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: Text(
                  _isSaving ? 'Saving...' : 'Saved',
                  key: ValueKey(_isSaving),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: _isSaving
                        ? theme.colorScheme.secondary
                        : theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _titleController,
            textInputAction: TextInputAction.next,
            style: theme.textTheme.titleLarge,
            decoration: const InputDecoration(
              labelText: 'Title',
              hintText: 'Optional title',
            ),
          ),
          const SizedBox(height: 16),
          foldersAsync.when(
            data: (folders) {
              NoteFolder? selectedFolder;
              for (final folder in folders) {
                if (folder.id == _selectedFolderId) {
                  selectedFolder = folder;
                  break;
                }
              }
              return Row(
                children: [
                  _EditorIconButton(
                    icon: Icons.auto_awesome_rounded,
                    tooltip: 'AI summary',
                    isBusy: _isGeneratingSummary,
                    onPressed: _toggleInlineSummary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _FolderTagButton(
                      label: selectedFolder?.name ?? 'No folder',
                      onTap: () => _showFolderPickerSheet(folders),
                    ),
                  ),
                ],
              );
            },
            error: (_, stackTrace) => const SizedBox.shrink(),
            loading: () => Row(
              children: [
                _EditorIconButton(
                  icon: Icons.auto_awesome_rounded,
                  tooltip: 'AI summary',
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final tag in _selectedTags)
                _TagChip(
                  tag: tag,
                  onRemove: () => setState(
                    () => _selectedTags =
                        _selectedTags.where((t) => t.id != tag.id).toList(),
                  ),
                ),
              _AddTagButton(onTap: _openTagPicker),
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            child: _suggestions.isEmpty
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (_suggestions.title != null)
                          _SuggestionChip(
                            icon: Icons.title_rounded,
                            label: 'Title: ${_suggestions.title}',
                            onTap: () =>
                                _applyTitleSuggestion(_suggestions.title!),
                          ),
                        if (_suggestions.folder != null)
                          _SuggestionChip(
                            icon: Icons.folder_open_rounded,
                            label: 'File in ${_suggestions.folder!.name}',
                            onTap: () =>
                                _applyFolderSuggestion(_suggestions.folder!),
                          ),
                        for (final tag in _suggestions.tags)
                          _SuggestionChip(
                            icon: Icons.label_rounded,
                            label: 'Tag: ${tag.name}',
                            onTap: () => _applyTagSuggestion(tag),
                          ),
                      ],
                    ),
                  ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            child: _showInlineSummary
                ? Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: _InlineSummaryPanel(
                      summary: effectiveSummary,
                      isGenerating: _isGeneratingSummary,
                      onRefresh: _generateSummary,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  setState(() {
                    _showFormattingToolbar = !_showFormattingToolbar;
                  });
                },
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: theme.extension<AppSurfaces>()!.glassHighlight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.extension<AppSurfaces>()!.glassBorder,
                    ),
                  ),
                  child: Icon(
                    _showFormattingToolbar
                        ? Icons.close_rounded
                        : Icons.draw_rounded,
                    size: 18,
                    color: theme.extension<AppSurfaces>()!.accent,
                  ),
                ),
              ),
            ],
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeOutCubic,
            child: _showFormattingToolbar
                ? Padding(
                    key: const ValueKey('formatting-toolbar'),
                    padding: const EdgeInsets.only(top: 12),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _ToolbarActionButton(
                            icon: Icons.format_bold_rounded,
                            tooltip: 'Bold',
                            isSelected: _hasInlineAttribute(Attribute.bold),
                            onTap: () => _toggleInlineAttribute(Attribute.bold),
                          ),
                          const SizedBox(width: 10),
                          _ToolbarActionButton(
                            icon: Icons.format_italic_rounded,
                            tooltip: 'Italic',
                            isSelected: _hasInlineAttribute(Attribute.italic),
                            onTap: () =>
                                _toggleInlineAttribute(Attribute.italic),
                          ),
                          const SizedBox(width: 10),
                          _ToolbarActionButton(
                            icon: Icons.format_underline_rounded,
                            tooltip: 'Underline',
                            isSelected:
                                _hasInlineAttribute(Attribute.underline),
                            onTap: () =>
                                _toggleInlineAttribute(Attribute.underline),
                          ),
                          const SizedBox(width: 10),
                          _ToolbarActionButton(
                            icon: Icons.format_strikethrough_rounded,
                            tooltip: 'Strikethrough',
                            isSelected:
                                _hasInlineAttribute(Attribute.strikeThrough),
                            onTap: () => _toggleInlineAttribute(
                              Attribute.strikeThrough,
                            ),
                          ),
                          const SizedBox(width: 10),
                          _ToolbarActionButton(
                            icon: Icons.format_list_bulleted_rounded,
                            tooltip: 'Bullets',
                            isSelected: _isBulletActive,
                            onTap: _toggleBullets,
                          ),
                          const SizedBox(width: 10),
                          _ToolbarActionButton(
                            icon: Icons.checklist_rounded,
                            tooltip: 'Checklist',
                            isSelected: _isChecklistActive,
                            onTap: _toggleChecklist,
                          ),
                          const SizedBox(width: 10),
                          _ToolbarActionButton(
                            icon: Icons.image_rounded,
                            tooltip: 'Insert image',
                            onTap: _insertImage,
                          ),
                          const SizedBox(width: 10),
                          _ToolbarActionButton(
                            icon: Icons.palette_rounded,
                            tooltip: 'Text color',
                            onTap: () =>
                                _showStyledColorPicker(_bodyController, false),
                          ),
                          const SizedBox(width: 10),
                          _ToolbarActionButton(
                            icon: Icons.format_color_fill_rounded,
                            tooltip: 'Highlight',
                            onTap: () =>
                                _showStyledColorPicker(_bodyController, true),
                          ),
                          const SizedBox(width: 10),
                          _ToolbarCycleButton(
                            icon: _currentAlignmentIcon,
                            tooltip: 'Cycle alignment',
                            onTap: _cycleAlignment,
                          ),
                          const SizedBox(width: 10),
                          _ToolbarCycleButton(
                            icon: _currentIndentIcon,
                            tooltip: 'Cycle indent',
                            onTap: _cycleIndent,
                          ),
                          const SizedBox(width: 10),
                          _ToolbarActionButton(
                            icon: Icons.format_clear_rounded,
                            tooltip: 'Clear formatting',
                            onTap: _clearFormatting,
                          ),
                        ],
                      ),
                    ),
                  )
                : const SizedBox.shrink(
                    key: ValueKey('formatting-toolbar-hidden'),
                  ),
          ),
          const SizedBox(height: 12),
          GlassSurface(
            borderRadius: 20,
            blur: false,
            fillColor: surfaces.cardFill,
            borderColor: surfaces.cardBorder,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: QuillEditor.basic(
              controller: _bodyController,
              focusNode: _bodyFocusNode,
              config: QuillEditorConfig(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                placeholder: 'Start from here',
                autoFocus: true,
                scrollable: false,
                embedBuilders: [
                  LocalImageEmbedBuilder(ref.read(attachmentStoreProvider)),
                ],
              ),
            ),
          ),
          if (_related.isNotEmpty) ...[
            const SizedBox(height: 26),
            Row(
              children: [
                Icon(Icons.hub_outlined, size: 16, color: surfaces.accent),
                const SizedBox(width: 8),
                Text(
                  'Related notes',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: surfaces.mutedText,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (final note in _related)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _RelatedNoteCard(
                  note: note,
                  onTap: () => _openRelated(note.id),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _ColorSwatchButton extends StatelessWidget {
  const _ColorSwatchButton({
    required this.color,
    required this.onTap,
  });

  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.92),
              width: 2,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1F6D43E0),
                blurRadius: 14,
                offset: Offset(0, 6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolbarCycleButton extends StatelessWidget {
  const _ToolbarCycleButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: surfaces.glassHighlight,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: surfaces.cardBorder),
          ),
          child: Icon(
            icon,
            size: 18,
            color: surfaces.onGlass,
          ),
        ),
      ),
    );
  }
}

class _ToolbarActionButton extends StatelessWidget {
  const _ToolbarActionButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.isSelected = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    final background =
        isSelected ? theme.colorScheme.primary : surfaces.glassHighlight;
    final foreground =
        isSelected ? theme.colorScheme.onPrimary : surfaces.onGlass;

    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: surfaces.cardBorder),
            boxShadow: isSelected
                ? const [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Icon(
            icon,
            size: 18,
            color: foreground,
          ),
        ),
      ),
    );
  }
}

class _EditorIconButton extends StatefulWidget {
  const _EditorIconButton({
    required this.icon,
    required this.tooltip,
    this.isBusy = false,
    this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final bool isBusy;
  final VoidCallback? onPressed;

  @override
  State<_EditorIconButton> createState() => _EditorIconButtonState();
}

class _EditorIconButtonState extends State<_EditorIconButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    if (widget.isBusy) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _EditorIconButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isBusy == oldWidget.isBusy) {
      return;
    }
    if (widget.isBusy) {
      _controller.repeat(reverse: true);
    } else {
      _controller
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_controller.value);
        final scale = widget.isBusy ? 1 + (t * 0.05) : 1.0;
        final iconShift = widget.isBusy ? (t * 0.12) - 0.06 : 0.0;
        final borderColor = widget.isBusy
            ? Color.lerp(surfaces.glassBorder, surfaces.accent, 0.4 + t * 0.4)!
            : surfaces.glassBorder;

        return Transform.scale(
          scale: scale,
          child: Tooltip(
            message: widget.tooltip,
            child: GlassSurface(
              borderRadius: 12,
              blur: false,
              fillColor: surfaces.glassHighlight,
              borderColor: borderColor,
              onTap: widget.onPressed,
              child: SizedBox(
                width: 38,
                height: 38,
                child: Center(
                  child: Transform.rotate(
                    angle: iconShift,
                    child: Icon(
                      widget.icon,
                      size: 18,
                      color: surfaces.accent,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FolderTagButton extends StatelessWidget {
  const _FolderTagButton({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    return GlassSurface(
      borderRadius: 999,
      blur: false,
      fillColor: surfaces.glassHighlight,
      borderColor: surfaces.cardBorder,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.folder_open_outlined,
            size: 16,
            color: surfaces.accent,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelLarge?.copyWith(
                    color: surfaces.onGlass,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.expand_more_rounded,
            size: 18,
            color: surfaces.onGlass,
          ),
        ],
      ),
    );
  }
}

/// A tappable pill offering an on-device suggestion (title or folder). Tapping
/// applies it; the suggestion is otherwise ignorable, keeping it non-intrusive.
class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    return GlassSurface(
      borderRadius: 999,
      blur: false,
      fillColor: surfaces.glassHighlight,
      borderColor: surfaces.accent.withValues(alpha: 0.5),
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome_rounded, size: 14, color: surfaces.accent),
          const SizedBox(width: 6),
          Icon(icon, size: 15, color: surfaces.onGlass),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelLarge?.copyWith(
                color: surfaces.onGlass,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Icon(Icons.add_rounded, size: 16, color: surfaces.accent),
        ],
      ),
    );
  }
}

/// A tappable "See also" entry linking to a semantically related note.
class _RelatedNoteCard extends StatelessWidget {
  const _RelatedNoteCard({required this.note, required this.onTap});

  final NotePreview note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    final preview = note.body.replaceAll(RegExp(r'\s+'), ' ').trim();
    return GlassSurface(
      borderRadius: 16,
      blur: false,
      fillColor: surfaces.cardFill,
      borderColor: surfaces.cardBorder,
      onTap: onTap,
      padding: const EdgeInsets.all(13),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  note.title.trim().isEmpty ? 'Untitled note' : note.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: surfaces.onGlass,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (preview.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    preview,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: surfaces.mutedText,
                      height: 1.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right_rounded, color: surfaces.mutedText, size: 20),
        ],
      ),
    );
  }
}

Color _tagColor(String hex) {
  var value = hex.replaceFirst('#', '');
  if (value.length == 6) {
    value = 'FF$value';
  }
  return Color(int.tryParse(value, radix: 16) ?? 0xFF607D8B);
}

/// A removable tag chip shown on a note in the editor.
class _TagChip extends StatelessWidget {
  const _TagChip({required this.tag, required this.onRemove});

  final NoteTag tag;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    final color = _tagColor(tag.colorHex);
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.label_rounded, size: 13, color: color),
          const SizedBox(width: 6),
          Text(
            tag.name,
            style: theme.textTheme.labelMedium?.copyWith(
              color: surfaces.onGlass,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 2),
          InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: onRemove,
            child: Icon(Icons.close_rounded, size: 15, color: surfaces.mutedText),
          ),
        ],
      ),
    );
  }
}

class _AddTagButton extends StatelessWidget {
  const _AddTagButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: surfaces.glassBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_rounded, size: 15, color: surfaces.accent),
            const SizedBox(width: 4),
            Text(
              'Tag',
              style: theme.textTheme.labelMedium?.copyWith(
                color: surfaces.mutedText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A bottom sheet for choosing existing tags and creating new ones. Returns the
/// resulting selected-tag list on close.
class _TagPickerSheet extends ConsumerStatefulWidget {
  const _TagPickerSheet({required this.selected});

  final List<NoteTag> selected;

  @override
  ConsumerState<_TagPickerSheet> createState() => _TagPickerSheetState();
}

class _TagPickerSheetState extends ConsumerState<_TagPickerSheet> {
  late final Map<String, NoteTag> _selected;
  final _createController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selected = {for (final tag in widget.selected) tag.id: tag};
  }

  @override
  void dispose() {
    _createController.dispose();
    super.dispose();
  }

  Future<void> _createTag() async {
    final name = _createController.text.trim();
    if (name.isEmpty) {
      return;
    }
    final tag = await ref.read(notesActionsProvider).getOrCreateTag(name);
    if (!mounted) {
      return;
    }
    setState(() {
      _selected[tag.id] = tag;
      _createController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    final allTags = ref.watch(noteTagsProvider);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: surfaces.cardBorder),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tags', style: theme.textTheme.titleLarge),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _createController,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _createTag(),
                      decoration: const InputDecoration(
                        hintText: 'Create a new tag',
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _createTag,
                    icon: Icon(Icons.add_rounded, color: surfaces.accent),
                    tooltip: 'Create tag',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              allTags.when(
                data: (tags) {
                  final combined = <String, NoteTag>{
                    for (final tag in tags) tag.id: tag,
                    ..._selected,
                  };
                  if (combined.isEmpty) {
                    return Text(
                      'No tags yet. Create one above.',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: surfaces.mutedText),
                    );
                  }
                  return ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 260),
                    child: SingleChildScrollView(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final tag in combined.values)
                            FilterChip(
                              label: Text(tag.name),
                              selected: _selected.containsKey(tag.id),
                              onSelected: (on) => setState(() {
                                if (on) {
                                  _selected[tag.id] = tag;
                                } else {
                                  _selected.remove(tag.id);
                                }
                              }),
                            ),
                        ],
                      ),
                    ),
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.all(8),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, _) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: () => Navigator.of(context)
                      .pop(_selected.values.toList(growable: false)),
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InlineSummaryPanel extends StatelessWidget {
  const _InlineSummaryPanel({
    required this.summary,
    required this.isGenerating,
    required this.onRefresh,
  });

  final String? summary;
  final bool isGenerating;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaces.cardFill,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: surfaces.cardBorder,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _ModelDownloadPrompt(),
          Align(
            alignment: Alignment.centerRight,
            child: IconButton.filledTonal(
              onPressed: isGenerating ? null : onRefresh,
              tooltip: 'Refresh summary',
              icon: isGenerating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded),
            ),
          ),
          const SizedBox(height: 12),
          SelectableText(
            summary?.trim().isNotEmpty == true
                ? summary!.trim()
                : 'No summary yet.',
            style: theme.textTheme.bodyLarge?.copyWith(
              height: 1.45,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

/// Prompt shown inside the AI summary panel when the optional on-device models
/// have not been downloaded yet. Renders nothing once the models are present.
class _ModelDownloadPrompt extends ConsumerWidget {
  const _ModelDownloadPrompt();

  String _formatMb(int bytes) {
    final mb = bytes / (1024 * 1024);
    return '${mb.toStringAsFixed(0)} MB';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final download = ref.watch(modelDownloadControllerProvider);
    final needsDownloadAsync = ref.watch(modelsNeedDownloadProvider);

    // Once the download completes the models are present, so dismiss the prompt
    // regardless of the (possibly still-refreshing) needs-download flag.
    if (download.status == ModelDownloadStatus.completed) {
      return const SizedBox.shrink();
    }

    // While actively downloading or after a failure, keep the panel visible so
    // the user sees progress/errors even before the needs-download flag flips.
    final isBusyOrFailed = download.status == ModelDownloadStatus.downloading ||
        download.status == ModelDownloadStatus.failed;
    final needsDownload = needsDownloadAsync.valueOrNull ?? false;
    if (!needsDownload && !isBusyOrFailed) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    final controller = ref.read(modelDownloadControllerProvider.notifier);
    final fraction = download.fraction;

    Widget body;
    switch (download.status) {
      case ModelDownloadStatus.downloading:
        body = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              fraction == null
                  ? 'Downloading AI models…'
                  : 'Downloading AI models… ${(fraction * 100).toStringAsFixed(0)}%'
                      ' (${_formatMb(download.received)} / ${_formatMb(download.total)})',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurface),
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(value: fraction),
            ),
          ],
        );
        break;
      case ModelDownloadStatus.failed:
        body = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Model download failed. Check your connection and try again.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.error),
            ),
            const SizedBox(height: 10),
            FilledButton.tonalIcon(
              onPressed: controller.downloadModels,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry download'),
            ),
          ],
        );
        break;
      default:
        body = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'On-device AI models power summaries and semantic search. They '
              'download once and then run fully offline.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurface),
            ),
            const SizedBox(height: 10),
            FilledButton.tonalIcon(
              onPressed: controller.downloadModels,
              icon: const Icon(Icons.download_rounded),
              label: const Text('Download AI models'),
            ),
          ],
        );
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surfaces.glassHighlight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: surfaces.cardBorder),
      ),
      child: body,
    );
  }
}

class _FolderPickerSheet extends StatelessWidget {
  const _FolderPickerSheet({
    required this.folders,
    required this.selectedFolderId,
    required this.onSelected,
  });

  final List<NoteFolder> folders;
  final String? selectedFolderId;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: surfaces.cardBorder),
            boxShadow: const [
              BoxShadow(
                color: Color(0x18000000),
                blurRadius: 20,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Move to folder',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _FolderChoiceTag(
                    label: 'No folder',
                    selected: selectedFolderId == null,
                    onTap: () {
                      onSelected(null);
                      Navigator.of(context).pop();
                    },
                  ),
                  for (final folder in folders)
                    _FolderChoiceTag(
                      label: folder.name,
                      selected: selectedFolderId == folder.id,
                      onTap: () {
                        onSelected(folder.id);
                        Navigator.of(context).pop();
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FolderChoiceTag extends StatelessWidget {
  const _FolderChoiceTag({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? theme.colorScheme.primary
                : surfaces.glassHighlight,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: selected
                      ? theme.colorScheme.onPrimary
                      : surfaces.onGlass,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      ),
    );
  }
}
