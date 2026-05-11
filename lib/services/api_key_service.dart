import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// ──────────────────────────────────────────────────────────────
/// NoteFlow — API Key Service (Dual Provider)
///
/// Manages secure storage for two AI provider keys:
///  • Google Gemini  (google_generative_ai package)
///  • Alibaba Qwen   (DashScope OpenAI-compatible endpoint)
///
/// Also stores the user's active provider preference.
/// Keys are stored using shared_preferences and obfuscated via Base64.
/// ──────────────────────────────────────────────────────────────

enum AiProvider { gemini, qwen }

// AI NOTE: Service to securely manage and store AI provider keys and user preferences.
class ApiKeyService {
  static const String _geminiKey = 'gemini_api_key';
  static const String _qwenKey = 'qwen_api_key';
  static const String _activeProviderKey = 'active_ai_provider';

  // ─── Encoding Helpers ───

  String _encode(String value) {
    return base64Encode(utf8.encode(value));
  }

  String _decode(String encoded) {
    try {
      return utf8.decode(base64Decode(encoded));
    } catch (e) {
      return encoded; // Fallback in case it wasn't encoded properly
    }
  }

  // ─── Active Provider ───

  /// Returns the currently active AI provider (default: Gemini).
  // AI NOTE: Retrieves the currently active AI provider (Gemini or Qwen) from storage.
  Future<AiProvider> getActiveProvider() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_activeProviderKey);
    if (value == 'qwen') return AiProvider.qwen;
    return AiProvider.gemini;
  }

  /// Saves the active provider preference.
  // AI NOTE: Saves the user's preferred active AI provider to storage.
  Future<void> setActiveProvider(AiProvider provider) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _activeProviderKey,
      provider == AiProvider.qwen ? 'qwen' : 'gemini',
    );
  }

  // ─── Save ───

  // AI NOTE: Securely saves the Google Gemini API key.
  Future<void> saveGeminiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_geminiKey, _encode(key.trim()));
  }

  // AI NOTE: Securely saves the Alibaba Qwen API key.
  Future<void> saveQwenKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_qwenKey, _encode(key.trim()));
  }

  // ─── Read (raw — for API calls) ───

  // AI NOTE: Retrieves the raw Google Gemini API key from storage.
  Future<String?> getGeminiKey() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(_geminiKey);
    return encoded != null ? _decode(encoded) : null;
  }

  // AI NOTE: Retrieves the raw Alibaba Qwen API key from storage.
  Future<String?> getQwenKey() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(_qwenKey);
    return encoded != null ? _decode(encoded) : null;
  }

  /// Returns the API key for the currently active provider.
  // AI NOTE: Returns the API key for whichever AI provider is currently active.
  Future<String?> getActiveKey() async {
    final provider = await getActiveProvider();
    return provider == AiProvider.gemini ? getGeminiKey() : getQwenKey();
  }

  // ─── Read (masked — for UI display) ───

  // AI NOTE: Retrieves the Gemini API key masked for safe UI display (e.g., ••••xxxx).
  Future<String?> getMaskedGeminiKey() async {
    final key = await getGeminiKey();
    return key != null && key.isNotEmpty ? _mask(key) : null;
  }

  // AI NOTE: Retrieves the Qwen API key masked for safe UI display (e.g., ••••xxxx).
  Future<String?> getMaskedQwenKey() async {
    final key = await getQwenKey();
    return key != null && key.isNotEmpty ? _mask(key) : null;
  }

  // AI NOTE: Helper function to mask a given string, showing only the last 4 characters.
  String _mask(String key) {
    if (key.length <= 8) return '••••••••';
    final last4 = key.substring(key.length - 4);
    return '•••••••••••$last4';
  }

  // ─── Check ───

  // AI NOTE: Checks if a Gemini API key is currently saved.
  Future<bool> hasGeminiKey() async {
    final key = await getGeminiKey();
    return key != null && key.isNotEmpty;
  }

  // AI NOTE: Checks if a Qwen API key is currently saved.
  Future<bool> hasQwenKey() async {
    final key = await getQwenKey();
    return key != null && key.isNotEmpty;
  }

  // ─── Delete ───

  // AI NOTE: Deletes the Gemini API key from storage.
  Future<void> deleteGeminiKey() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_geminiKey);
  }

  // AI NOTE: Deletes the Qwen API key from storage.
  Future<void> deleteQwenKey() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_qwenKey);
  }

  // ─── Test Connection ───

  /// Tests the given provider with the supplied key.
  // AI NOTE: Tests if the provided API key works by sending a simple prompt to the respective AI provider.
  Future<String> testConnection(AiProvider provider, String apiKey, String modelName) async {
    if (provider == AiProvider.gemini) {
      return _testGemini(apiKey, modelName);
    } else {
      return _testQwen(apiKey, modelName);
    }
  }

  // AI NOTE: Validates a Gemini API key by making a test API call.
  Future<String> _testGemini(String apiKey, String modelName) async {
    try {
      final response = await http
          .post(
            Uri.parse(
              'https://generativelanguage.googleapis.com/v1beta/models/'
              '$modelName:generateContent?key=$apiKey',
            ),
            headers: {'content-type': 'application/json'},
            body: jsonEncode({
              'contents': [
                {
                  'parts': [
                    {'text': 'Say "OK" in one word.'},
                  ],
                },
              ],
              'generationConfig': {'maxOutputTokens': 10},
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) return 'success';
      if (response.statusCode == 400) {
        return 'Invalid API key. Check your Google AI Studio key.';
      }
      final body = jsonDecode(response.body);
      final msg = body['error']?['message'] ?? 'Unknown error';
      return 'Error ${response.statusCode}: $msg';
    } catch (e) {
      return 'Connection failed: $e';
    }
  }

  // AI NOTE: Validates a Qwen API key by making a test API call.
  Future<String> _testQwen(String apiKey, String modelName) async {
    try {
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
              'model': modelName,
              'messages': [
                {'role': 'user', 'content': 'Say "OK" in one word.'},
              ],
              'max_tokens': 10,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) return 'success';
      if (response.statusCode == 401) {
        return 'Invalid API key. Check your DashScope key.';
      }
      final body = jsonDecode(response.body);
      final msg =
          body['error']?['message'] ?? body['message'] ?? 'Unknown error';
      return 'Error ${response.statusCode}: $msg';
    } catch (e) {
      return 'Connection failed: $e';
    }
  }
}
