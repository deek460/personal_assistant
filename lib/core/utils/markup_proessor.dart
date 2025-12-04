/// Utility class for processing specific markup and formatting patterns
class MarkupProcessor {
  /// Process code blocks and preserve formatting where needed
  static String processCodeBlocks(String text) {
    // Replace code blocks with plain text equivalents
    text = text.replaceAllMapped(
      RegExp(r'``````'),
          (match) {
        String language = match.group(1) ?? 'code';
        String code = match.group(2) ?? '';
        return 'Here is some $language code: ${code.trim()}';
      },
    );
    return text;
  }

  /// Process tables and convert to readable text
  static String processTables(String text) {
    // Simple table detection and conversion
    text = text.replaceAllMapped(
      RegExp(r'\|(.+)\|', multiLine: true),
          (match) {
        String row = match.group(1) ?? '';
        List<String> cells = row.split('|').map((e) => e.trim()).toList();
        return cells.where((cell) => cell.isNotEmpty).join(', ');
      },
    );
    return text;
  }

  /// Process quotes and emphasis
  static String processQuotes(String text) {
    // Block quotes: > text
    text = text.replaceAll(RegExp(r'^>\s+(.*)$', multiLine: true), r'Quote: $1');

    // Emphasis with better handling
    text = text.replaceAll(RegExp(r'\*\*(.+?)\*\*'), r'$1'); // Strong
    text = text.replaceAll(RegExp(r'__(.+?)__'), r'$1'); // Strong
    text = text.replaceAll(RegExp(r'\*(.+?)\*'), r'$1'); // Emphasis
    text = text.replaceAll(RegExp(r'_(.+?)_'), r'$1'); // Emphasis

    return text;
  }

  /// Process mathematical expressions
  static String processMath(String text) {
    // LaTeX math expressions
    text = text.replaceAll(RegExp(r'\$\$(.+?)\$\$'), r'mathematical expression: $1');
    text = text.replaceAll(RegExp(r'\$(.+?)\$'), r'$1');

    return text;
  }

  /// Comprehensive markup processing
  static String processAllMarkup(String text) {
    text = processCodeBlocks(text);
    text = processTables(text);
    text = processQuotes(text);
    text = processMath(text);
    return text;
  }
}
