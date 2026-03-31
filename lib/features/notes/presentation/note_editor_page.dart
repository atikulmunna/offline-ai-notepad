import 'dart:async';
import 'dart:convert';

import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai/domain/embedding_status.dart';
import '../../ai/domain/ai_runtime_status.dart';
import '../../ai/domain/note_ai_snapshot.dart';
import '../../ai/providers/ai_actions.dart';
import '../../ai/providers/ai_providers.dart';
import '../domain/note_document.dart';
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
  bool _didLoadInitialData = false;
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isGeneratingSummary = false;
  String? _activeNoteId;
  String? _selectedFolderId;
  String? _summary;

  @override
  void initState() {
    super.initState();
    _activeNoteId = widget.noteId;
    _titleController.addListener(_scheduleAutosave);
    _bodyController.addListener(_scheduleAutosave);
    _loadInitialNote();
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

  @override
  void dispose() {
    _autosaveTimer?.cancel();
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
      _bodyController.document.toPlainText().replaceAll('\u00a0', ' ').trim();

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
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Container(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFFFFBF7),
                    Color(0xFFEAE0D5),
                    Color(0xFFC6AC8F),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: const Color(0xFFC6AC8F)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x2222333B),
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
                                color: const Color(0xFF0A0908),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isBackground
                                  ? 'Pick a soft highlight for the selected text.'
                                  : 'Choose a color that still reads beautifully on the page.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: const Color(0xFF22333B),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditingExisting = _activeNoteId != null;
    final foldersAsync = ref.watch(noteFoldersProvider);
    final runtimeStatusAsync = ref.watch(aiRuntimeStatusProvider);
    final aiSnapshotAsync = _activeNoteId == null
        ? null
        : ref.watch(noteAiSnapshotProvider(_activeNoteId!));
    final toolbarIconTheme = QuillIconTheme(
      iconButtonUnselectedData: IconButtonData(
        color: const Color(0xFF22333B),
        style: IconButton.styleFrom(
          backgroundColor: const Color(0xFFF2E8DC),
          foregroundColor: const Color(0xFF22333B),
          hoverColor: const Color(0xFFE5D6C3),
          highlightColor: const Color(0xFFD9C4AA),
          padding: const EdgeInsets.all(11),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFC6AC8F)),
          ),
        ),
      ),
      iconButtonSelectedData: IconButtonData(
        color: const Color(0xFFEAE0D5),
        style: IconButton.styleFrom(
          backgroundColor: const Color(0xFF5E503F),
          foregroundColor: const Color(0xFFEAE0D5),
          hoverColor: const Color(0xFF4F4334),
          highlightColor: const Color(0xFF3E3429),
          padding: const EdgeInsets.all(11),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          side: const BorderSide(color: Color(0xFFC6AC8F)),
          shadowColor: const Color(0x445E503F),
          elevation: 4,
        ),
      ),
    );
    final toolbarConfig = QuillSimpleToolbarConfig(
      showFontFamily: false,
      showFontSize: false,
      showBoldButton: true,
      showItalicButton: true,
      showUnderLineButton: true,
      showStrikeThrough: true,
      showSubscript: false,
      showSuperscript: false,
      showHeaderStyle: false,
      showListNumbers: false,
      showListBullets: false,
      showListCheck: false,
      showCodeBlock: false,
      showQuote: false,
      showIndent: false,
      showLink: false,
      showSearchButton: false,
      showUndo: false,
      showRedo: false,
      showDividers: false,
      showSmallButton: false,
      showInlineCode: false,
      showDirection: false,
      multiRowsDisplay: true,
      toolbarSize: 38,
      toolbarSectionSpacing: 10,
      toolbarRunSpacing: 10,
      color: const Color(0x00000000),
      iconTheme: toolbarIconTheme,
      buttonOptions: QuillSimpleToolbarButtonOptions(
        base: QuillToolbarBaseButtonOptions(
          iconSize: 18,
          iconButtonFactor: 1.15,
          iconTheme: toolbarIconTheme,
        ),
        color: QuillToolbarColorButtonOptions(
          iconTheme: toolbarIconTheme,
          customOnPressedCallback: _showStyledColorPicker,
        ),
        backgroundColor: QuillToolbarColorButtonOptions(
          iconTheme: toolbarIconTheme,
          customOnPressedCallback: _showStyledColorPicker,
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditingExisting ? 'Edit note' : 'New note'),
        actions: [
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
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, (1 - value) * 12),
                  child: child,
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFEAE0D5),
                    Color(0xFFF6EEE6),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: const Color(0xFFC6AC8F)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1422333B),
                    blurRadius: 22,
                    offset: Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          isEditingExisting ? 'Editing' : 'Draft',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
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
                  const SizedBox(height: 18),
                  Text(
                    isEditingExisting ? 'Keep writing' : 'Capture a note',
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isEditingExisting
                        ? 'Changes save locally as you go.'
                        : 'A clean space for quick capture.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          _AiWorkspaceCard(
            summary: _summary,
            snapshotAsync: aiSnapshotAsync,
            runtimeStatusAsync: runtimeStatusAsync,
            isGeneratingSummary: _isGeneratingSummary,
            onGenerateSummary: _generateSummary,
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
              return DropdownButtonFormField<String?>(
                initialValue:
                    folders.any((folder) => folder.id == _selectedFolderId)
                    ? _selectedFolderId
                    : null,
                decoration: const InputDecoration(
                  labelText: 'Folder',
                  hintText: 'Choose a folder',
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('No folder'),
                  ),
                  ...folders.map(
                    (folder) => DropdownMenuItem<String?>(
                      value: folder.id,
                      child: Text(folder.name),
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedFolderId = value;
                  });
                },
              );
            },
            error: (_, stackTrace) => const SizedBox.shrink(),
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: LinearProgressIndicator(),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white,
                  const Color(0xFFF2E8DC),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFC6AC8F)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1222333B),
                  blurRadius: 18,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Body',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.fromLTRB(
                    12,
                    12,
                    12,
                    10,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.98),
                        const Color(0xFFF6EEE6),
                        const Color(0xFFEAE0D5),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFC6AC8F)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1522333B),
                        blurRadius: 18,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF22333B),
                                  Color(0xFF5E503F),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x3322333B),
                                  blurRadius: 14,
                                  offset: Offset(0, 6),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.draw_rounded,
                              size: 18,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Formatting',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: const Color(0xFF0A0908),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.54),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFFC6AC8F),
                          ),
                        ),
                        padding: const EdgeInsets.all(8),
                        child: QuillSimpleToolbar(
                          controller: _bodyController,
                          config: toolbarConfig,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  constraints: const BoxConstraints(
                    minHeight: 260,
                    maxHeight: 420,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBF7),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFC6AC8F)),
                  ),
                  child: QuillEditor.basic(
                    controller: _bodyController,
                    focusNode: _bodyFocusNode,
                    config: QuillEditorConfig(
                      padding: const EdgeInsets.all(12),
                      placeholder: 'Write your note here...',
                    ),
                  ),
                ),
              ],
            ),
          ),
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

class _AiWorkspaceCard extends StatelessWidget {
  const _AiWorkspaceCard({
    required this.summary,
    required this.snapshotAsync,
    required this.runtimeStatusAsync,
    required this.isGeneratingSummary,
    required this.onGenerateSummary,
  });

  final String? summary;
  final AsyncValue<NoteAiSnapshot?>? snapshotAsync;
  final AsyncValue<AiRuntimeStatus> runtimeStatusAsync;
  final bool isGeneratingSummary;
  final VoidCallback onGenerateSummary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final snapshot = snapshotAsync?.valueOrNull;
    final effectiveSummary = (summary != null && summary!.trim().isNotEmpty)
        ? summary!.trim()
        : snapshot?.summary;
    final status = snapshot?.embeddingStatus ?? EmbeddingStatus.missing;
    final summaryStatusLabel = switch (status) {
      EmbeddingStatus.indexed => 'Summary and note index are ready.',
      EmbeddingStatus.queued => 'Summary is ready. Search index is updating.',
      EmbeddingStatus.failed => 'Summary is ready. AI indexing needs attention.',
      EmbeddingStatus.missing => effectiveSummary == null
          ? 'Generate a local summary when you want a quick recap.'
          : 'Summary is ready.',
    };
    final summaryStatusIcon = switch (status) {
      EmbeddingStatus.indexed => Icons.check_circle_outline_rounded,
      EmbeddingStatus.queued => Icons.schedule_rounded,
      EmbeddingStatus.failed => Icons.error_outline_rounded,
      EmbeddingStatus.missing => effectiveSummary == null
          ? Icons.auto_awesome_outlined
          : Icons.check_circle_outline_rounded,
    };
    final summaryStatusColor = switch (status) {
      EmbeddingStatus.indexed => const Color(0xFF5E503F),
      EmbeddingStatus.queued => const Color(0xFF22333B),
      EmbeddingStatus.failed => const Color(0xFF8A7259),
      EmbeddingStatus.missing => effectiveSummary == null
          ? const Color(0xFF22333B)
          : const Color(0xFF5E503F),
    };

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [
            Color(0xFFEAE0D5),
            Color(0xFFF6EEE6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: const Color(0xFFC6AC8F)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1022333B),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'AI Summary',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: isGeneratingSummary ? null : onGenerateSummary,
                icon: const Icon(Icons.auto_awesome_rounded),
                label: Text(
                  isGeneratingSummary ? 'Generating...' : 'Refresh',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'A short local recap of the current note.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF22333B),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.78),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFFC6AC8F),
              ),
            ),
            child: Text(
              effectiveSummary ??
                  'No summary yet.',
              style: theme.textTheme.bodyLarge?.copyWith(
                height: 1.45,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.62),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFC6AC8F)),
            ),
            child: Row(
              children: [
                Icon(
                  summaryStatusIcon,
                  size: 18,
                  color: summaryStatusColor,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    summaryStatusLabel,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: summaryStatusColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
