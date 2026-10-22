class ChatLinkMatch {
  final int start;
  final int end;
  final String text;
  final String url;

  const ChatLinkMatch({
    required this.start,
    required this.end,
    required this.text,
    required this.url,
  });
}

class ChatLinkUtils {
  ChatLinkUtils._();

  static final _urlPattern = RegExp(
    r'(?:https?:\/\/|www\.)[^\s<>]+',
    caseSensitive: false,
  );

  static List<ChatLinkMatch> findLinks(String text) {
    final links = <ChatLinkMatch>[];
    for (final match in _urlPattern.allMatches(text)) {
      var end = match.end;
      while (end > match.start && '.,!?;:)]}'.contains(text[end - 1])) {
        end--;
      }
      if (end <= match.start) continue;
      final linkText = text.substring(match.start, end);
      final url = linkText.toLowerCase().startsWith('www.')
          ? 'https://$linkText'
          : linkText;
      links.add(ChatLinkMatch(
        start: match.start,
        end: end,
        text: linkText,
        url: url,
      ));
    }
    return links;
  }
}
