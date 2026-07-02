import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../data/attachment_store.dart';

/// Renders inline image embeds from locally-stored attachment files.
///
/// The delta stores only the attachment file name; the absolute path is
/// resolved through [AttachmentStore], whose directory is warmed before the
/// editor renders. If the file is missing (e.g. a backup restored without its
/// attachments) a calm placeholder is shown instead of throwing.
class LocalImageEmbedBuilder extends EmbedBuilder {
  LocalImageEmbedBuilder(this.store);

  final AttachmentStore store;

  @override
  String get key => BlockEmbed.imageType;

  /// Keep the searchable/plain-text projection free of binary noise.
  @override
  String toPlainText(Embed node) => '';

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final data = embedContext.node.value.data;
    final path = data is String ? store.resolve(data) : null;
    final exists = path != null && File(path).existsSync();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: exists
            ? ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: Image.file(
                  File(path),
                  fit: BoxFit.contain,
                  errorBuilder: (context, _, _) => _Placeholder(),
                ),
              )
            : _Placeholder(),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 120,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.broken_image_outlined, size: 18, color: scheme.outline),
          const SizedBox(width: 8),
          Text(
            'Image unavailable',
            style: TextStyle(color: scheme.outline),
          ),
        ],
      ),
    );
  }
}
