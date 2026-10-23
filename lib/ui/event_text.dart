import 'package:flutter/material.dart';

/// KSS uses `<bi>` for bold/italic, alongside ordinary inline HTML tags.
/// This is a text-only renderer: no WebView, scripts, URLs or remote resources.
class EventText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign textAlign;
  const EventText(
    this.text, {
    super.key,
    this.style,
    this.textAlign = TextAlign.start,
  });

  static String _decode(String value) => value.replaceAllMapped(
    RegExp(
      r'&(#x[0-9a-f]+|#[0-9]+|amp|lt|gt|quot|apos|nbsp);',
      caseSensitive: false,
    ),
    (match) {
      final token = match[1]!.toLowerCase();
      if (token.startsWith('#')) {
        final hex = token.startsWith('#x');
        final code = int.tryParse(
          token.substring(hex ? 2 : 1),
          radix: hex ? 16 : 10,
        );
        if (code != null &&
            code > 0 &&
            code <= 0x10ffff &&
            (code < 0xd800 || code > 0xdfff)) {
          return String.fromCharCode(code);
        }
        return match[0]!;
      }
      return const {
        'amp': '&',
        'lt': '<',
        'gt': '>',
        'quot': '"',
        'apos': "'",
        'nbsp': '\u00a0',
      }[token]!;
    },
  );

  static TextSpan span(String source, {TextStyle? style}) {
    final spans = <InlineSpan>[];
    final active = <String>[];
    void append(String value) {
      if (value.isEmpty) return;
      spans.add(
        TextSpan(
          text: _decode(value),
          style: TextStyle(
            fontWeight: active.any((tag) => ['b', 'strong', 'bi'].contains(tag))
                ? FontWeight.bold
                : null,
            fontStyle: active.any((tag) => ['i', 'em', 'bi'].contains(tag))
                ? FontStyle.italic
                : null,
            decoration: active.contains('u') ? TextDecoration.underline : null,
          ),
        ),
      );
    }

    final tags = RegExp(
      r'<\s*(/?)\s*(bi|b|strong|i|em|u|br|p)\s*(/?)\s*>',
      caseSensitive: false,
    );
    var offset = 0;
    for (final tag in tags.allMatches(source)) {
      append(source.substring(offset, tag.start));
      final name = tag[2]!.toLowerCase();
      if (name == 'br' || name == 'p') {
        if (name == 'br' || tag[1] == '/') append('\n');
      } else if (tag[1] == '/') {
        final index = active.lastIndexOf(name);
        if (index >= 0) active.removeAt(index);
      } else {
        active.add(name);
      }
      offset = tag.end;
    }
    append(source.substring(offset));
    return TextSpan(style: style, children: spans);
  }

  @override
  Widget build(BuildContext context) =>
      Text.rich(span(text, style: style), textAlign: textAlign);
}
