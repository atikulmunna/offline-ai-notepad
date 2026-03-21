import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/in_memory_notes_repository.dart';
import '../domain/notes_repository.dart';

NotesRepository createDefaultNotesRepository(Ref ref) {
  return InMemoryNotesRepository();
}
