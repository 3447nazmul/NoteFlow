import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;

import '../features/notes/models/note_model.dart';
import 'api_key_service.dart';
import 'app_config_service.dart';

/// ──────────────────────────────────────────────────────────────
/// NoteFlow — Unified AI Service
///
/// Routes all AI requests to the user's active provider:
///  • Gemini  → google_generative_ai (gemini-3.1-flash)
///  • Qwen   → DashScope OpenAI-compatible API (qwen-turbo)
///
/// Four core functions:
///  1. summariseNote()
///  2. generateTags()
///  3. chatWithNotes()
///  4. detectAndCalculate()
/// ──────────────────────────────────────────────────────────────

// AI NOTE: Service class responsible for routing AI requests to the active provider (Gemini or Qwen).
class AiService {
  final ApiKeyService _keyService;
  final AppConfigService _appConfigService;

  AiService(this._keyService, this._appConfigService);

  // ─────────────────────────────────────────────────────────────
  // 1. Summarise Note
  // ─────────────────────────────────────────────────────────────

  // AI NOTE: Requests the AI to summarize the given note body into a few sentences.
  Future<String> summariseNote(String noteBody) async {
    if (noteBody.trim().isEmpty) return 'Nothing to summarise.';

    const systemPrompt =
        'You are a note summarisation assistant. Read the note and return '
        'a clear, concise summary in 2 to 3 sentences. Use plain language. '
        'Do not use bullet points. Do not add headings. Return only the '
        'summary text.';

    return _sendPrompt(systemPrompt, noteBody);
  }

  // ─────────────────────────────────────────────────────────────
  // 2. Generate Tags
  // ─────────────────────────────────────────────────────────────

  // AI NOTE: Requests the AI to generate relevant tags based on the note title and body.
  Future<List<String>> generateTags(String noteTitle, String noteBody) async {
    if (noteTitle.trim().isEmpty && noteBody.trim().isEmpty) return [];

    const systemPrompt =
        'You are a note tagging assistant. Read the note title and body '
        'and return 3 to 5 relevant category tags. Return only a '
        'comma-separated list of single-word or two-word tags. No '
        'explanations. No bullet points. Example output: Work, Finance, '
        'Goals, Q3 Planning';

    final userMessage = 'Title: $noteTitle\n\nBody: $noteBody';
    final response = await _sendPrompt(systemPrompt, userMessage);

    // Parse comma-separated response into a clean list
    return response
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty && t.length < 30)
        .take(5)
        .toList();
  }

  // ─────────────────────────────────────────────────────────────
  // 3. Chat With Notes
  // ─────────────────────────────────────────────────────────────

  // AI NOTE: Chats with the AI using the context of all provided notes to answer a user's question.
  Future<String> chatWithNotes(String question, List<Note> allNotes) async {
    if (question.trim().isEmpty) {
      return 'Please ask a question.';
    }

    // Build context from all notes (first 500 chars each)
    final buffer = StringBuffer();
    for (int i = 0; i < allNotes.length; i++) {
      final note = allNotes[i];
      final preview = note.body.length > 500
          ? note.body.substring(0, 500)
          : note.body;
      buffer.writeln(
        'Note ${i + 1} - Title: ${note.displayTitle} - Content: $preview',
      );
    }

    const systemPrompt =
        'You are a personal note assistant. The user has given you access '
        'to all their notes. Answer their question based only on what is '
        'in the notes. If the answer is not in the notes, say so honestly. '
        'Be concise and direct.';

    final userMessage =
        '--- MY NOTES ---\n${buffer.toString()}\n--- QUESTION ---\n$question';

    return _sendPrompt(systemPrompt, userMessage);
  }

  // ─────────────────────────────────────────────────────────────
  // 4. Detect and Calculate
  // ─────────────────────────────────────────────────────────────

  // AI NOTE: Requests the AI to detect and calculate any mathematical expression in the text.
  Future<String> detectAndCalculate(String noteText) async {
    if (noteText.trim().isEmpty) return 'NONE';

    const systemPrompt =
        'You are a calculation assistant. Read the following text. If it '
        'contains a mathematical question or calculation request, solve it '
        'and return only the numeric answer with a short label. If there '
        'is no calculation in the text, return the word NONE.';

    return _sendPrompt(systemPrompt, noteText);
  }

  // ─────────────────────────────────────────────────────────────
  // 5. Extract Text From Image (OCR)
  // ─────────────────────────────────────────────────────────────

  // AI NOTE: Uses Gemini to extract text from an image via OCR.
  Future<String> extractTextFromImage(Uint8List imageBytes) async {
    final apiKey = await _keyService.getActiveKey();

    if (apiKey == null || apiKey.isEmpty) {
      return 'No AI API key found. Add it in Settings.';
    }

    try {
      // Force using Gemini for OCR as it natively supports multimodal requests
      final model = GenerativeModel(model: _appConfigService.activeAiModel, apiKey: apiKey);

      final prompt = TextPart(
        'Extract all text from this image exactly as it is written. Do not add any extra conversation.',
      );
      final imagePart = DataPart('image/jpeg', imageBytes);

      final response = await model
          .generateContent([
            Content.multi([prompt, imagePart]),
          ])
          .timeout(const Duration(seconds: 45));

      final text = response.text;
      if (text == null || text.isEmpty) {
        return 'Could not extract any text from the image.';
      }
      return text.trim();
    } catch (e) {
      if (kDebugMode) debugPrint('❌ OCR call failed: $e');
      return 'Image extraction failed: $e';
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 6. Translate Text
  // ─────────────────────────────────────────────────────────────

  // AI NOTE: Requests the AI to translate the given text to the target language.
  Future<String> translateText(String text, String targetLanguage) async {
    if (text.trim().isEmpty) return 'Nothing to translate.';

    final systemPrompt =
        'You are a translation assistant. Translate the following text to $targetLanguage. '
        'Only return the translated text, nothing else.';

    return _sendPrompt(systemPrompt, text);
  }
  // ─────────────────────────────────────────────────────────────
  // 7. Transcribe Audio (Gemini ONLY)
  // ─────────────────────────────────────────────────────────────

  // AI NOTE: Uses Gemini to transcribe audio from the given bytes.
  Future<String> transcribeAudio(Uint8List audioBytes, String mimeType) async {
    final apiKey = await _keyService.getGeminiKey();
    if (apiKey == null || apiKey.isEmpty) {
      return 'Gemini API key is required for audio transcription.';
    }

    try {
      final model = GenerativeModel(model: _appConfigService.activeAiModel, apiKey: apiKey);

      final prompt = TextPart(
        'Transcribe this audio file accurately into text.',
      );
      final audioPart = DataPart(mimeType, audioBytes);

      final response = await model
          .generateContent([
            Content.multi([prompt, audioPart]),
          ])
          .timeout(const Duration(seconds: 120));

      final text = response.text;
      if (text == null || text.isEmpty) {
        return 'Could not extract any audio transcription.';
      }
      return text.trim();
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Audio transcription failed: $e');
      return 'Audio transcription failed: $e';
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 8. Auto-Summary & Smart Titles
  // ─────────────────────────────────────────────────────────────

  // AI NOTE: Requests the AI to generate a title and summary for the given note body, returning a parsed JSON map.
  Future<Map<String, String>?> generateSummaryAndTitle(String noteBody) async {
    if (noteBody.trim().isEmpty) return null;

    const systemPrompt =
        'You are an AI editor. Read the user text and return a JSON object with two keys: '
        '"title" (a short 3-5 word fitting title) and "summary" (a crisp 2-3 sentence summary). '
        'Return ONLY raw JSON, without any markdown formatting blocks like ```json.';

    final response = await _sendPrompt(systemPrompt, noteBody);

    try {
      final String cleanResponse = response
          .replaceAll(RegExp(r'```json\n?'), '')
          .replaceAll(RegExp(r'```\n?'), '')
          .trim();
      final jsonResponse = jsonDecode(cleanResponse) as Map<String, dynamic>;
      return {
        'title': jsonResponse['title']?.toString() ?? '',
        'summary': jsonResponse['summary']?.toString() ?? '',
      };
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to parse title/summary JSON: $e');
      return null;
    }
  }
  // ═════════════════════════════════════════════════════════════
  // Internal: Router → Gemini or Qwen
  // ═════════════════════════════════════════════════════════════

  // AI NOTE: Internal helper to send a prompt to the active AI provider.
  Future<String> _sendPrompt(String systemPrompt, String userMessage) async {
    final provider = await _keyService.getActiveProvider();
    final apiKey = await _keyService.getActiveKey();

    if (apiKey == null || apiKey.isEmpty) {
      final name = provider == AiProvider.gemini ? 'Gemini' : 'Qwen';
      return 'No $name API key found. Add it in Settings.';
    }

    try {
      if (provider == AiProvider.gemini) {
        return await _callGemini(apiKey, systemPrompt, userMessage);
      } else {
        return await _callQwen(apiKey, systemPrompt, userMessage);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ AI call failed: $e');
      return 'AI request failed: $e';
    }
  }

  // ─── Gemini ───

  // AI NOTE: Calls the Gemini API with the given prompt.
  Future<String> _callGemini(
    String apiKey,
    String systemPrompt,
    String userMessage,
  ) async {
    final model = GenerativeModel(
      model: _appConfigService.activeAiModel,
      apiKey: apiKey,
      systemInstruction: Content.system(systemPrompt),
      generationConfig: GenerationConfig(maxOutputTokens: 1024),
    );

    final response = await model
        .generateContent([Content.text(userMessage)])
        .timeout(const Duration(seconds: 30));

    final text = response.text;
    if (text == null || text.isEmpty) {
      return 'Gemini returned an empty response.';
    }
    return text.trim();
  }

  // ─── Qwen (DashScope OpenAI-compatible) ───

  // AI NOTE: Calls the Qwen API with the given prompt.
  Future<String> _callQwen(
    String apiKey,
    String systemPrompt,
    String userMessage,
  ) async {
    final response = await http
        .post(
          Uri.parse(
            'https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions',
          ),
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': _appConfigService.qwenAiModel,
            'messages': [
              {'role': 'system', 'content': systemPrompt},
              {'role': 'user', 'content': userMessage},
            ],
            'max_tokens': 1024,
          }),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      final text = body['choices']?[0]?['message']?['content'] as String? ?? '';
      return text.trim().isEmpty
          ? 'Qwen returned an empty response.'
          : text.trim();
    } else {
      final body = jsonDecode(response.body);
      final msg =
          body['error']?['message'] ?? body['message'] ?? 'Unknown error';
      return 'Qwen error ${response.statusCode}: $msg';
    }
  }
}
