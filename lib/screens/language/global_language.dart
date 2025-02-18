import 'package:flutter/material.dart';
import 'package:translator/translator.dart';

/// 言語設定用の enum
enum Language { Japanese, English }

/// 言語設定のグローバル変数
Language selectedLanguage = Language.Japanese;

/// translator のグローバルインスタンス
final GoogleTranslator globalTranslator = GoogleTranslator();

/// 翻訳表示用ウィジェット
/// ・selectedLanguage が English の場合、translator を使って原文を英語に翻訳して表示
/// ・日本語の場合は原文をそのまま表示
class TranslatedText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;

  const TranslatedText({
    super.key,
    required this.text,
    this.style,
    this.textAlign,
  });

  @override
  _TranslatedTextState createState() => _TranslatedTextState();
}

class _TranslatedTextState extends State<TranslatedText> {
  late Future<String> translatedText;

  @override
  void initState() {
    super.initState();
    translatedText = _getTranslatedText(widget.text);
  }

  Future<String> _getTranslatedText(String text) async {
    if (selectedLanguage == Language.English) {
      final translation = await globalTranslator.translate(text, to: 'en');
      return translation.text;
    }
    return text;  // 日本語の場合はそのまま返す
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: translatedText,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // 翻訳中は原文を表示
          return Text(widget.text, style: widget.style, textAlign: widget.textAlign);
        }
        if (snapshot.hasError) {
          // エラー時は原文を表示
          return Text(widget.text, style: widget.style, textAlign: widget.textAlign);
        }
        if (snapshot.hasData) {
          // 翻訳結果が取得できた場合はそれを表示
          return Text(
            snapshot.data ?? widget.text, // snapshot.data が null なら原文を表示
            style: widget.style,
            textAlign: widget.textAlign,
          );
        }
        return Text(widget.text, style: widget.style, textAlign: widget.textAlign);
      },
    );
  }
}
