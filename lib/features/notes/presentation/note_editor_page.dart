import 'dart:async';
import 'dart:convert';

import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai/providers/ai_actions.dart';
import '../../ai/providers/ai_providers.dart';
import '../domain/note_document.dart';
import '../domain/note_folder.dart';
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
  bool _showFormattingToolbar = false;
  bool _showInlineSummary = false;
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                      color: const Color(0xFFEAE0D5),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ],
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
                  child: Icon(
                    _showFormattingToolbar
                        ? Icons.close_rounded
                        : Icons.draw_rounded,
                    size: 18,
                    color: Colors.white,
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
          QuillEditor.basic(
            controller: _bodyController,
            focusNode: _bodyFocusNode,
            config: const QuillEditorConfig(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              placeholder: 'Start from here',
              autoFocus: true,
              scrollable: false,
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
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFFF2E8DC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFC6AC8F)),
          ),
          child: Icon(
            icon,
            size: 18,
            color: const Color(0xFF22333B),
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
    final background =
        isSelected ? const Color(0xFF5E503F) : const Color(0xFFF2E8DC);
    final foreground =
        isSelected ? const Color(0xFFEAE0D5) : const Color(0xFF22333B);

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
            border: Border.all(color: const Color(0xFFC6AC8F)),
            boxShadow: isSelected
                ? const [
                    BoxShadow(
                      color: Color(0x445E503F),
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
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_controller.value);
        final scale = widget.isBusy ? 1 + (t * 0.05) : 1.0;
        final glowOpacity = widget.isBusy ? 0.18 + (t * 0.12) : 0.0;
        final iconShift = widget.isBusy ? (t * 0.12) - 0.06 : 0.0;

        return Transform.scale(
          scale: scale,
          child: Tooltip(
            message: widget.tooltip,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: widget.onPressed,
              child: Container(
                width: 38,
                height: 38,
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
                  boxShadow: [
                    BoxShadow(
                      color: Color.fromRGBO(34, 51, 59, 0.2 + glowOpacity),
                      blurRadius: widget.isBusy ? 18 : 14,
                      spreadRadius: widget.isBusy ? 1.5 : 0,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (widget.isBusy)
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Color.fromRGBO(234, 224, 213, 0.28 + (t * 0.18)),
                            ),
                          ),
                        ),
                      ),
                    Transform.rotate(
                      angle: iconShift,
                      child: Icon(
                        widget.icon,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                  ],
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF5E503F),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.folder_open_outlined,
                size: 16,
                color: Color(0xFFEAE0D5),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: const Color(0xFFEAE0D5),
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.expand_more_rounded,
                size: 18,
                color: Color(0xFFEAE0D5),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFF6F9FB),
            Color(0xFFE8EEF2),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFD5E0E7),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1222333B),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonalIcon(
              onPressed: isGenerating ? null : onRefresh,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(isGenerating ? 'Refreshing...' : 'Refresh'),
            ),
          ),
          const SizedBox(height: 12),
          SelectableText(
            summary?.trim().isNotEmpty == true
                ? summary!.trim()
                : 'No summary yet.',
            style: theme.textTheme.bodyLarge?.copyWith(
              height: 1.45,
              color: const Color(0xFF22333B),
            ),
          ),
        ],
      ),
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

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBF7),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFFC6AC8F)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1822333B),
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
                  color: const Color(0xFF22333B),
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF5E503F) : const Color(0xFFEAE0D5),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: selected ? const Color(0xFFEAE0D5) : const Color(0xFF22333B),
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      ),
    );
  }
}
