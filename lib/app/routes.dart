import 'package:flutter/material.dart';

import '../features/auth/screens/login_screen.dart';
import '../features/notes/screens/notes_list_screen.dart';
import '../features/notes/screens/note_editor_screen.dart';
import '../features/notes/screens/note_detail_screen.dart';

/// Centralised route definitions for the app.
class AppRoutes {
  AppRoutes._();

  static const String login = '/login';
  static const String notesList = '/';
  static const String noteEditor = '/editor';
  static const String noteDetail = '/detail';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case login:
        return _fade(const LoginScreen(), settings);
      case notesList:
        return _fade(const NotesListScreen(), settings);
      case noteEditor:
        final noteId = settings.arguments as String?;
        return _fade(NoteEditorScreen(noteId: noteId), settings);
      case noteDetail:
        final noteId = settings.arguments as String;
        return _fade(NoteDetailScreen(noteId: noteId), settings);
      default:
        return _fade(const NotesListScreen(), settings);
    }
  }

  /// Smooth fade transition matching the "calm" design philosophy.
  static PageRouteBuilder _fade(Widget page, RouteSettings settings) {
    return PageRouteBuilder(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: const Duration(milliseconds: 250),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    );
  }
}
