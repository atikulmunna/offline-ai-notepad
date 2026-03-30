import 'dart:async';

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
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
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
    _bodyController.text = note.body;
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
    super.dispose();
  }

  Future<void> _save() async {
    await _persist(closeAfterSave: true);
  }

  Future<void> _generateSummary() async {
    final body = _bodyController.text.trim();
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
    final body = _bodyController.text.trim();
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
              folderId: _selectedFolderId,
            );
      } else {
        await ref.read(notesActionsProvider).updateNote(
              id: _activeNoteId!,
              title: title,
              body: body,
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditingExisting = _activeNoteId != null;
    final foldersAsync = ref.watch(noteFoldersProvider);
    final runtimeStatusAsync = ref.watch(aiRuntimeStatusProvider);
    final aiSnapshotAsync = _activeNoteId == null
        ? null
        : ref.watch(noteAiSnapshotProvider(_activeNoteId!));

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
                    Color(0xFFFFF0E9),
                    Color(0xFFEFF9F5),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
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
                          isEditingExisting ? 'Autosave active' : 'Fresh note',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                      const Spacer(),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: Text(
                          _isSaving ? 'Saving...' : 'Saved locally',
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
                        ? 'Autosave is active while you edit. This is our first pass at a persistent plain-text note workflow.'
                        : 'A bright, distraction-light editor for fast capture. We will layer richer workflows on top of this foundation.',
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
          TextField(
            controller: _bodyController,
            minLines: 12,
            maxLines: 20,
            textCapitalization: TextCapitalization.sentences,
            style: theme.textTheme.bodyLarge,
            decoration: const InputDecoration(
              labelText: 'Body',
              hintText: 'Write your note here...',
              alignLabelWithHint: true,
            ),
          ),
        ],
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
    final runtimeStatus = runtimeStatusAsync.valueOrNull;
    final effectiveSummary = (summary != null && summary!.trim().isNotEmpty)
        ? summary!.trim()
        : snapshot?.summary;
    final status = snapshot?.embeddingStatus ?? EmbeddingStatus.missing;
    final modelVersion = snapshot?.modelVersion ?? runtimeStatus?.modelVersion;
    final runtimeReady = runtimeStatus?.isReady ?? false;
    final packagedRuntimeReady = runtimeStatus?.packagedRuntimeReady ?? false;
    final nativeBackendLinked = runtimeStatus?.nativeBackendLinked ?? false;
    final nativeSessionReady = runtimeStatus?.nativeSessionReady ?? false;
    final contractMatchesManifest =
        runtimeStatus?.contractMatchesManifest ?? false;
    final isLocalOnly = runtimeStatus?.isLocalOnly ?? true;
    final runtimeLabel = runtimeStatus?.runtimeLabel ?? 'Loading runtime';
    final packagedModels = runtimeStatus == null
        ? null
        : '${runtimeStatus.packagedModels}/${runtimeStatus.totalModels} planned';
    final installedModels = runtimeStatus == null
        ? null
        : '${runtimeStatus.installedModels}/${runtimeStatus.totalModels} installed';
    final stagedModels = runtimeStatus == null
        ? null
        : '${runtimeStatus.stagedModels}/${runtimeStatus.totalModels} staged';
    final runtimeProfile = runtimeStatus?.runtimeProfile;
    final summaryModelId = runtimeStatus?.summaryModelId;
    final embeddingModelId = runtimeStatus?.embeddingModelId;
    final runtimeDirectory = runtimeStatus?.runtimeDirectory;
    final capabilityMessage = runtimeStatus?.capabilityMessage;
    final sessionMessage = runtimeStatus?.sessionMessage;
    final contractMessage = runtimeStatus?.contractMessage;
    final actualInputNames = runtimeStatus?.actualInputNames ?? const <String>[];
    final actualOutputNames =
        runtimeStatus?.actualOutputNames ?? const <String>[];
    final tokenizationMessage = runtimeStatus?.tokenizationMessage;
    final previewInputIds = runtimeStatus?.previewInputIds ?? const <int>[];
    final previewAttentionMask =
        runtimeStatus?.previewAttentionMask ?? const <int>[];
    final previewTokenizerLoaded =
        runtimeStatus?.previewTokenizerLoaded ?? false;
    final tokenizerMessage = runtimeStatus?.tokenizerMessage;
    final tokenizerVocabSize = runtimeStatus?.tokenizerVocabSize ?? 0;
    final tokenizerModelType = runtimeStatus?.tokenizerModelType;
    final tokenizerPreTokenizerType = runtimeStatus?.tokenizerPreTokenizerType;
    final tokenizerNormalizerType = runtimeStatus?.tokenizerNormalizerType;
    final runPreviewMessage = runtimeStatus?.runPreviewMessage;
    final previewOutputNames =
        runtimeStatus?.previewOutputNames ?? const <String>[];
    final previewOutputShapes =
        runtimeStatus?.previewOutputShapes ?? const <String>[];
    final previewOutputValueSample =
        runtimeStatus?.previewOutputValueSample ?? const <String>[];
    final outputInterpretationMessage =
        runtimeStatus?.outputInterpretationMessage;
    final decoderType = runtimeStatus?.decoderType;
    final canAttemptDecode = runtimeStatus?.canAttemptDecode ?? false;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [
            Color(0xFFE8F6FF),
            Color(0xFFFFF4E8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: const Color(0xFFD8E6EE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 12,
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
                  'Local AI preview',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: isGeneratingSummary ? null : onGenerateSummary,
                icon: const Icon(Icons.auto_awesome_rounded),
                label: Text(
                  isGeneratingSummary ? 'Generating...' : 'Generate summary',
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Summary',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            effectiveSummary ??
                'No summary yet. Generate one locally to test the AI workflow before we plug in the real on-device model runtime.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              Chip(
                avatar: const Icon(Icons.hub_outlined, size: 16),
                label: Text(status.label),
              ),
              Chip(
                avatar: Icon(
                  runtimeReady ? Icons.offline_bolt_rounded : Icons.error_outline,
                  size: 16,
                ),
                label: Text(runtimeLabel),
              ),
              Chip(
                avatar: const Icon(Icons.memory_rounded, size: 16),
                label: Text(modelVersion ?? 'runtime pending'),
              ),
              if (isLocalOnly)
                const Chip(
                  avatar: Icon(Icons.cloud_off_rounded, size: 16),
                  label: Text('On-device only'),
                ),
              if (!runtimeReady)
                const Chip(
                  avatar: Icon(Icons.warning_amber_rounded, size: 16),
                  label: Text('Runtime unavailable'),
                ),
              if (packagedRuntimeReady)
                const Chip(
                  avatar: Icon(Icons.check_circle_outline, size: 16),
                  label: Text('Packaged models ready'),
                )
              else
                const Chip(
                  avatar: Icon(Icons.pending_outlined, size: 16),
                  label: Text('Packaged models pending'),
                ),
              if (nativeBackendLinked)
                const Chip(
                  avatar: Icon(Icons.developer_mode_rounded, size: 16),
                  label: Text('Native ONNX linked'),
                )
              else
                const Chip(
                  avatar: Icon(Icons.developer_mode_outlined, size: 16),
                  label: Text('Native ONNX pending'),
                ),
              if (nativeSessionReady)
                const Chip(
                  avatar: Icon(Icons.play_circle_outline_rounded, size: 16),
                  label: Text('Session load ready'),
                )
              else
                const Chip(
                  avatar: Icon(Icons.pause_circle_outline_rounded, size: 16),
                  label: Text('Session load pending'),
                ),
              if (contractMatchesManifest)
                const Chip(
                  avatar: Icon(Icons.rule_folder_outlined, size: 16),
                  label: Text('Contract matches'),
                )
              else
                const Chip(
                  avatar: Icon(Icons.rule_folder_rounded, size: 16),
                  label: Text('Contract unchecked'),
                ),
              if (packagedModels != null)
                Chip(
                  avatar: const Icon(Icons.inventory_2_outlined, size: 16),
                  label: Text(packagedModels),
                ),
              if (installedModels != null)
                Chip(
                  avatar: const Icon(Icons.download_done_outlined, size: 16),
                  label: Text(installedModels),
                ),
              if (stagedModels != null)
                Chip(
                  avatar: const Icon(Icons.folder_special_outlined, size: 16),
                  label: Text(stagedModels),
                ),
            ],
          ),
          if (runtimeProfile != null ||
              summaryModelId != null ||
              embeddingModelId != null ||
              runtimeDirectory != null) ...[
            const SizedBox(height: 14),
            Text(
              [
                if (runtimeProfile != null) 'Profile: $runtimeProfile',
                if (summaryModelId != null) 'Summary model: $summaryModelId',
                if (embeddingModelId != null) 'Embedding model: $embeddingModelId',
                if (runtimeDirectory != null) 'Runtime dir: $runtimeDirectory',
                if (capabilityMessage != null) 'Backend: $capabilityMessage',
                if (sessionMessage != null) 'Session: $sessionMessage',
                if (contractMessage != null) 'Contract: $contractMessage',
                if (tokenizationMessage != null) 'Tokenization: $tokenizationMessage',
                if (tokenizerMessage != null) 'Tokenizer: $tokenizerMessage',
                if (runPreviewMessage != null) 'Run preview: $runPreviewMessage',
                if (outputInterpretationMessage != null)
                  'Decode: $outputInterpretationMessage',
                if (actualInputNames.isNotEmpty)
                  'Actual inputs: ${actualInputNames.join(', ')}',
                if (actualOutputNames.isNotEmpty)
                  'Actual outputs: ${actualOutputNames.join(', ')}',
                if (tokenizerVocabSize > 0) 'Tokenizer vocab size: $tokenizerVocabSize',
                'Preview tokenizer loaded: $previewTokenizerLoaded',
                if (tokenizerModelType != null) 'Tokenizer model: $tokenizerModelType',
                if (tokenizerPreTokenizerType != null)
                  'Pre-tokenizer: $tokenizerPreTokenizerType',
                if (tokenizerNormalizerType != null)
                  'Normalizer: $tokenizerNormalizerType',
                if (previewInputIds.isNotEmpty)
                  'Preview input_ids: ${previewInputIds.take(12).join(', ')}',
                if (previewAttentionMask.isNotEmpty)
                  'Preview attention_mask: ${previewAttentionMask.take(12).join(', ')}',
                if (previewOutputNames.isNotEmpty)
                  'Preview outputs: ${previewOutputNames.join(', ')}',
                if (previewOutputShapes.isNotEmpty)
                  'Output shapes: ${previewOutputShapes.join(' | ')}',
                if (previewOutputValueSample.isNotEmpty)
                  'Output sample: ${previewOutputValueSample.join(', ')}',
                if (decoderType != null) 'Decoder type: $decoderType',
                'Can attempt decode: $canAttemptDecode',
              ].join('\n'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF4D5B68),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
