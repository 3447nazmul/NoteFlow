/// Utility for parsing and processing note text.
class TextParser {
  TextParser._();

  /// Extracts hashtag-style tags from text (e.g. #work #ideas).
  static List<String> extractTags(String text) {
    final regex = RegExp(r'#(\w+)');
    return regex.allMatches(text).map((m) => m.group(1)!).toSet().toList();
  }

  /// Returns word count of the given text.
  static int wordCount(String text) {
    if (text.trim().isEmpty) return 0;
    return text.trim().split(RegExp(r'\s+')).length;
  }

  /// Estimated reading time in minutes (average 200 wpm).
  static int readingTimeMinutes(String text) {
    final words = wordCount(text);
    return (words / 200).ceil().clamp(1, 9999);
  }
}
