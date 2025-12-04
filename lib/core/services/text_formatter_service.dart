import 'dart:convert';

class TextFormatterService {
  static final TextFormatterService _instance = TextFormatterService._internal();
  factory TextFormatterService() => _instance;
  TextFormatterService._internal();

  /// Formats AI response for display
  String formatAIResponse(String rawText) {
    if (rawText.isEmpty) return rawText;
    String text = rawText;

    // Remove unwanted tokens (e.g., $1, $2), gemma/llm tags, and markup leftovers
    text = text.replaceAll(RegExp(r'<end_of_turn>|<start_of_turn>|model|user'), '');
    text = text.replaceAll(RegExp(r'\$\d+'), ''); // Remove $1, $2 etc.
    text = text.replaceAll(RegExp(r'[*_`#~]'), '');

    // Fix punctuation with no space after
    text = text.replaceAllMapped(RegExp(r'([.!?,])([^\s])'), (m) => '${m.group(1)} ${m.group(2)}');

    // Add space before uppercase Or numbers jammed to letters
    text = text.replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) => '${m.group(1)} ${m.group(2)}');
    text = text.replaceAllMapped(RegExp(r'([a-zA-Z])([0-9])'), (m) => '${m.group(1)} ${m.group(2)}');
    text = text.replaceAllMapped(RegExp(r'([0-9])([a-zA-Z])'), (m) => '${m.group(1)} ${m.group(2)}');

    // Normalize quotes and dashes
    text = text.replaceAll('’', "'");
    text = text.replaceAll('‘', "'");
    text = text.replaceAll('“', '"');
    text = text.replaceAll('”', '"');
    text = text.replaceAll('–', '-');
    text = text.replaceAll('—', '-');

    // Remove any remaining non-text characters
    // UPDATED: Added math symbols (+-*/%=) and brackets to the allowed list
    text = text.replaceAll(RegExp(r'''[^\w\s.,!?'"+\-*/%=()\[\]<>]'''), '');

    // Remove duplicate spaces and trim
    text = text.replaceAll(RegExp(r'\s{2,}'), ' ').trim();

    // Capitalize first letter if needed
    if (text.isNotEmpty && text[0] != text[0].toUpperCase()) {
      text = '${text[0].toUpperCase()}${text.substring(1)}';
    }

    // Ensure period at end if it's a sentence and not ending in math or punctuation
    // (Optional check to avoid adding '.' after '6' if strictly math, but usually fine)
    if (text.isNotEmpty && !RegExp(r'[.!?]$').hasMatch(text)) {
      text += '.';
    }

    return text;
  }

  /// Formats response for TTS (removes extraneous chars, adds pauses if needed)
  String formatForTTS(String text) {
    text = formatAIResponse(text);
    text = text.replaceAll(RegExp(r'https?://[^\s]+'), ''); // Remove URLs
    // Note: We keep math symbols now so "3 + 3 = 6" is read as "Three plus three equals six"
    return text;
  }
}