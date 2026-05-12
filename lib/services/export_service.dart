import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:archive/archive_io.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../features/notes/models/note_model.dart';

/// ──────────────────────────────────────────────────────────────
/// NoteFlow — Branded Export Service
///
/// Generates branded PDF and Image exports with a promotional
/// footer: "Created with NoteFlow" + app logo placeholder.
///
/// PDF Export:
///   • Multi-page document using the `pdf` package
///   • Poppins typography, Indigo accent, professional layout
///   • Branded footer on every page with page numbers
///   • Opens system share dialog via `printing` package
///
/// Image Export:
///   • Renders a branded card to a PNG image
///   • Returns Uint8List for sharing
/// ──────────────────────────────────────────────────────────────

// AI NOTE: Service to handle generating and exporting notes as PDF or Image.
class ExportService {
  // ─── PDF Export ───

  /// Generates the branded PDF byte data.
  static Future<Uint8List> generatePdfBytes(Note note) async {
    final pdf = pw.Document(
      title: note.displayTitle,
      author: 'NoteFlow',
      creator: 'NoteFlow — Think clearly. Write freely.',
    );

    // Load a base font for the PDF
    final regularFont = await PdfGoogleFonts.notoSansBengaliRegular();
    final boldFont = await PdfGoogleFonts.notoSansBengaliBold();
    final semiBoldFont = await PdfGoogleFonts.notoSansBengaliSemiBold();

    final brandColor = PdfColor.fromHex('#4648D4');
    final lightBrandBg = PdfColor.fromHex('#F0F0FF');
    final textColor = PdfColor.fromHex('#1B1B23');
    final mutedColor = PdfColor.fromHex('#464554');

    // Load logo bytes
    Uint8List? logoBytes;
    try {
      final ByteData bytes = await rootBundle.load('assets/images/ic_launcher.png');
      logoBytes = bytes.buffer.asUint8List();
    } catch (e) {
      debugPrint('Could not load app logo for PDF: $e');
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),

        // ── Branded footer on every page ──
        footer: (context) => _buildPdfFooter(
          context,
          regularFont,
          semiBoldFont,
          brandColor,
          mutedColor,
          logoBytes,
        ),

        build: (context) => [
          // ── Title ──
          pw.Text(
            note.displayTitle,
            style: pw.TextStyle(font: boldFont, fontSize: 28, color: textColor),
          ),
          pw.SizedBox(height: 8),

          // ── Date ──
          pw.Text(
            'Last updated: ${_formatDate(note.updatedAt)}',
            style: pw.TextStyle(
              font: regularFont,
              fontSize: 11,
              color: mutedColor,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Divider(color: PdfColor.fromHex('#C7C4D7'), thickness: 0.5),
          pw.SizedBox(height: 16),

          // ── Tags ──
          if (note.tags.isNotEmpty) ...[
            pw.Wrap(
              spacing: 8,
              runSpacing: 6,
              children: note.tags.map((tag) {
                return pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: pw.BoxDecoration(
                    color: lightBrandBg,
                    borderRadius: pw.BorderRadius.circular(9999),
                  ),
                  child: pw.Text(
                    tag,
                    style: pw.TextStyle(
                      font: semiBoldFont,
                      fontSize: 10,
                      color: brandColor,
                    ),
                  ),
                );
              }).toList(),
            ),
            pw.SizedBox(height: 16),
          ],

          // ── Summary ──
          if (note.summary.isNotEmpty) ...[
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: lightBrandBg,
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(color: brandColor, width: 0.5),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'AI Summary',
                    style: pw.TextStyle(
                      font: semiBoldFont,
                      fontSize: 11,
                      color: brandColor,
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    note.summary,
                    style: pw.TextStyle(
                      font: regularFont,
                      fontSize: 12,
                      color: textColor,
                      lineSpacing: 4,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
          ],

          // ── Body text ──
          pw.Text(
            note.body.isNotEmpty ? note.body : '(No content)',
            style: pw.TextStyle(
              font: regularFont,
              fontSize: 13,
              color: textColor,
              lineSpacing: 6,
            ),
          ),

          // ── Checklist ──
          if (note.checklist.isNotEmpty) ...[
            pw.SizedBox(height: 20),
            pw.Divider(color: PdfColor.fromHex('#C7C4D7'), thickness: 0.5),
            pw.SizedBox(height: 12),
            pw.Text(
              'Checklist',
              style: pw.TextStyle(
                font: semiBoldFont,
                fontSize: 14,
                color: textColor,
              ),
            ),
            pw.SizedBox(height: 8),
            ...note.checklist.map((item) {
              final checked = item['checked'] as bool? ?? false;
              final text = item['text'] as String? ?? '';
              return pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 4),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(
                      width: 14,
                      height: 14,
                      margin: const pw.EdgeInsets.only(top: 2, right: 8),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(
                          color: checked ? brandColor : mutedColor,
                          width: 1.5,
                        ),
                        borderRadius: pw.BorderRadius.circular(3),
                        color: checked ? brandColor : PdfColors.white,
                      ),
                      child: checked
                          ? pw.Center(
                              child: pw.Text(
                                '✓',
                                style: pw.TextStyle(
                                  font: boldFont,
                                  fontSize: 9,
                                  color: PdfColors.white,
                                ),
                              ),
                            )
                          : pw.SizedBox(),
                    ),
                    pw.Expanded(
                      child: pw.Text(
                        text,
                        style: pw.TextStyle(
                          font: regularFont,
                          fontSize: 12,
                          color: checked ? mutedColor : textColor,
                          decoration: checked
                              ? pw.TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );

    return await pdf.save();
  }

  /// Generates a branded PDF and opens the system share dialog or saves locally.
  static Future<void> exportAsPdf(Note note, {bool saveToDevice = false}) async {
    final bytes = await generatePdfBytes(note);
    final filename = '${_sanitizeFilename(note.displayTitle)}.pdf';

    if (saveToDevice) {
      await saveFileLocally(filename, bytes);
    } else {
      await Printing.sharePdf(bytes: bytes, filename: filename);
    }
  }

  /// Exports the note as PDF and bundles attached files into a ZIP archive.
  static Future<void> exportWithAttachments(Note note, {required bool saveToDevice}) async {
    final archive = Archive();

    // 1. Add the generated PDF
    final pdfBytes = await generatePdfBytes(note);
    final pdfFilename = '${_sanitizeFilename(note.displayTitle)}.pdf';
    archive.addFile(ArchiveFile(pdfFilename, pdfBytes.length, pdfBytes));

    // 2. Add all local attachments
    for (var attachment in note.attachments) {
      final path = attachment['path'];
      final name = attachment['name'];
      if (path != null && name != null) {
        final file = File(path);
        if (await file.exists()) {
          final fileBytes = await file.readAsBytes();
          archive.addFile(ArchiveFile('attachments/$name', fileBytes.length, fileBytes));
        }
      }
    }

    // Encode the archive
    final zipEncoder = ZipEncoder();
    final zipBytes = zipEncoder.encode(archive);

    final zipFilename = '${_sanitizeFilename(note.displayTitle)}_export.zip';

    if (saveToDevice) {
      await saveFileLocally(zipFilename, Uint8List.fromList(zipBytes));
    } else {
      // Create a temporary file to share
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/$zipFilename');
      await tempFile.writeAsBytes(zipBytes);
      
      await Share.shareXFiles([XFile(tempFile.path)], text: 'Exported note with attachments from NoteFlow.');
    }
  }

  /// Saves a file directly to the device's Downloads directory (Android/iOS/Desktop).
  static Future<void> saveFileLocally(String filename, Uint8List bytes) async {
    try {
      Directory? directory;
      if (Platform.isAndroid) {
        directory = Directory('/storage/emulated/0/Download');
        if (!await directory.exists()) {
          directory = await getExternalStorageDirectory();
        }
      } else if (Platform.isIOS) {
        directory = await getApplicationDocumentsDirectory();
      } else {
        directory = await getDownloadsDirectory();
      }

      if (directory != null) {
        final file = File('${directory.path}/$filename');
        await file.writeAsBytes(bytes);
        debugPrint('File saved locally at: ${file.path}');
      } else {
        throw Exception("Could not locate storage directory.");
      }
    } catch (e) {
      debugPrint('Error saving file locally: $e');
      throw Exception('Failed to save file: $e');
    }
  }

  /// Builds the branded footer for every PDF page.
  // AI NOTE: Builds the branded footer (logo, text, page number) for every PDF page.
  static pw.Widget _buildPdfFooter(
    pw.Context context,
    pw.Font regularFont,
    pw.Font semiBoldFont,
    PdfColor brandColor,
    PdfColor mutedColor,
    Uint8List? logoBytes,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: PdfColors.grey300, width: 0.4),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          // ── Branded text ──
          pw.Row(
            children: [
              // App logo or fallback
              if (logoBytes != null)
                pw.ClipRRect(
                  horizontalRadius: 3,
                  verticalRadius: 3,
                  child: pw.Container(
                    width: 14,
                    height: 14,
                    child: pw.Image(pw.MemoryImage(logoBytes)),
                  ),
                )
              else
                pw.Container(
                  width: 14,
                  height: 14,
                  decoration: pw.BoxDecoration(
                    color: brandColor,
                    borderRadius: pw.BorderRadius.circular(3),
                  ),
                  child: pw.Center(
                    child: pw.Text(
                      'N',
                      style: pw.TextStyle(
                        font: semiBoldFont,
                        fontSize: 8,
                        color: PdfColors.white,
                      ),
                    ),
                  ),
                ),
              pw.SizedBox(width: 6),
              pw.Text(
                'Created with ',
                style: pw.TextStyle(
                  font: regularFont,
                  fontSize: 7.5,
                  color: mutedColor,
                ),
              ),
              pw.Text(
                'NoteFlow',
                style: pw.TextStyle(
                  font: semiBoldFont,
                  fontSize: 7.5,
                  color: brandColor,
                ),
              ),
            ],
          ),
          // ── Page number ──
          pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: pw.TextStyle(
              font: regularFont,
              fontSize: 7.5,
              color: mutedColor,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Image Export ───

  /// Generates a branded image of the note as a PNG.
  /// Uses a GlobalKey to capture a widget as an image.
  // AI NOTE: Generates a branded PNG image of the note by rendering a hidden widget.
  static Future<Uint8List?> exportAsImage(
    Note note,
    BuildContext context,
  ) async {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Build the widget to capture
    final widget = _BrandedNoteCard(
      note: note,
      colorScheme: cs,
      isDark: isDark,
    );

    // Render to image using RepaintBoundary
    final key = GlobalKey();
    final overlay = OverlayEntry(
      builder: (_) => Positioned(
        left: -9999,
        child: RepaintBoundary(
          key: key,
          child: Material(
            color: Colors.transparent,
            child: SizedBox(width: 420, child: widget),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(overlay);
    await Future.delayed(const Duration(milliseconds: 100));

    try {
      final boundary =
          key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } finally {
      overlay.remove();
    }
  }

  // ─── Helpers ───

  // AI NOTE: Helper to format a DateTime into a readable string (e.g., "Jan 1, 2024").
  static String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  // AI NOTE: Sanitizes a string to be used safely as a filename.
  static String _sanitizeFilename(String name) {
    return name
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '_')
        .toLowerCase();
  }
}

/// ──────────────────────────────────────────────────────────────
/// Branded Note Card — used for image export
/// ──────────────────────────────────────────────────────────────

// AI NOTE: A widget representing the note's branded layout, used specifically for image export rendering.
class _BrandedNoteCard extends StatelessWidget {
  final Note note;
  final ColorScheme colorScheme;
  final bool isDark;

  const _BrandedNoteCard({
    required this.note,
    required this.colorScheme,
    required this.isDark,
  });

  // AI NOTE: Builds the UI for the branded note card.
  @override
  Widget build(BuildContext context) {
    final cs = colorScheme;
    final bgColor = isDark ? const Color(0xFF0B1326) : const Color(0xFFFCF8FF);
    final cardColor = isDark
        ? const Color(0xFF171F33)
        : const Color(0xFFEFECF8);
    final brandIndigo = const Color(0xFF6366F1);

    return Container(
      padding: const EdgeInsets.all(24),
      color: bgColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Card ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  note.displayTitle,
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),

                // Body preview
                if (note.body.isNotEmpty)
                  Text(
                    note.body.length > 500
                        ? '${note.body.substring(0, 500)}…'
                        : note.body,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      height: 1.7,
                      color: cs.onSurfaceVariant,
                    ),
                    maxLines: 12,
                    overflow: TextOverflow.ellipsis,
                  ),

                // Tags
                if (note.tags.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: note.tags.take(5).map((tag) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: brandIndigo.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(9999),
                        ),
                        child: Text(
                          tag,
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: brandIndigo,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Branded footer ──
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.asset(
                  'assets/images/ic_launcher.png',
                  width: 14,
                  height: 14,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'Created with ',
                style: GoogleFonts.poppins(
                  fontSize: 8,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ),
              Text(
                'NoteFlow',
                style: GoogleFonts.poppins(
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  color: brandIndigo,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
