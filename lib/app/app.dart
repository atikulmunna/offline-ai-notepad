import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

import 'theme/app_theme.dart';
import '../features/notes/presentation/home_page.dart';

class OfflineAiNotepadApp extends StatelessWidget {
  const OfflineAiNotepadApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NativeNote',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      localizationsDelegates: FlutterQuillLocalizations.localizationsDelegates,
      supportedLocales: FlutterQuillLocalizations.supportedLocales,
      home: const NotesHomePage(),
    );
  }
}
