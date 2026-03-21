import 'package:flutter/material.dart';

import 'theme/app_theme.dart';
import '../features/notes/presentation/home_page.dart';

class OfflineAiNotepadApp extends StatelessWidget {
  const OfflineAiNotepadApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Offline AI Notepad',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const NotesHomePage(),
    );
  }
}
