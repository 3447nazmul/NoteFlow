import 'dart:async';

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'dart:convert';

import '../../../shared/constants/app_strings.dart';
import '../../../services/ai_service.dart';
import '../../../services/api_key_service.dart';
import '../../../services/export_service.dart';
import '../../../services/ad_service.dart';
import '../../../services/app_config_service.dart';
import '../controllers/notes_controller.dart';
import '../models/note_model.dart';
import '../widgets/ai_action_bar.dart';
import '../widgets/checklist_widget.dart';
import '../widgets/share_card_dialog.dart';

/// ──────────────────────────────────────────────────────────────
/// NoteFlow — Note Editor Screen
///
/// Full-screen distraction-free editor with:
///  • Large title field ("Note title…")
///  • Large body field ("Start writing…")
///  • Auto-save every 3 seconds of inactivity
///  • "Saving…" / "Saved ✓" status indicator in top bar
///  • Word count + character count footer
///  • Formatting toolbar (Bold · Italic · Bullet list)
///  • Back button with discard confirmation
///  • AI action bar at the bottom
/// ──────────────────────────────────────────────────────────────

// AI NOTE: UI for the distraction-free note editor, featuring auto-save, text formatting, OCR, voice-to-text, and AI integrations.
class NoteEditorScreen extends StatefulWidget {
  final String? noteId;
  const NoteEditorScreen({super.key, this.noteId});

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  late TextEditingController _titleController;
  late quill.QuillController _quillController;

  Note? _note;
  bool _hasUnsavedChanges = false;

  // Auto-save
  Timer? _autoSaveTimer;
  _SaveStatus _saveStatus = _SaveStatus.idle;

  // Stats
  int _wordCount = 0;
  int _charCount = 0;

  // Checklist
  bool _showChecklist = false;
  List<Map<String, dynamic>> _checklistItems = [];

  // Attachments
  List<Map<String, String>> _attachments = [];

  // OCR
  final ImagePicker _picker = ImagePicker();

  late NotesController _notesController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _quillController = quill.QuillController.basic();

    _quillController.document.changes.listen((_) => _updateStats());

    WidgetsBinding.instance.addPostFrameCallback((_) => _loadNote());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _notesController = context.read<NotesController>();
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    // Final save on exit
    _saveNote();

    if (_note != null) {
      _notesController.autoTagNoteBackground(_note!.id);
    }

    _titleController.dispose();
    _quillController.dispose();
    super.dispose();
  }

  // ─── Load ───

  void _loadNote() {
    if (widget.noteId != null) {
      final controller = context.read<NotesController>();
      final note = controller.getNoteById(widget.noteId!);
      if (note != null) {
        setState(() {
          _note = note;
          _titleController.text = note.title;
          
          if (note.body.startsWith('[{"insert"')) {
            try {
              final json = jsonDecode(note.body);
              _quillController = quill.QuillController(
                document: quill.Document.fromJson(json),
                selection: const TextSelection.collapsed(offset: 0),
              );
            } catch (e) {
              _quillController = quill.QuillController(
                document: quill.Document()..insert(0, note.body),
                selection: const TextSelection.collapsed(offset: 0),
              );
            }
          } else {
            _quillController = quill.QuillController(
              document: quill.Document()..insert(0, note.body),
              selection: const TextSelection.collapsed(offset: 0),
            );
          }
          _quillController.document.changes.listen((_) => _updateStats());

          _checklistItems = List<Map<String, dynamic>>.from(
            note.checklist.map((m) => Map<String, dynamic>.from(m)),
          );
          _attachments = List<Map<String, String>>.from(
            note.attachments.map((m) => Map<String, String>.from(m)),
          );
          _showChecklist = _checklistItems.isNotEmpty;
          _updateStats();
        });
      }
    }
  }

  // ─── Stats ───

  void _updateStats() {
    final text = _quillController.document.toPlainText();
    final words = text.trim().isEmpty
        ? 0
        : text.trim().split(RegExp(r'\s+')).length;

    setState(() {
      _charCount = text.length - 1; // subtract trailing newline from Quill
      if (_charCount < 0) _charCount = 0;
      _wordCount = words;
    });
  }

  // ─── Auto-save ───

  void _onContentChanged() {
    if (!_hasUnsavedChanges) {
      setState(() => _hasUnsavedChanges = true);
    }

    // Reset the 3-second auto-save timer
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(seconds: 3), () {
      _saveNote();
    });
  }

  Future<void> _saveNote() async {
    if (_note == null || !_hasUnsavedChanges) return;

    setState(() => _saveStatus = _SaveStatus.saving);

    final bodyJson = jsonEncode(_quillController.document.toDelta().toJson());
    await _notesController.updateNote(
      _note!.copyWith(
        title: _titleController.text.trim(),
        body: bodyJson,
        checklist: _checklistItems,
        attachments: _attachments,
      ),
    );

    // Re-fetch the note to get updated timestamp
    _note = _notesController.getNoteById(_note!.id);

    if (mounted) {
      setState(() {
        _hasUnsavedChanges = false;
        _saveStatus = _SaveStatus.saved;
      });

      // Reset status after 2 seconds
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && _saveStatus == _SaveStatus.saved) {
          setState(() => _saveStatus = _SaveStatus.idle);
        }
      });
    }
  }

  // ─── Back with discard check ───

  Future<bool> _onWillPop() async {
    if (!_hasUnsavedChanges) return true;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Unsaved Changes',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'You have unsaved changes. Save before leaving?',
          style: GoogleFonts.poppins(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), // discard
            child: Text(
              'Discard',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
          FilledButton(
            onPressed: () async {
              await _saveNote();
              if (ctx.mounted) Navigator.pop(ctx, true);
            },
            child: const Text('Save & Leave'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  // ─── Formatting toolbar actions ───

  void _insertBold() => _quillController.formatSelection(quill.Attribute.bold);
  void _insertItalic() => _quillController.formatSelection(quill.Attribute.italic);
  void _insertUnderline() => _quillController.formatSelection(quill.Attribute.underline);
  void _insertStrikethrough() => _quillController.formatSelection(quill.Attribute.strikeThrough);
  void _insertBullet() => _quillController.formatSelection(quill.Attribute.ul);

  void _toggleChecklist() {
    HapticFeedback.selectionClick();
    setState(() {
      _showChecklist = !_showChecklist;
      if (_showChecklist && _checklistItems.isEmpty) {
        _checklistItems = [
          {'text': '', 'checked': false},
        ];
      }
    });
    _onContentChanged();
  }

  // ─── Image OCR & Attachments ───

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;
    final pickedFile = await _picker.pickImage(source: source);
    if (pickedFile == null) return;

    await _saveAttachmentLocally(pickedFile.path, 'image');
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'html', 'pptx', 'mp3', 'wav', 'xls', 'xlsx'],
    );

    if (result != null && result.files.single.path != null) {
      final ext = result.files.single.extension?.toLowerCase() ?? 'file';
      await _saveAttachmentLocally(result.files.single.path!, ext);
    }
  }

  Future<void> _saveAttachmentLocally(String sourcePath, String type) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = sourcePath.split(Platform.pathSeparator).last;
      final savedFile = await File(sourcePath).copy('${appDir.path}/$fileName');

      setState(() {
        _attachments.add({
          'id': DateTime.now().millisecondsSinceEpoch.toString(),
          'path': savedFile.path,
          'name': fileName,
          'type': type,
        });
      });
      _onContentChanged();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to attach file: $e')),
        );
      }
    }
  }

  void _removeAttachment(int index) {
    setState(() {
      _attachments.removeAt(index);
    });
    _onContentChanged();
  }

  Future<void> _pickImageAndExtractText() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    final pickedFile = await _picker.pickImage(source: source);
    if (pickedFile == null) return;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
              const SizedBox(width: 12),
              const Text('Extracting text...'),
            ],
          ),
          duration: const Duration(seconds: 15),
        ),
      );
    }

    final bytes = await pickedFile.readAsBytes();
    if (!mounted) return;
    final aiService = AiService(ApiKeyService(), context.read<AppConfigService>());
    final extractedText = await aiService.extractTextFromImage(bytes);

    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      if (extractedText.startsWith('Image extraction failed') ||
          extractedText.startsWith('Could not extract') ||
          extractedText.startsWith('No AI API key')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(extractedText),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      } else {
        final index = _quillController.selection.baseOffset >= 0
            ? _quillController.selection.baseOffset
            : _quillController.document.length - 1;
        _quillController.document.insert(
          index,
          '\n\n--- Extracted Text ---\n$extractedText\n----------------------\n\n',
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Text extracted successfully.')),
        );
      }
    }
  }

  // ─── Export as PDF ───

  void _showExportOptions() {
    FocusScope.of(context).unfocus();
    final hasAttachments = _note?.attachments.isNotEmpty ?? false;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Export Options',
                  style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                
                // Export PDF Options
                ListTile(
                  leading: const Icon(Icons.picture_as_pdf_outlined),
                  title: const Text('Share as PDF'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _executeExport(isZip: false, saveToDevice: false);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.download_rounded),
                  title: const Text('Save PDF to Device'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _executeExport(isZip: false, saveToDevice: true);
                  },
                ),

                // Export ZIP Options (If attachments exist)
                if (hasAttachments) ...[
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.folder_zip_outlined),
                    title: const Text('Share with Attachments (.zip)'),
                    onTap: () {
                      Navigator.pop(ctx);
                      _executeExport(isZip: true, saveToDevice: false);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.save_alt_rounded),
                    title: const Text('Save with Attachments (.zip)'),
                    onTap: () {
                      Navigator.pop(ctx);
                      _executeExport(isZip: true, saveToDevice: true);
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _executeExport({required bool isZip, required bool saveToDevice}) async {
    await _saveNote();
    if (_note == null) return;

    HapticFeedback.mediumImpact();
    final cs = Theme.of(context).colorScheme;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: cs.onPrimary,
              ),
            ),
            const SizedBox(width: 12),
            Text(isZip ? 'Generating ZIP Archive…' : 'Generating PDF…', style: GoogleFonts.poppins(fontSize: 14)),
          ],
        ),
        duration: const Duration(seconds: 10),
      ),
    );

    try {
      if (isZip) {
        await ExportService.exportWithAttachments(_note!, saveToDevice: saveToDevice);
      } else {
        await ExportService.exportAsPdf(_note!, saveToDevice: saveToDevice);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 10),
                Text(
                  saveToDevice ? 'Saved successfully' : 'Export ready',
                  style: GoogleFonts.poppins(fontSize: 14),
                ),
              ],
            ),
          ),
        );
      }

      // Trigger Interstitial Ad after a successful export action
      if (mounted) {
        context.read<AdService>().showInterstitialAd();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Export failed: $e',
              style: GoogleFonts.poppins(fontSize: 14),
            ),
            backgroundColor: cs.error,
          ),
        );
      }
    }
  }

  // ─── AI Action Handler ───

  Future<String> _handleAiAction(String action) async {
    final aiService = AiService(ApiKeyService(), context.read<AppConfigService>());
    final controller = context.read<NotesController>();

    switch (action) {
      case 'Summarise':
        final body = _quillController.document.toPlainText();
        if (body.trim().isEmpty) return 'Write something first to summarise.';
        final summary = await aiService.summariseNote(body);
        // Also save the summary to the note
        if (_note != null &&
            !summary.startsWith('No ') &&
            !summary.startsWith('AI request failed')) {
          final updated = _note!.copyWith(summary: summary);
          await controller.updateNote(updated);
          _note = updated;
        }
        return summary;

      case 'Auto-tag':
        final title = _titleController.text;
        final body = _quillController.document.toPlainText();
        if (title.trim().isEmpty && body.trim().isEmpty) {
          return 'Write something first to generate tags.';
        }
        final tags = await aiService.generateTags(title, body);
        if (tags.isEmpty) return 'Could not generate tags.';
        // Save tags to the note
        if (_note != null) {
          final updated = _note!.copyWith(tags: tags);
          await controller.updateNote(updated);
          _note = updated;
        }
        return 'Tags: ${tags.join(', ')}';

      case 'Ask AI':
        // Show a dialog to ask a question
        final question = await _showQuestionDialog();
        if (question == null || question.trim().isEmpty) {
          return 'No question asked.';
        }
        final contextNotes = _note != null ? [_note!] : <Note>[];
        if (contextNotes.isEmpty) return 'Please save the note first.';
        return aiService.chatWithNotes(question, contextNotes);

      case 'Calculate':
        final body = _quillController.document.toPlainText();
        if (body.trim().isEmpty) return 'Write something first.';
        final result = await aiService.detectAndCalculate(body);
        return result == 'NONE' ? 'No calculation found in the note.' : result;

      default:
        return 'Unknown action.';
    }
  }

  Future<String?> _showQuestionDialog() async {
    final controller = TextEditingController();
    final cs = Theme.of(context).colorScheme;

    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Ask AI about your notes',
          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: GoogleFonts.poppins(fontSize: 15),
          decoration: InputDecoration(
            hintText: 'e.g. What meetings do I have this week?',
            hintStyle: GoogleFonts.poppins(
              fontSize: 14,
              color: cs.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Ask'),
          ),
        ],
      ),
    );
  }

  Future<void> _showTranslateDialog() async {
    if (_quillController.document.toPlainText().trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Write something first to translate.')),
        );
      }
      return;
    }

    final cs = Theme.of(context).colorScheme;
    final languages = [
      'Spanish',
      'French',
      'German',
      'Chinese',
      'Japanese',
      'Korean',
      'Italian',
      'Portuguese',
      'Russian',
    ];

    String? selectedLanguage = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(
            'Select Language',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: languages.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(languages[index], style: GoogleFonts.poppins()),
                  onTap: () => Navigator.pop(ctx, languages[index]),
                );
              },
            ),
          ),
        );
      },
    );

    if (selectedLanguage == null) return;

    if (!mounted) return;

    // Show Loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) =>
          Center(child: CircularProgressIndicator(color: cs.primary)),
    );

    try {
      final aiService = AiService(ApiKeyService(), context.read<AppConfigService>());
      final translatedText = await aiService.translateText(
        _quillController.document.toPlainText(),
        selectedLanguage,
      );

      if (!mounted) return;
      Navigator.pop(context); // close loading

      // Show result dialog
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(
            'Translated to $selectedLanguage',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
          ),
          content: SingleChildScrollView(
            child: Text(
              translatedText,
              style: GoogleFonts.poppins(fontSize: 15),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton.tonal(
              onPressed: () {
                _quillController.document.insert(
                  _quillController.document.length - 1,
                  '\n\n--- $selectedLanguage Translation ---\n$translatedText',
                );
                _onContentChanged();
                Navigator.pop(ctx);
              },
              child: const Text('Append'),
            ),
            FilledButton(
              onPressed: () {
                _quillController.document.replace(
                  0,
                  _quillController.document.length - 1,
                  translatedText,
                );
                _onContentChanged();
                Navigator.pop(ctx);
              },
              child: const Text('Replace'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // close loading
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('AI request failed: $e')));
    }
  }

  Future<void> _handleAutoSummarize() async {
    if (_quillController.document.toPlainText().trim().isEmpty) return;

    final cs = Theme.of(context).colorScheme;

    // Show Loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) =>
          Center(child: CircularProgressIndicator(color: cs.primary)),
    );

    try {
      final aiService = AiService(ApiKeyService(), context.read<AppConfigService>());
      final result = await aiService.generateSummaryAndTitle(
        _quillController.document.toPlainText(),
      );

      if (!context.mounted) return;
      Navigator.pop(context); // close loading

      if (result == null || result.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not generate summary.')),
        );
        return;
      }

      final suggestedTitle = result['title'] ?? '';
      final suggestedSummary = result['summary'] ?? '';

      // Show review dialog
      final accept = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(
            'AI Suggestions',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Suggested Title:',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    color: cs.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(suggestedTitle, style: GoogleFonts.poppins(fontSize: 15)),
                const SizedBox(height: 16),
                Text(
                  'Summary:',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    color: cs.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  suggestedSummary,
                  style: GoogleFonts.poppins(fontSize: 15),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Discard'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Apply'),
            ),
          ],
        ),
      );

      if (accept == true) {
        setState(() {
          if (suggestedTitle.isNotEmpty) {
            _titleController.text = suggestedTitle;
          }
          if (suggestedSummary.isNotEmpty) {
            _quillController.document.insert(0, '$suggestedSummary\n\n');
          }
          _onContentChanged();
        });
      }
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context); // close loading
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Summarization failed: $e')));
    }
  }

  void _showShareCardDialog() {
    if (_note == null) return;

    // Ensure the current edits are in the note before sharing
    final updatedNote = _note!.copyWith(
      title: _titleController.text.trim(),
      body: _quillController.document.toPlainText().trim(),
    );

    showDialog(
      context: context,
      builder: (ctx) => ShareCardDialog(note: updatedNote),
    );
  }

  Future<void> _handleChatFromAppBar() async {
    final response = await _handleAiAction('Ask AI');
    if (!mounted || response == 'No question asked.') return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'AI Response',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
        content: SingleChildScrollView(
          child: Text(response, style: GoogleFonts.poppins(fontSize: 15)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // ─── Build ───

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) {
          final navigator = Navigator.of(context);
          final shouldPop = await _onWillPop();
          if (shouldPop && mounted) navigator.pop();
        }
      },
      child: Scaffold(
        appBar: _buildAppBar(cs),
        body: Column(
          children: [
            // ─── Editor body ───
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title field
                    TextField(
                      controller: _titleController,
                      onChanged: (_) => _onContentChanged(),
                      style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Note title…',
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        contentPadding: EdgeInsets.zero,
                        hintStyle: GoogleFonts.poppins(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.35),
                        ),
                      ),
                      maxLines: null,
                      textCapitalization: TextCapitalization.sentences,
                    ),

                    const SizedBox(height: 4),

                    // Body field
                    quill.QuillEditor.basic(
                      controller: _quillController,
                    ),

                    // ─── Checklist section ───
                    if (_showChecklist) ...[
                      const SizedBox(height: 16),
                      ChecklistWidget(
                        items: _checklistItems,
                        onChanged: (items) {
                          _checklistItems = items;
                          _onContentChanged();
                        },
                      ),
                    ],

                    // ─── Attachments section ───
                    if (_attachments.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _attachments.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final att = entry.value;
                          IconData iconData = Icons.insert_drive_file_rounded;
                          Color iconColor = cs.primary;
                          
                          if (att['type'] == 'image') {
                            iconData = Icons.image_rounded;
                            iconColor = Colors.purple;
                          } else if (att['type'] == 'pdf') {
                            iconData = Icons.picture_as_pdf_rounded;
                            iconColor = Colors.red;
                          } else if (att['type'] == 'doc' || att['type'] == 'docx') {
                            iconData = Icons.description_rounded;
                            iconColor = Colors.blue;
                          } else if (att['type'] == 'mp3' || att['type'] == 'wav') {
                            iconData = Icons.audio_file_rounded;
                            iconColor = Colors.orange;
                          }

                          return Chip(
                            avatar: Icon(iconData, color: iconColor, size: 18),
                            label: Text(
                              att['name'] ?? 'File',
                              style: GoogleFonts.poppins(fontSize: 12),
                            ),
                            onDeleted: () => _removeAttachment(idx),
                            deleteIcon: const Icon(Icons.close_rounded, size: 16),
                            backgroundColor: cs.surfaceContainerHigh,
                            side: BorderSide.none,
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // ─── Formatting toolbar ───
            _FormattingToolbar(
              onBold: _insertBold,
              onItalic: _insertItalic,
              onUnderline: _insertUnderline,
              onStrikethrough: _insertStrikethrough,
              onBullet: _insertBullet,
              onChecklist: _toggleChecklist,
              checklistActive: _showChecklist,
              onOcr: _pickImageAndExtractText,
              onAttachImage: _pickImage,
              onAttachFile: _pickFile,
            ),

            // ─── Word / character count ───
            _StatsBar(wordCount: _wordCount, charCount: _charCount),

            // ─── AI action bar ───
            AiActionBar(onAction: (action) => _handleAiAction(action)),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(ColorScheme cs) {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () async {
          if (_hasUnsavedChanges) {
            final shouldPop = await _onWillPop();
            if (shouldPop && mounted) Navigator.pop(context);
          } else {
            Navigator.pop(context);
          }
        },
      ),
      title: _SaveStatusIndicator(status: _saveStatus),
      centerTitle: true,
      actions: [
        // AI Chat
        IconButton(
          icon: const Icon(Icons.chat_bubble_outline_rounded),
          tooltip: 'Note-Level Chat',
          onPressed: () => _handleChatFromAppBar(),
        ),
        // Translate
        IconButton(
          icon: const Icon(Icons.translate_rounded),
          tooltip: 'Translate',
          onPressed: () => _showTranslateDialog(),
        ),
        // Export as PDF
        IconButton(
          icon: const Icon(Icons.picture_as_pdf_outlined),
          tooltip: 'Export as PDF',
          onPressed: () => _showExportOptions(),
        ),
        // Manual save button
        IconButton(
          icon: const Icon(Icons.check_rounded),
          tooltip: AppStrings.save,
          onPressed: () async {
            await _saveNote();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(AppStrings.noteSaved),
                  duration: Duration(seconds: 1),
                ),
              );
            }
          },
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded),
          onSelected: (val) {
            if (val == 'auto_summarize') {
              _handleAutoSummarize();
            } else if (val == 'share_image') {
              _showShareCardDialog();
            }
          },
          itemBuilder: (ctx) => [
            const PopupMenuItem(
              value: 'auto_summarize',
              child: ListTile(
                leading: Icon(Icons.auto_awesome_rounded),
                title: Text('Magic Auto-Summarize'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'share_image',
              child: ListTile(
                leading: Icon(Icons.share_rounded),
                title: Text('Share as Image'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// ──────────────────────────────────────────────────────────────
/// Save Status Indicator  (idle → Saving… → Saved ✓)
/// ──────────────────────────────────────────────────────────────

enum _SaveStatus { idle, saving, saved }

class _SaveStatusIndicator extends StatelessWidget {
  final _SaveStatus status;
  const _SaveStatusIndicator({required this.status});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    switch (status) {
      case _SaveStatus.saving:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Saving…',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        );
      case _SaveStatus.saved:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_done_rounded, size: 16, color: cs.primary),
            const SizedBox(width: 6),
            Text(
              'Saved',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: cs.primary,
              ),
            ),
          ],
        );
      case _SaveStatus.idle:
        return const SizedBox.shrink();
    }
  }
}

/// ──────────────────────────────────────────────────────────────
/// Formatting Toolbar  (Bold · Italic · Bullet list)
/// ──────────────────────────────────────────────────────────────

class _FormattingToolbar extends StatelessWidget {
  final VoidCallback onBold;
  final VoidCallback onItalic;
  final VoidCallback onUnderline;
  final VoidCallback onStrikethrough;
  final VoidCallback onBullet;
  final VoidCallback onChecklist;
  final bool checklistActive;
  final VoidCallback onOcr;
  final VoidCallback onAttachImage;
  final VoidCallback onAttachFile;

  const _FormattingToolbar({
    required this.onBold,
    required this.onItalic,
    required this.onUnderline,
    required this.onStrikethrough,
    required this.onBullet,
    required this.onChecklist,
    this.checklistActive = false,
    required this.onOcr,
    required this.onAttachImage,
    required this.onAttachFile,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _ToolbarButton(
              icon: Icons.format_bold_rounded,
              tooltip: 'Bold',
              onPressed: onBold,
            ),
            _ToolbarButton(
              icon: Icons.format_italic_rounded,
              tooltip: 'Italic',
              onPressed: onItalic,
            ),
            _ToolbarButton(
              icon: Icons.format_underlined_rounded,
              tooltip: 'Underline',
              onPressed: onUnderline,
            ),
            _ToolbarButton(
              icon: Icons.format_strikethrough_rounded,
              tooltip: 'Strikethrough',
              onPressed: onStrikethrough,
            ),
            _ToolbarButton(
              icon: Icons.format_list_bulleted_rounded,
              tooltip: 'Bullet List',
              onPressed: onBullet,
            ),
            _ToolbarButton(
              icon: Icons.checklist_rounded,
              tooltip: 'Checklist',
              onPressed: onChecklist,
              isActive: checklistActive,
            ),
            const SizedBox(width: 8),
            Container(
              height: 24,
              width: 1,
              color: cs.outlineVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(width: 8),
            _ToolbarButton(
              icon: Icons.document_scanner_outlined,
              tooltip: 'Extract Text from Image',
              onPressed: onOcr,
            ),
            const SizedBox(width: 8),
            Container(
              height: 24,
              width: 1,
              color: cs.outlineVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(width: 8),
            _ToolbarButton(
              icon: Icons.image_outlined,
              tooltip: 'Attach Image',
              onPressed: onAttachImage,
            ),
            _ToolbarButton(
              icon: Icons.attach_file_rounded,
              tooltip: 'Attach File',
              onPressed: onAttachFile,
            ),
            const SizedBox(width: 16),
            // Keyboard dismiss button
            _ToolbarButton(
              icon: Icons.keyboard_hide_rounded,
              tooltip: 'Hide keyboard',
              onPressed: () => FocusScope.of(context).unfocus(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool isActive;

  const _ToolbarButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return IconButton(
      icon: Icon(
        icon,
        size: 22,
        color: isActive ? cs.primary : cs.onSurfaceVariant,
      ),
      tooltip: tooltip,
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      splashRadius: 20,
    );
  }
}

/// ──────────────────────────────────────────────────────────────
/// Stats Bar  (word count · character count)
/// ──────────────────────────────────────────────────────────────

class _StatsBar extends StatelessWidget {
  final int wordCount;
  final int charCount;

  const _StatsBar({required this.wordCount, required this.charCount});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Align(
        alignment: Alignment.centerRight,
        child: Text(
          '$wordCount words  ·  $charCount characters',
          style: GoogleFonts.poppins(
            fontSize: 10,
            letterSpacing: 0.5,
            fontWeight: FontWeight.w500,
            color: cs.onSurfaceVariant.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }
}
