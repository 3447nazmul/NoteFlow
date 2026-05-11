import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';

import '../../../services/export_service.dart';
import '../models/note_model.dart';

// AI NOTE: A dialog that generates a beautifully styled image of the note for sharing to social media.
class ShareCardDialog extends StatefulWidget {
  final Note note;

  const ShareCardDialog({super.key, required this.note});

  @override
  State<ShareCardDialog> createState() => _ShareCardDialogState();
}

class _ShareCardDialogState extends State<ShareCardDialog> {
  final ScreenshotController _screenshotController = ScreenshotController();
  bool _isCapturing = false;

  Future<void> _shareImage() async {
    setState(() => _isCapturing = true);

    try {
      final Uint8List? imageBytes = await _screenshotController.capture();
      if (imageBytes != null && mounted) {
        final xFile = XFile.fromData(
          imageBytes,
          mimeType: 'image/png',
          name: '${widget.note.displayTitle}.png',
        );
        await Share.shareXFiles([
          xFile,
        ], text: 'Check out this note from NoteFlow!');
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to share image: $e')));
      }
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  Future<void> _saveImageLocally() async {
    setState(() => _isCapturing = true);

    try {
      final Uint8List? imageBytes = await _screenshotController.capture();
      if (imageBytes != null) {
        final filename = '${widget.note.displayTitle.replaceAll(RegExp(r'\s+'), '_')}_card.png';
        await ExportService.saveFileLocally(filename, imageBytes);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Image saved to device')),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save image: $e')));
      }
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Use the first 300 chars of the body for the preview
    final bodyPreview = widget.note.body.length > 300
        ? '${widget.note.body.substring(0, 300)}...'
        : widget.note.body;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // The card to be captured
          Screenshot(
            controller: _screenshotController,
            child: Container(
              width: 400, // Fixed width for consistent aspect ratio
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [cs.primary, cs.tertiary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.note.displayTitle,
                    style: GoogleFonts.poppins(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: cs.onPrimary,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: cs.surface.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      bodyPreview.isEmpty ? 'Empty note' : bodyPreview,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: cs.onSurface,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notes_rounded, color: cs.onPrimary, size: 24),
                      const SizedBox(width: 8),
                      Text(
                        'Created with NoteFlow',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: cs.onPrimary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(foregroundColor: cs.surface),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                onPressed: _isCapturing ? null : _saveImageLocally,
                icon: const Icon(Icons.download_rounded),
                label: const Text('Save'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _isCapturing ? null : _shareImage,
                icon: _isCapturing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.share_rounded),
                label: Text(_isCapturing ? 'Wait...' : 'Share'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
