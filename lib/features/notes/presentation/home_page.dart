import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database_provider.dart';
import '../domain/note_collection.dart';
import '../domain/note_folder.dart';
import '../domain/note_preview.dart';
import '../domain/note_search_mode.dart';
import '../providers/notes_actions.dart';
import '../providers/notes_providers.dart';
import '../providers/notes_view_state.dart';
import '../../security/data/encrypted_backup_service.dart';
import '../../security/data/note_protection_service.dart';
import '../../security/providers/app_lock_providers.dart';
import 'note_editor_page.dart';

class NotesHomePage extends ConsumerStatefulWidget {
  const NotesHomePage({super.key});

  @override
  ConsumerState<NotesHomePage> createState() => _NotesHomePageState();
}

class _NotesHomePageState extends ConsumerState<NotesHomePage> {
  late final TextEditingController _searchController;
  Timer? _searchDebounce;
  Timer? _introDismissTimer;
  bool _showIntro = true;
  bool _showSearch = false;

  @override
  void initState() {
    super.initState();
    final initialQuery = ref.read(notesViewStateProvider).searchQuery;
    _searchController = TextEditingController(text: initialQuery);
    _introDismissTimer = Timer(const Duration(milliseconds: 1600), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _showIntro = false;
      });
    });
  }

  @override
  void dispose() {
    _introDismissTimer?.cancel();
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

  Future<void> _openPrivacySheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _PrivacySheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notesAsync = ref.watch(notesListProvider);
    final foldersAsync = ref.watch(noteFoldersProvider);
    final viewState = ref.watch(notesViewStateProvider);
    final appLockState = ref.watch(appLockControllerProvider);
    final isShowingIntro = _showIntro;

    return Scaffold(
      appBar: isShowingIntro
          ? null
          : AppBar(
              title: const _BrandWordmark(),
              actions: [
                IconButton(
                  onPressed: _openPrivacySheet,
                  tooltip: 'Privacy controls',
                  icon: Icon(
                    appLockState.isEnabled
                        ? Icons.lock_rounded
                        : Icons.lock_open_rounded,
                  ),
                ),
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
      floatingActionButton: isShowingIntro
          ? null
          : FloatingActionButton.extended(
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
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 380),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeOutCubic,
        child: isShowingIntro
            ? const _LaunchIntroScreen(key: ValueKey('launch-intro'))
            : Stack(
                key: const ValueKey('home-content'),
                children: [
                  const _BackdropGlow(),
                  ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                    children: [
                      _Entrance(
                        delay: 80,
                        child: _ControlDeck(
                          showSearch: _showSearch,
                          onToggleSearch: () {
                            setState(() {
                              _showSearch = !_showSearch;
                            });
                          },
                          searchController: _searchController,
                          onSearchChanged: _onSearchChanged,
                          foldersAsync: foldersAsync,
                          viewState: viewState,
                        ),
                      ),
                      const SizedBox(height: 24),
                      _Entrance(
                        delay: 160,
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
                            NoteCollection.active => viewState.searchMode == NoteSearchMode.semantic
                                ? 'Use local meaning-based search to surface notes that feel related, not just exact matches.'
                                : 'Keep the current workspace tidy and searchable.',
                            NoteCollection.archived => 'Older notes stay close without crowding the main list.',
                            NoteCollection.trash => 'Restore something valuable or remove it permanently.',
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      notesAsync.when(
                        data: (notes) => _Entrance(
                          delay: 220,
                          child: notes.isEmpty
                              ? _EmptyNotesCard(viewState: viewState)
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
            Color(0xFF22333B),
            Color(0xFF5E503F),
            Color(0xFFC6AC8F),
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
                    Color(0x55C6AC8F),
                    Color(0x00C6AC8F),
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
                    Color(0x3322333B),
                    Color(0x0022333B),
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

class _LaunchIntroScreen extends StatelessWidget {
  const _LaunchIntroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ColoredBox(
      color: const Color(0xFFF5EEE6),
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.96, end: 1),
          duration: const Duration(milliseconds: 520),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Transform.scale(
              scale: value,
              child: Opacity(
                opacity: value.clamp(0.0, 1.0),
                child: child,
              ),
            );
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF22333B),
                      Color(0xFF5E503F),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x3322333B),
                      blurRadius: 20,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.edit_note_rounded,
                  color: Color(0xFFEAE0D5),
                  size: 34,
                ),
              ),
              const SizedBox(height: 20),
              const _BrandWordmark(),
              const SizedBox(height: 14),
              Text(
                'Private notes with a pulse.',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: const Color(0xFF5E503F).withValues(alpha: 0.72),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ControlDeck extends ConsumerWidget {
  const _ControlDeck({
    required this.showSearch,
    required this.onToggleSearch,
    required this.searchController,
    required this.onSearchChanged,
    required this.foldersAsync,
    required this.viewState,
  });

  final bool showSearch;
  final VoidCallback onToggleSearch;
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
            const Color(0xFFEAE0D5),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFC6AC8F)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1422333B),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Explore', style: theme.textTheme.titleMedium),
              const Spacer(),
              AnimatedRotation(
                turns: showSearch ? 0.0 : -0.02,
                duration: const Duration(milliseconds: 220),
                child: IconButton.filledTonal(
                  onPressed: onToggleSearch,
                  icon: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: Icon(
                      showSearch ? Icons.close_rounded : Icons.search_rounded,
                      key: ValueKey(showSearch),
                    ),
                  ),
                  tooltip: showSearch ? 'Hide search' : 'Show search',
                ),
              ),
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            child: showSearch
                ? Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: searchController,
                          onChanged: onSearchChanged,
                          decoration: InputDecoration(
                            labelText: viewState.searchMode ==
                                    NoteSearchMode.semantic
                                ? 'Search by meaning'
                                : 'Search notes',
                            hintText: viewState.searchMode ==
                                    NoteSearchMode.semantic
                                ? 'Ideas, themes, or what the note was about'
                                : 'Title, body, or exact words you remember',
                            prefixIcon: const Icon(Icons.search_rounded),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text('Search style', style: theme.textTheme.titleMedium),
                        const SizedBox(height: 10),
                        SegmentedButton<NoteSearchMode>(
                          segments: const [
                            ButtonSegment(
                              value: NoteSearchMode.keyword,
                              icon: Icon(Icons.text_fields_rounded),
                              label: Text('Keyword'),
                            ),
                            ButtonSegment(
                              value: NoteSearchMode.semantic,
                              icon: Icon(Icons.auto_awesome_rounded),
                              label: Text('Semantic'),
                            ),
                          ],
                          selected: {viewState.searchMode},
                          onSelectionChanged: (selection) {
                            ref
                                .read(notesActionsProvider)
                                .setSearchMode(selection.first);
                          },
                        ),
                        const SizedBox(height: 10),
                        Text(
                          viewState.searchMode.helperLabel,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF746487),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
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
        color: const Color(0xFFFFFBF7),
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

class _PrivacySheet extends ConsumerStatefulWidget {
  const _PrivacySheet();

  @override
  ConsumerState<_PrivacySheet> createState() => _PrivacySheetState();
}

class _PrivacySheetState extends ConsumerState<_PrivacySheet> {
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  bool _isDisabling = false;
  bool _isProcessingBackup = false;

  @override
  void dispose() {
    _pinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  Future<void> _enableLock() async {
    final messenger = ScaffoldMessenger.of(context);
    final pin = _pinController.text.trim();
    final confirmation = _confirmPinController.text.trim();
    if (pin != confirmation) {
      messenger.showSnackBar(
        const SnackBar(content: Text('PIN entries need to match.')),
      );
      return;
    }

    final success =
        await ref.read(appLockControllerProvider.notifier).enableWithPin(pin);
    if (!mounted) {
      return;
    }
    if (success) {
      await ref
          .read(noteProtectionServiceProvider)
          .encryptExistingNotes(
            ref.read(appDatabaseProvider),
            sessionPinOverride: pin,
          );
      ref.invalidate(notesListProvider);
      _pinController.clear();
      _confirmPinController.clear();
      messenger.showSnackBar(
        const SnackBar(content: Text('App lock is on and notes are now protected at rest.')),
      );
    }
  }

  Future<void> _disableLock() async {
    final messenger = ScaffoldMessenger.of(context);
    final pinController = TextEditingController();
    final enteredPin = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Turn off app lock'),
          content: TextField(
            controller: pinController,
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: 8,
            decoration: const InputDecoration(
              labelText: 'Current PIN',
              counterText: '',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(pinController.text.trim()),
              child: const Text('Disable'),
            ),
          ],
        );
      },
    );
    pinController.dispose();

    if (!mounted || enteredPin == null || enteredPin.isEmpty) {
      return;
    }

    setState(() {
      _isDisabling = true;
    });
    final controller = ref.read(appLockControllerProvider.notifier);
    final unlocked = await controller.unlock(enteredPin);
    if (!mounted) {
      return;
    }
    var success = false;
    if (unlocked) {
      await ref
          .read(noteProtectionServiceProvider)
          .decryptExistingNotes(
            ref.read(appDatabaseProvider),
            sessionPinOverride: enteredPin,
          );
      success = await controller.disable(enteredPin);
      ref.invalidate(notesListProvider);
    }
    setState(() {
      _isDisabling = false;
    });
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          success ? 'App lock is off.' : 'Could not disable app lock.',
        ),
      ),
    );
  }

  Future<String?> _promptBackupPassphrase({
    required String title,
    required String actionLabel,
    bool confirm = false,
  }) async {
    final passphraseController = TextEditingController();
    final confirmController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: passphraseController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Passphrase',
                ),
              ),
              if (confirm) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: confirmController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirm passphrase',
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final passphrase = passphraseController.text.trim();
                final confirmation = confirmController.text.trim();
                if (passphrase.length < 6) {
                  return;
                }
                if (confirm && passphrase != confirmation) {
                  return;
                }
                Navigator.of(context).pop(passphrase);
              },
              child: Text(actionLabel),
            ),
          ],
        );
      },
    );
    passphraseController.dispose();
    confirmController.dispose();
    return result;
  }

  Future<void> _exportBackup() async {
    final messenger = ScaffoldMessenger.of(context);
    final passphrase = await _promptBackupPassphrase(
      title: 'Export encrypted backup',
      actionLabel: 'Export',
      confirm: true,
    );
    if (!mounted || passphrase == null) {
      return;
    }

    setState(() {
      _isProcessingBackup = true;
    });
    try {
      final backupService = ref.read(encryptedBackupServiceProvider);
      final path = await backupService.exportEncryptedBackup(
        passphrase: passphrase,
      );
      await backupService.shareBackupFile(path);
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Encrypted backup is ready to save or share.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingBackup = false;
        });
      }
    }
  }

  Future<void> _importBackup() async {
    final messenger = ScaffoldMessenger.of(context);
    final passphrase = await _promptBackupPassphrase(
      title: 'Import encrypted backup',
      actionLabel: 'Import',
    );
    if (!mounted || passphrase == null) {
      return;
    }

    setState(() {
      _isProcessingBackup = true;
    });
    try {
      final imported = await ref.read(encryptedBackupServiceProvider).importEncryptedBackup(
            passphrase: passphrase,
          );
      if (!mounted) {
        return;
      }
      if (imported) {
        ref.invalidate(notesListProvider);
        ref.invalidate(noteFoldersProvider);
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            imported
                ? 'Encrypted backup imported.'
                : 'Backup import was cancelled.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Could not import that backup. Check the passphrase and file.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingBackup = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appLockState = ref.watch(appLockControllerProvider);

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(22),
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
            borderRadius: BorderRadius.circular(30),
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
              Text('Privacy lock', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                appLockState.isEnabled
                    ? 'NativeNote will ask for your PIN whenever the app comes back into view.'
                    : 'Add a local PIN so the app locks itself when you leave it.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF22333B),
                ),
              ),
              const SizedBox(height: 18),
              if (!appLockState.isEnabled) ...[
                TextField(
                  controller: _pinController,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 8,
                  decoration: const InputDecoration(
                    labelText: 'Create PIN',
                    hintText: '4 to 8 digits',
                    counterText: '',
                    prefixIcon: Icon(Icons.lock_outline_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _confirmPinController,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 8,
                  decoration: const InputDecoration(
                    labelText: 'Confirm PIN',
                    hintText: 'Repeat the same PIN',
                    counterText: '',
                    prefixIcon: Icon(Icons.verified_user_outlined),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: appLockState.isBusy ? null : _enableLock,
                    icon: const Icon(Icons.shield_rounded),
                    label: Text(
                      appLockState.isBusy ? 'Saving...' : 'Turn on app lock',
                    ),
                  ),
                ),
              ] else ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFC6AC8F)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF22333B),
                              Color(0xFF5E503F),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.lock_rounded,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'App lock is active',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: const Color(0xFF0A0908),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'The app will relock when it goes to the background.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: const Color(0xFF22333B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          ref
                              .read(appLockControllerProvider.notifier)
                              .lockNow();
                          Navigator.of(context).pop();
                        },
                        icon: const Icon(Icons.lock_clock_rounded),
                        label: const Text('Lock now'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: _isDisabling ? null : _disableLock,
                        icon: const Icon(Icons.lock_open_rounded),
                        label: Text(_isDisabling ? 'Checking...' : 'Turn off'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.66),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: const Color(0xFFC6AC8F)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Encrypted backup',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: const Color(0xFF0A0908),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Export your notes into a passphrase-protected backup file, or import one back into this device.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF22333B),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed:
                                  _isProcessingBackup ? null : _exportBackup,
                              icon: const Icon(Icons.ios_share_rounded),
                              label: Text(
                                _isProcessingBackup ? 'Working...' : 'Export',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.tonalIcon(
                              onPressed:
                                  _isProcessingBackup ? null : _importBackup,
                              icon: const Icon(Icons.download_rounded),
                              label: const Text('Import'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
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
      const Color(0xFF5E503F),
      const Color(0xFFC6AC8F),
      const Color(0xFF22333B),
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
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF22333B),
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
                      color: const Color(0xFF22333B),
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
    required this.viewState,
  });

  final NotesViewState viewState;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasSearchQuery = viewState.searchQuery.trim().isNotEmpty;
    final message = hasSearchQuery
        ? switch (viewState.searchMode) {
            NoteSearchMode.keyword =>
              'No exact matches yet. Try a broader word, remove a folder filter, or switch to semantic search.',
            NoteSearchMode.semantic =>
              'No related notes surfaced yet. Try a different idea phrase or switch back to keyword search for exact wording.',
          }
        : switch (viewState.collection) {
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
