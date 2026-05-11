import 'dart:io';
import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:syncfusion_flutter_pdf/pdf.dart';

// AI NOTE: Service class to handle importing and extracting text from various file formats.
class ImportService {
  /// Extracts text from a given file based on its extension.
  // AI NOTE: Extracts raw text content from a given file (supports txt, html, pdf, pptx).
  static Future<String?> extractTextFromFile(File file) async {
    try {
      final extension = file.path.split('.').last.toLowerCase();

      switch (extension) {
        case 'txt':
          return await file.readAsString();

        case 'html':
        case 'htm':
          final htmlString = await file.readAsString();
          final document = html_parser.parse(htmlString);
          return document.body?.text.trim();

        case 'pdf':
          final bytes = await file.readAsBytes();
          final document = PdfDocument(inputBytes: bytes);
          final extractor = PdfTextExtractor(document);
          final text = extractor.extractText();
          document.dispose();
          return text.trim();

        case 'pptx':
          final bytes = await file.readAsBytes();
          final archive = ZipDecoder().decodeBytes(bytes);
          final textBuffer = StringBuffer();

          final slideFiles = archive.files
              .where(
                (f) =>
                    f.name.startsWith('ppt/slides/slide') &&
                    f.name.endsWith('.xml'),
              )
              .toList();
          slideFiles.sort((a, b) {
            final aNum =
                int.tryParse(
                  RegExp(r'slide(\d+)\.xml').firstMatch(a.name)?.group(1) ??
                      '0',
                ) ??
                0;
            final bNum =
                int.tryParse(
                  RegExp(r'slide(\d+)\.xml').firstMatch(b.name)?.group(1) ??
                      '0',
                ) ??
                0;
            return aNum.compareTo(bNum);
          });

          for (final slide in slideFiles) {
            final content = utf8.decode(slide.content as List<int>);
            final matches = RegExp(
              r'<a:t[^>]*>(.*?)</a:t>',
            ).allMatches(content);
            for (final match in matches) {
              textBuffer.write('${match.group(1)} ');
            }
            textBuffer.writeln('\n');
          }
          return textBuffer.toString().trim();

        default:
          throw Exception('Unsupported file type: $extension');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error extracting text from file: $e');
      }
      return null;
    }
  }
}
