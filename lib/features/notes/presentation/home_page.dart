import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/note_preview.dart';
import '../providers/notes_actions.dart';
import '../providers/notes_providers.dart';
import 'note_editor_page.dart';

class NotesHomePage extends ConsumerWidget {
  const NotesHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(notesListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline AI Notepad'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Chip(
              avatar: const Icon(Icons.cloud_off_rounded, size: 16),
              label: const Text('Offline-ready'),
              backgroundColor: Colors.white,
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
              _Entrance(
                delay: 0,
                child: const _HeroPanel(),
              ),
              const SizedBox(height: 18),
              _Entrance(
                delay: 80,
                child: _QuickStats(notesAsync: notesAsync),
              ),
              const SizedBox(height: 22),
              _Entrance(
                delay: 140,
                child: _SectionHeader(
                  eyebrow: 'Roadmap',
                  title: 'Build Focus',
                  subtitle: 'A calm foundation first, then local AI on top.',
                ),
              ),
              const SizedBox(height: 12),
              const _Entrance(
                delay: 180,
                child: _StatusCard(
                  title: 'Milestone 1',
                  body: 'Project shell is ready. Next we wire in the local data model, note creation flow, and plain-text editing experience.',
                  icon: Icons.foundation_outlined,
                ),
              ),
              const SizedBox(height: 12),
              const _Entrance(
                delay: 240,
                child: _StatusCard(
                  title: 'Milestone 2',
                  body: 'On-device summarization and embeddings will plug in behind interfaces so the app remains useful when AI is unavailable.',
                  icon: Icons.psychology_alt_outlined,
                ),
              ),
              const SizedBox(height: 24),
              _Entrance(
                delay: 300,
                child: _SectionHeader(
                  eyebrow: 'Library',
                  title: 'Recent Notes',
                  subtitle: 'Tap a card to keep writing.',
                ),
              ),
              const SizedBox(height: 12),
              notesAsync.when(
                data: (notes) => _Entrance(
                  delay: 360,
                  child: notes.isEmpty
                      ? const _EmptyNotesCard()
                      : Column(
                          children: [
                            for (var i = 0; i < notes.length; i++) ...[
                              _PreviewCard(
                                note: notes[i],
                                accentIndex: i,
                                onTap: () async {
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
                    Color(0x55FF7A59),
                    Color(0x00FF7A59),
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
                    Color(0x336CCFF6),
                    Color(0x006CCFF6),
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
            Color(0xFF0B6E4F),
            Color(0xFF188A65),
            Color(0xFF6CCFF6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22182A3A),
            blurRadius: 30,
            offset: Offset(0, 18),
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
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
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
            'Bright, fast, and offline-first. We are building the note-taking core first, then layering in local AI without sacrificing trust or speed.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.92),
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: const [
              _FeaturePill(label: 'Encrypted storage'),
              _FeaturePill(label: 'Autosave'),
              _FeaturePill(label: 'Semantic search'),
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
  });

  final AsyncValue<List<NotePreview>> notesAsync;

  @override
  Widget build(BuildContext context) {
    final count = notesAsync.valueOrNull?.length ?? 0;

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'Stored notes',
            value: '$count',
            tint: const Color(0xFFEEF7F0),
            icon: Icons.sticky_note_2_outlined,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: _StatCard(
            label: 'Mode',
            value: 'Local',
            tint: Color(0xFFFFF1EB),
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
        border: Border.all(color: Colors.white),
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

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.title,
    required this.body,
    required this.icon,
  });

  final String title;
  final String body;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 44,
              width: 44,
              decoration: BoxDecoration(
                color: theme.colorScheme.secondary.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: theme.colorScheme.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text(body, style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
          ],
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
    required this.onTogglePin,
  });

  final NotePreview note;
  final VoidCallback onTap;
  final int accentIndex;
  final VoidCallback onTogglePin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accents = [
      const Color(0xFF0B6E4F),
      const Color(0xFFFF7A59),
      const Color(0xFF6CCFF6),
    ];
    final accent = accents[accentIndex % accents.length];

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
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
                  IconButton(
                    onPressed: onTogglePin,
                    tooltip: note.isPinned ? 'Unpin note' : 'Pin note',
                    icon: Icon(
                      note.isPinned
                          ? Icons.push_pin_rounded
                          : Icons.push_pin_outlined,
                      color: accent,
                    ),
                  ),
                  Chip(label: Text(note.badge)),
                ],
              ),
              const SizedBox(height: 10),
              Text(note.body, style: theme.textTheme.bodyMedium),
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
                    'Open note',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w700,
                    ),
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
  const _EmptyNotesCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('No notes yet', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Create your first note and we will keep it local, editable, and ready for future on-device AI features.',
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
