import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../../appearance/presentation/glass_surface.dart';
import '../../notes/presentation/note_editor_page.dart';
import '../domain/note_qa.dart';
import '../providers/ask_notes_providers.dart';

/// "Ask your notes": a question box that answers from the user's own notes,
/// fully on-device, with citations back to the source notes.
class AskNotesPage extends ConsumerStatefulWidget {
  const AskNotesPage({super.key});

  @override
  ConsumerState<AskNotesPage> createState() => _AskNotesPageState();
}

class _AskNotesPageState extends ConsumerState<AskNotesPage> {
  late final TextEditingController _controller;
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit() {
    final question = _controller.text.trim();
    if (question.isEmpty) {
      return;
    }
    _focusNode.unfocus();
    ref.read(askNotesControllerProvider.notifier).ask(question);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    final state = ref.watch(askNotesControllerProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: Icon(Icons.arrow_back_rounded,
                        color: surfaces.onGlass),
                    tooltip: 'Back',
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.auto_awesome_rounded,
                      color: surfaces.accent, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Ask your notes',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: surfaces.onGlass,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              GlassSurface(
                borderRadius: 22,
                strongBorder: true,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        autofocus: true,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => _submit(),
                        style: theme.textTheme.bodyLarge
                            ?.copyWith(color: surfaces.onGlass),
                        cursorColor: surfaces.accent,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Ask anything about your notes…',
                          hintStyle: theme.textTheme.bodyLarge
                              ?.copyWith(color: surfaces.mutedText),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: state.isLoading ? null : _submit,
                      icon: Icon(Icons.arrow_upward_rounded,
                          color: surfaces.accent),
                      tooltip: 'Ask',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Answers are generated on your device from your own notes.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: surfaces.mutedText),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _AskBody(state: state),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AskBody extends StatelessWidget {
  const _AskBody({required this.state});

  final AskNotesState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;

    switch (state.status) {
      case AskStatus.idle:
        return _CenteredHint(
          icon: Icons.travel_explore_rounded,
          text: 'Type a question and I\'ll answer from your notes.',
        );
      case AskStatus.loading:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: surfaces.accent),
              const SizedBox(height: 16),
              Text('Searching your notes…',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: surfaces.mutedText)),
            ],
          ),
        );
      case AskStatus.error:
        return _CenteredHint(
          icon: Icons.error_outline_rounded,
          text: 'Something went wrong. Please try again.',
        );
      case AskStatus.done:
        final answer = state.answer;
        if (answer == null) {
          return const SizedBox.shrink();
        }
        return _AnswerView(answer: answer);
    }
  }
}

class _AnswerView extends StatelessWidget {
  const _AnswerView({required this.answer});

  final NoteQaAnswer answer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;

    switch (answer.outcome) {
      case NoteQaOutcome.emptyQuestion:
        return _CenteredHint(
          icon: Icons.travel_explore_rounded,
          text: 'Type a question and I\'ll answer from your notes.',
        );
      case NoteQaOutcome.noNotes:
        return _CenteredHint(
          icon: Icons.note_add_outlined,
          text: 'You don\'t have any notes yet. Add a few and ask again.',
        );
      case NoteQaOutcome.noMatches:
        return _CenteredHint(
          icon: Icons.search_off_rounded,
          text: 'I couldn\'t find anything about that in your notes.',
        );
      case NoteQaOutcome.answered:
        return ListView(
          children: [
            GlassSurface(
              borderRadius: 22,
              fillColor: surfaces.cardFill,
              borderColor: surfaces.cardBorder,
              blur: false,
              padding: const EdgeInsets.all(18),
              child: Text(
                answer.answer,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: surfaces.onGlass,
                  height: 1.4,
                ),
              ),
            ),
            if (answer.citations.isNotEmpty) ...[
              const SizedBox(height: 22),
              Text(
                'From your notes',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: surfaces.mutedText,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 10),
              for (final citation in answer.citations)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _CitationCard(citation: citation),
                ),
            ],
          ],
        );
    }
  }
}

class _CitationCard extends StatelessWidget {
  const _CitationCard({required this.citation});

  final NoteQaCitation citation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    final score = citation.score;

    return GlassSurface(
      borderRadius: 18,
      fillColor: surfaces.cardFill,
      borderColor: surfaces.cardBorder,
      blur: false,
      padding: const EdgeInsets.all(14),
      onTap: () => Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (context) => NoteEditorPage(noteId: citation.noteId),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  citation.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: surfaces.onGlass,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (score != null) ...[
                const SizedBox(width: 8),
                Text(
                  '${(score * 100).round()}% match',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: surfaces.accent),
                ),
              ],
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded,
                  color: surfaces.mutedText, size: 20),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            citation.snippet,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: surfaces.mutedText,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _CenteredHint extends StatelessWidget {
  const _CenteredHint({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: surfaces.mutedText, size: 40),
            const SizedBox(height: 14),
            Text(
              text,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: surfaces.mutedText, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
