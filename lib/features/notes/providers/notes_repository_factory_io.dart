import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../data/local_notes_repository.dart';
import '../domain/notes_repository.dart';

NotesRepository createDefaultNotesRepository(Ref ref) {
  return LocalNotesRepository(AppDatabase());
}
