// ignore_for_file: file_names

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

// ignore: slash_for_doc_comments
/**
 * 유니티의 rich text를 사용하기 위한 컴퍼넌트
 * 
 * 지원 태그:
 * - b : 굵게
 * - i : 기울여쓰기
 * - u : 밑줄
 * - color : 글씨 색깔, #ffffff 형식 또는 컬러이름 useage) <color=#ffffff>색깔</color> 또는 <color=red>색깔</color>
 * - size : 글씨 크기 useage) <size=16>크기</size>
 * - link : 하이퍼링크 useage) <link=https://www.google.com>링크</link>
 * 
 * 샘플 텍스트: 'You have <b><i>pushed</i></b>\nthe <b><size=20><color=orange>button</color></size></b> this many <size=32><u>times</u></size>\n<link=https://www.google.com>Google 바로가기</link>'
 */
class CustomRichText extends StatefulWidget {
  final String text;
  final TextStyle? style;

  const CustomRichText(
    this.text, {
    Key? key,
    this.style,
  }) : super(key: key);

  @override
  State<CustomRichText> createState() => _CustomRichTextState();
}

class _CustomRichTextState extends State<CustomRichText> {
  List<TextInfo> _infos = [];

  // 텍스트 분석을 토대로 TextSpan을 생성한다.
  List<TextSpan> getChildren() {
    if (_infos.isEmpty) {
      _infos = splitText(widget.text);
    }
    if (_infos.isEmpty) return [];

    List<TextSpan> children = [];
    for (var info in _infos) {
      var textSpan = makeChild(info);
      children.add(textSpan);
    }
    return children;
  }

  // 입력받은 리치텍스트를 파싱한다.
  List<TextInfo> splitText(String text) {
    try {
      final List<TextInfo> result = [];

      // 태그 기호가 없으면 전부 일반 텍스트 이다.
      final index = text.indexOf('<');
      if (index == -1) {
        return [TextInfo(text)];
      }

      // 태그 없이 나오는 첫 텍스트는 RichText의 text에 매핑 가능하다.
      // 하지만 사용하지 않는다.
      var headText = text.substring(0, index);
      result.add(TextInfo(headText));

      // 이후 텍스트를 파싱한다.
      // 가장 바깥쪽 태그를 기준으로 원본 텍스트를 나눈다.
      final List<String> spletedText = [];
      var next = text.substring(index, text.length);
      while (true) {
        var splited = "";
        if (next.isEmpty) break;
        var startIdx = next.indexOf('<');
        if (startIdx == -1) {
          spletedText.add(next);
          break;
        }
        if (startIdx > 0) {
          splited = next.substring(0, startIdx);
          spletedText.add(splited);
          next = next.substring(startIdx);
          continue;
        }
        var tagIndex = next.indexOf('>');
        if (tagIndex == -1) {
          spletedText.add(next);
          break;
        }
        final tagText = next.substring(0, tagIndex + 1);
        final tag = Tag(tagText);
        final endTag = tag.endTag;
        final endIndex = next.indexOf(endTag);
        if (endIndex == -1) {
          spletedText.add(next);
          break;
        }
        splited = next.substring(0, endIndex + endTag.length);
        spletedText.add(splited);

        next = next.substring(splited.length);
      }

      // 나누어진 텍스트를 기준으로 태그를 읽어 파싱한다.
      for (var text in spletedText) {
        final info = makeInfo(text);
        result.add(info);
      }
      return result;
    } catch (e) {
      return [TextInfo(text)];
    }
  }

  // 태그를 분석해 정보를 추출한다.
  TextInfo makeInfo(String text) {
    final info = TextInfo("");
    if (text[0] != '<') {
      if (text.contains('<')) {
        info.text = text.substring(0, text.indexOf('<'));
      } else {
        info.text = text;
      }
      return info;
    }

    var next = text;

    while (true) {
      if (next.indexOf('</') == 0) {
        info.text = next;
        break;
      }
      final tagIndex = next.indexOf('>');
      if (tagIndex == -1) {
        info.text = next;
        break;
      }
      final tagText = next.substring(0, tagIndex + 1);
      final tag = Tag(tagText);
      if (next.contains(tag.endTag) == false) {
        info.text = next;
        break;
      }
      final tagType = tag.getTagType();
      info.styleTags.add(TagInfo(tagType, tag.value));
      next = next.substring(tag.tag.length);
      if (tag.value.isNotEmpty) {
        next = next.substring(tag.value.length + 1);
      }
      next = next.substring(0, next.length - tag.endTag.length);
    }

    return info;
  }

  // 추출한 정보를 바탕으로 TextSpan을 생성한다.
  TextSpan makeChild(TextInfo info) {
    final text = info.text;
    final style = getStyle(info);

    // 링크가 있는 경우 처리
    if (info.styleTags.any((element) => element.tag == RichTextTag.link)) {
      var tagInfo = info.styleTags.where((element) => element.tag == RichTextTag.link).first;
      var url = tagInfo.value;
      return TextSpan(
        style: style,
        text: text,
        recognizer: TapGestureRecognizer()
          ..onTap = () async {
            Uri uri = Uri.parse(url);
            await launchUrl(uri);
          },
      );
    }

    return TextSpan(text: text, style: style);
  }

  // 스타일을 설정한다.
  TextStyle getStyle(TextInfo info) {
    var style = const TextStyle();
    for (var tagInfo in info.styleTags) {
      switch (tagInfo.tag) {
        case RichTextTag.b:
          style = style.merge(const TextStyle(fontWeight: FontWeight.bold));
          break;
        case RichTextTag.i:
          style = style.merge(const TextStyle(fontStyle: FontStyle.italic));
          break;
        case RichTextTag.u:
          style = style.merge(const TextStyle(decoration: TextDecoration.underline));
          break;
        case RichTextTag.color:
          if (tagInfo.value.contains('#')) {
            style = style.merge(TextStyle(color: HexColor.fromHex(tagInfo.value)));
          } else {
            style = style.merge(TextStyle(color: VtokColor.fromName(tagInfo.value)));
          }
          break;
        case RichTextTag.size:
          style = style.merge(TextStyle(fontSize: double.parse(tagInfo.value)));
          break;
        case RichTextTag.link:
          // 링크에는 따로 스타일 지정이 없다.
          break;
        default:
          break;
      }
    }
    return style;
  }

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        text: '',
        style: widget.style ?? DefaultTextStyle.of(context).style,
        children: getChildren(),
      ),
    );
  }
}

enum RichTextTag {
  unknown,
  b,
  i,
  u,
  color,
  size,
  link,
}

class TextInfo {
  String text;
  List<TagInfo> styleTags = [];

  TextInfo(this.text);
}

class TagInfo {
  RichTextTag tag;
  String value;

  TagInfo(this.tag, this.value);
}

class Tag {
  late String tag;
  late String value;
  late String endTag;
  late String _tagStr;

  Tag(tagText) {
    _setTag(tagText);
    _setTagStr();
    _setEndTag(tagText);
    _setValue(tagText);
  }

  _setTag(String tag) {
    if (tag.contains("=")) {
      var index = tag.indexOf("=");
      this.tag = tag.substring(0, index) + ">"; //<color=#ffff>
    } else {
      this.tag = tag;
    }
    this.tag = this.tag.toLowerCase();
    // window.console.log("태그: " + tag);
  }

  _setTagStr() {
    _tagStr = tag.substring(1, tag.length - 1);
    // window.console.log("태그 문자열: " + _tagStr);
  }

  _setEndTag(String tag) {
    if (tag.contains("=")) {
      var index = tag.indexOf("=");
      endTag = "</" + tag.substring(1, index) + ">"; //<color=#ffff> 13
    } else {
      endTag = "</" + tag.substring(1);
    }
    // window.console.log("클로즈 태그: " + endTag);
  }

  _setValue(String tag) {
    if (tag.contains("=")) {
      var index = tag.indexOf("=");
      value = tag.substring(index + 1);
      value = value.substring(0, value.length - 1);
    } else {
      value = '';
    }
    value = value.toLowerCase();
    // window.console.log("값: " + value);
  }

  RichTextTag getTagType() {
    switch (_tagStr) {
      case "b":
        return RichTextTag.b;
      case "i":
        return RichTextTag.i;
      case "u":
        return RichTextTag.u;
      case "color":
        return RichTextTag.color;
      case "size":
        return RichTextTag.size;
      case "link":
        return RichTextTag.link;
      default:
        return RichTextTag.unknown;
    }
  }
}

extension HexColor on Color {
  /// String is in the format "aabbcc" or "ffaabbcc" with an optional leading "#".
  static Color fromHex(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  /// Prefixes a hash sign if [leadingHashSign] is set to `true` (default is `true`).
  String toHex({bool leadingHashSign = true}) => '${leadingHashSign ? '#' : ''}'
      '${alpha.toRadixString(16).padLeft(2, '0')}'
      '${red.toRadixString(16).padLeft(2, '0')}'
      '${green.toRadixString(16).padLeft(2, '0')}'
      '${blue.toRadixString(16).padLeft(2, '0')}';
}

extension VtokColor on Color {
  static Color fromName(String colorName) {
    switch (colorName.toLowerCase()) {
      case "red":
        return Colors.red;
      case "blue":
        return Colors.blue;
      case "yellow":
        return Colors.yellow;
      case "pink":
        return Colors.pink;
      case "orange":
        return Colors.orange;
      case "green":
        return Colors.green;
      case "grey":
        return Colors.grey;
      case "sky":
        return Colors.lightBlue;
      case "brown":
        return Colors.brown;
      case "cyan":
        return Colors.cyan;
      case "purple":
        return Colors.purple;
      case "white":
        return Colors.white;
      case "black":
        return Colors.black;
      default:
        return Colors.black;
    }
  }
}
