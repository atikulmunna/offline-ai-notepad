import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/notes_repository.dart';
import 'notes_repository_factory_stub.dart'
    if (dart.library.io) 'notes_repository_factory_io.dart' as notes_repo_factory;

NotesRepository createDefaultNotesRepository(Ref ref) {
  return notes_repo_factory.createDefaultNotesRepository(ref);
}
