import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/note_preview.dart';
import '../providers/notes_providers.dart';
import 'note_editor_page.dart';

class NotesHomePage extends ConsumerWidget {
  const NotesHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final notesAsync = ref.watch(notesListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline AI Notepad'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 20),
            child: Chip(
              label: Text('Offline-ready'),
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
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF0A9396),
                  Color(0xFF94D2BD),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Private notes with on-device AI',
                  style: theme.textTheme.headlineLarge?.copyWith(
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'We are building the encrypted, offline-first foundation first so note-taking stays fast even before AI features arrive.',
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
          ),
          const SizedBox(height: 20),
          Text(
            'Build Focus',
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          const _StatusCard(
            title: 'Milestone 1',
            body: 'Project shell is ready. Next we wire in the local data model, note creation flow, and plain-text editing experience.',
            icon: Icons.foundation_outlined,
          ),
          const SizedBox(height: 12),
          const _StatusCard(
            title: 'Milestone 2',
            body: 'On-device summarization and embeddings will plug in behind interfaces so the app remains useful when AI is unavailable.',
            icon: Icons.psychology_alt_outlined,
          ),
          const SizedBox(height: 20),
          Text(
            'Sample Notes',
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          notesAsync.when(
            data: (notes) => Column(
              children: [
                for (var i = 0; i < notes.length; i++) ...[
                  _PreviewCard(note: notes[i]),
                  if (i < notes.length - 1) const SizedBox(height: 12),
                ],
              ],
            ),
            error: (error, stackTrace) => _ErrorCard(error: error),
            loading: () => const _LoadingCard(),
          ),
        ],
      ),
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
  });

  final NotePreview note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(note.title, style: theme.textTheme.titleMedium),
                ),
                Chip(label: Text(note.badge)),
              ],
            ),
            const SizedBox(height: 10),
            Text(note.body, style: theme.textTheme.bodyMedium),
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
