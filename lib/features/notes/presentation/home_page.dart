import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/note_collection.dart';
import '../domain/note_folder.dart';
import '../domain/note_preview.dart';
import '../providers/notes_actions.dart';
import '../providers/notes_providers.dart';
import '../providers/notes_view_state.dart';
import 'note_editor_page.dart';

class NotesHomePage extends ConsumerStatefulWidget {
  const NotesHomePage({super.key});

  @override
  ConsumerState<NotesHomePage> createState() => _NotesHomePageState();
}

class _NotesHomePageState extends ConsumerState<NotesHomePage> {
  late final TextEditingController _searchController;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    final initialQuery = ref.read(notesViewStateProvider).searchQuery;
    _searchController = TextEditingController(text: initialQuery);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      ref.read(notesActionsProvider).setSearchQuery(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final notesAsync = ref.watch(notesListProvider);
    final foldersAsync = ref.watch(noteFoldersProvider);
    final viewState = ref.watch(notesViewStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const _BrandWordmark(),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Chip(
              avatar: const Icon(Icons.cloud_off_rounded, size: 16),
              label: const Text('Offline-ready'),
              backgroundColor: Colors.white.withValues(alpha: 0.92),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (context) => const NoteEditorPage(),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('New note'),
      ),
      body: Stack(
        children: [
          const _BackdropGlow(),
          ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
            children: [
              const _Entrance(
                delay: 0,
                child: _HeroPanel(),
              ),
              const SizedBox(height: 18),
              _Entrance(
                delay: 70,
                child: _QuickStats(
                  notesAsync: notesAsync,
                  collection: viewState.collection,
                ),
              ),
              const SizedBox(height: 22),
              _Entrance(
                delay: 140,
                child: _ControlDeck(
                  searchController: _searchController,
                  onSearchChanged: _onSearchChanged,
                  foldersAsync: foldersAsync,
                  viewState: viewState,
                ),
              ),
              const SizedBox(height: 24),
              _Entrance(
                delay: 220,
                child: _SectionHeader(
                  eyebrow: switch (viewState.collection) {
                    NoteCollection.active => 'Library',
                    NoteCollection.archived => 'Archive',
                    NoteCollection.trash => 'Trash',
                  },
                  title: switch (viewState.collection) {
                    NoteCollection.active => 'Recent Notes',
                    NoteCollection.archived => 'Archived Notes',
                    NoteCollection.trash => 'Trash Bin',
                  },
                  subtitle: switch (viewState.collection) {
                    NoteCollection.active => 'Keep the current workspace tidy and searchable.',
                    NoteCollection.archived => 'Older notes stay close without crowding the main list.',
                    NoteCollection.trash => 'Restore something valuable or remove it permanently.',
                  },
                ),
              ),
              const SizedBox(height: 12),
              notesAsync.when(
                data: (notes) => _Entrance(
                  delay: 280,
                  child: notes.isEmpty
                      ? _EmptyNotesCard(collection: viewState.collection)
                      : Column(
                          children: [
                            for (var i = 0; i < notes.length; i++) ...[
                              _PreviewCard(
                                note: notes[i],
                                accentIndex: i,
                                collection: viewState.collection,
                                onTap: () async {
                                  if (viewState.collection == NoteCollection.trash) {
                                    return;
                                  }
                                  await Navigator.of(context).push<bool>(
                                    MaterialPageRoute(
                                      builder: (context) => NoteEditorPage(
                                        noteId: notes[i].id,
                                      ),
                                    ),
                                  );
                                },
                                onTogglePin: () async {
                                  await ref.read(notesActionsProvider).togglePin(
                                        id: notes[i].id,
                                        value: !notes[i].isPinned,
                                      );
                                },
                                onArchiveToggle: () async {
                                  await ref.read(notesActionsProvider).setArchived(
                                        id: notes[i].id,
                                        value: !notes[i].isArchived,
                                      );
                                },
                                onMoveToTrash: () async {
                                  await ref
                                      .read(notesActionsProvider)
                                      .moveToTrash(notes[i].id);
                                },
                                onRestore: () async {
                                  await ref
                                      .read(notesActionsProvider)
                                      .restoreFromTrash(notes[i].id);
                                },
                                onDeleteForever: () async {
                                  await ref
                                      .read(notesActionsProvider)
                                      .deletePermanently(notes[i].id);
                                },
                              ),
                              if (i < notes.length - 1)
                                const SizedBox(height: 14),
                            ],
                          ],
                        ),
                ),
                error: (error, stackTrace) => _ErrorCard(error: error),
                loading: () => const _LoadingCard(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BrandWordmark extends StatelessWidget {
  const _BrandWordmark();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).appBarTheme.titleTextStyle ??
        Theme.of(context).textTheme.titleLarge;

    return ShaderMask(
      shaderCallback: (bounds) {
        return const LinearGradient(
          colors: [
            Color(0xFF5C33D6),
            Color(0xFF8F6BFF),
            Color(0xFFC56CFF),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(bounds);
      },
      blendMode: BlendMode.srcIn,
      child: Text(
        'NativeNote',
        style: style?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _BackdropGlow extends StatelessWidget {
  const _BackdropGlow();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -60,
            right: -40,
            child: Container(
              height: 220,
              width: 220,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Color(0x55B388FF),
                    Color(0x00B388FF),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 240,
            left: -70,
            child: Container(
              height: 240,
              width: 240,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Color(0x337C4DFF),
                    Color(0x007C4DFF),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF5C33D6),
            Color(0xFF8F6BFF),
            Color(0xFFC8B1FF),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2C5F46B0),
            blurRadius: 30,
            offset: Offset(0, 18),
          ),
        ],
        border: Border.all(
          color: Color(0x3DFFFFFF),
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -36,
            right: -24,
            child: Container(
              width: 170,
              height: 170,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Color(0x50FFFFFF),
                    Color(0x00FFFFFF),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -28,
            left: -18,
            child: Container(
              width: 140,
              height: 140,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Color(0x2EBEA3FF),
                    Color(0x00BEA3FF),
                  ],
                ),
              ),
            ),
          ),
          Column(
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
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 16),
                        SizedBox(width: 8),
                        Text(
                          'Offline AI workspace',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                'Private notes with a pulse.',
                style: theme.textTheme.headlineLarge?.copyWith(
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Folders, archive, trash, and search are now shaping the note library into a calmer workspace instead of a single stream.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: Colors.white.withValues(alpha: 0.92),
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: const [
                  _FeaturePill(label: 'Folders'),
                  _FeaturePill(label: 'Archive'),
                  _FeaturePill(label: 'Trash restore'),
                  _FeaturePill(label: 'Search'),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickStats extends StatelessWidget {
  const _QuickStats({
    required this.notesAsync,
    required this.collection,
  });

  final AsyncValue<List<NotePreview>> notesAsync;
  final NoteCollection collection;

  @override
  Widget build(BuildContext context) {
    final count = notesAsync.valueOrNull?.length ?? 0;

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: switch (collection) {
              NoteCollection.active => 'Visible notes',
              NoteCollection.archived => 'Archived',
              NoteCollection.trash => 'In trash',
            },
            value: '$count',
            tint: const Color(0xFFF3ECFF),
            icon: switch (collection) {
              NoteCollection.active => Icons.sticky_note_2_outlined,
              NoteCollection.archived => Icons.archive_outlined,
              NoteCollection.trash => Icons.delete_outline,
            },
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: _StatCard(
            label: 'Mode',
            value: 'Local',
            tint: Color(0xFFEFE7FF),
            icon: Icons.shield_moon_outlined,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.tint,
    required this.icon,
  });

  final String label;
  final String value;
  final Color tint;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF5EEFF)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              height: 42,
              width: 42,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: theme.colorScheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 4),
                  Text(value, style: theme.textTheme.titleLarge),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ControlDeck extends ConsumerWidget {
  const _ControlDeck({
    required this.searchController,
    required this.onSearchChanged,
    required this.foldersAsync,
    required this.viewState,
  });

  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final AsyncValue<List<NoteFolder>> foldersAsync;
  final NotesViewState viewState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.94),
            const Color(0xFFF8F2FF),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFDDD1F4)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x145F46B0),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: searchController,
            onChanged: onSearchChanged,
            decoration: const InputDecoration(
              labelText: 'Search notes',
              hintText: 'Title, body, or ideas you remember',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
          const SizedBox(height: 18),
          Text('Views', style: theme.textTheme.titleMedium),
          const SizedBox(height: 10),
          SegmentedButton<NoteCollection>(
            segments: const [
              ButtonSegment(
                value: NoteCollection.active,
                icon: Icon(Icons.home_work_outlined),
                label: Text('Active'),
              ),
              ButtonSegment(
                value: NoteCollection.archived,
                icon: Icon(Icons.archive_outlined),
                label: Text('Archive'),
              ),
              ButtonSegment(
                value: NoteCollection.trash,
                icon: Icon(Icons.delete_outline),
                label: Text('Trash'),
              ),
            ],
            selected: {viewState.collection},
            onSelectionChanged: (selection) {
              ref
                  .read(notesActionsProvider)
                  .showCollection(selection.first);
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text('Folders', style: theme.textTheme.titleMedium),
              const Spacer(),
              TextButton.icon(
                onPressed: foldersAsync.valueOrNull == null
                    ? null
                    : () async {
                        await showModalBottomSheet<void>(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (context) => _FolderManagerSheet(
                            folders: foldersAsync.valueOrNull ?? const [],
                          ),
                        );
                      },
                icon: const Icon(Icons.edit_note_rounded),
                label: const Text('Manage'),
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('Pinned only'),
                selected: viewState.pinnedOnly,
                onSelected: (value) {
                  ref.read(notesActionsProvider).setPinnedOnly(value);
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ChoiceChip(
                label: const Text('All'),
                selected: viewState.folderId == null,
                onSelected: (_) {
                  ref.read(notesActionsProvider).setFolderFilter(null);
                },
              ),
              ...foldersAsync.valueOrNull?.map((folder) {
                    return ChoiceChip(
                      label: Text(folder.name),
                      selected: viewState.folderId == folder.id,
                      onSelected: (_) {
                        ref
                            .read(notesActionsProvider)
                            .setFolderFilter(folder.id);
                      },
                    );
                  }) ??
                  [],
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
  });

  final String eyebrow;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow.toUpperCase(),
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.primary,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 4),
        Text(title, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(subtitle, style: theme.textTheme.bodyMedium),
      ],
    );
  }
}

class _FeaturePill extends StatelessWidget {
  const _FeaturePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white24),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _FolderManagerSheet extends ConsumerStatefulWidget {
  const _FolderManagerSheet({
    required this.folders,
  });

  final List<NoteFolder> folders;

  @override
  ConsumerState<_FolderManagerSheet> createState() => _FolderManagerSheetState();
}

class _FolderManagerSheetState extends ConsumerState<_FolderManagerSheet> {
  final _createController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _createController.dispose();
    super.dispose();
  }

  Future<void> _createFolder() async {
    final name = _createController.text.trim();
    if (name.isEmpty || _isSaving) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await ref.read(notesActionsProvider).createFolder(name);
      _createController.clear();
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _renameFolder(NoteFolder folder) async {
    final controller = TextEditingController(text: folder.name);
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Rename folder'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Folder name',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop(controller.text.trim());
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    controller.dispose();

    if (result == null || result.isEmpty || result == folder.name) {
      return;
    }

    await ref.read(notesActionsProvider).renameFolder(
          id: folder.id,
          name: result,
        );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foldersAsync = ref.watch(noteFoldersProvider);
    final folders = foldersAsync.valueOrNull ?? widget.folders;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Material(
        color: const Color(0xFFFCF8FF),
        borderRadius: BorderRadius.circular(28),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Manage folders', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                'Keep your workspace organized without leaving the note flow.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _createController,
                      decoration: const InputDecoration(
                        labelText: 'New folder',
                        hintText: 'Ideas, Meetings, Reading...',
                      ),
                      onSubmitted: (_) => _createFolder(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _isSaving ? null : _createFolder,
                    child: Text(_isSaving ? 'Saving...' : 'Add'),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (folders.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text('No folders yet. Create one to start grouping notes.'),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 280),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: folders.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 20),
                    itemBuilder: (context, index) {
                      final folder = folders[index];
                      return Row(
                        children: [
                          const Icon(Icons.folder_open_rounded, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              folder.name,
                              style: theme.textTheme.titleMedium,
                            ),
                          ),
                          IconButton(
                            onPressed: () => _renameFolder(folder),
                            icon: const Icon(Icons.drive_file_rename_outline),
                            tooltip: 'Rename folder',
                          ),
                        ],
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.note,
    required this.onTap,
    required this.accentIndex,
    required this.collection,
    required this.onTogglePin,
    required this.onArchiveToggle,
    required this.onMoveToTrash,
    required this.onRestore,
    required this.onDeleteForever,
  });

  final NotePreview note;
  final VoidCallback onTap;
  final int accentIndex;
  final NoteCollection collection;
  final VoidCallback onTogglePin;
  final VoidCallback onArchiveToggle;
  final VoidCallback onMoveToTrash;
  final VoidCallback onRestore;
  final VoidCallback onDeleteForever;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accents = [
      const Color(0xFF7C4DFF),
      const Color(0xFFB388FF),
      const Color(0xFF8A63FF),
    ];
    final accent = accents[accentIndex % accents.length];

    return Card(
      elevation: 0,
      color: Colors.white.withValues(alpha: 0.96),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: collection == NoteCollection.trash ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(note.title, style: theme.textTheme.titleMedium),
                  ),
                  PopupMenuButton<_CardAction>(
                    itemBuilder: (context) => _buildActions(),
                    onSelected: (value) {
                      switch (value) {
                        case _CardAction.pin:
                          onTogglePin();
                        case _CardAction.archive:
                          onArchiveToggle();
                        case _CardAction.trash:
                          onMoveToTrash();
                        case _CardAction.restore:
                          onRestore();
                        case _CardAction.deleteForever:
                          onDeleteForever();
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                note.body,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF54486B),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (note.folderName != null)
                    Chip(
                      avatar: const Icon(Icons.folder_open_outlined, size: 16),
                      label: Text(note.folderName!),
                    ),
                  Chip(label: Text(note.badge)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    size: 16,
                    color: theme.colorScheme.primary.withValues(alpha: 0.75),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _formatUpdatedLabel(note.updatedAt),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF5B6674),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              if (collection != NoteCollection.trash) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Icon(
                      Icons.arrow_outward_rounded,
                      size: 18,
                      color: accent,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      collection == NoteCollection.archived
                          ? 'Review archived note'
                          : 'Open note',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<PopupMenuEntry<_CardAction>> _buildActions() {
    switch (collection) {
      case NoteCollection.active:
        return [
          PopupMenuItem(
            value: _CardAction.pin,
            child: Text(note.isPinned ? 'Unpin note' : 'Pin note'),
          ),
          const PopupMenuItem(
            value: _CardAction.archive,
            child: Text('Archive'),
          ),
          const PopupMenuItem(
            value: _CardAction.trash,
            child: Text('Move to trash'),
          ),
        ];
      case NoteCollection.archived:
        return [
          const PopupMenuItem(
            value: _CardAction.archive,
            child: Text('Move back to active'),
          ),
          const PopupMenuItem(
            value: _CardAction.trash,
            child: Text('Move to trash'),
          ),
        ];
      case NoteCollection.trash:
        return const [
          PopupMenuItem(
            value: _CardAction.restore,
            child: Text('Restore'),
          ),
          PopupMenuItem(
            value: _CardAction.deleteForever,
            child: Text('Delete permanently'),
          ),
        ];
    }
  }
}

enum _CardAction {
  pin,
  archive,
  trash,
  restore,
  deleteForever,
}

String _formatUpdatedLabel(DateTime updatedAt) {
  final now = DateTime.now();
  final difference = now.difference(updatedAt);

  if (difference.inMinutes < 1) {
    return 'Updated just now';
  }
  if (difference.inHours < 1) {
    return 'Updated ${difference.inMinutes}m ago';
  }
  if (difference.inDays < 1) {
    return 'Updated ${difference.inHours}h ago';
  }
  if (difference.inDays == 1) {
    return 'Updated yesterday';
  }
  return 'Updated ${difference.inDays}d ago';
}

class _EmptyNotesCard extends StatelessWidget {
  const _EmptyNotesCard({
    required this.collection,
  });

  final NoteCollection collection;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final message = switch (collection) {
      NoteCollection.active =>
        'Create a note, pin a few favorites, or narrow the workspace with folder and search filters.',
      NoteCollection.archived =>
        'Nothing is archived yet. When a note is done for now, archive it instead of deleting it.',
      NoteCollection.trash =>
        'Trash is empty. Deleted notes will wait here until you restore or permanently remove them.',
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nothing here yet', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              message,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(18),
        child: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text('Loading note previews...'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({
    required this.error,
  });

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Text(
          'Unable to load note previews: $error',
        ),
      ),
    );
  }
}

class _Entrance extends StatelessWidget {
  const _Entrance({
    required this.child,
    required this.delay,
  });

  final Widget child;
  final int delay;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 420 + delay),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 18),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
