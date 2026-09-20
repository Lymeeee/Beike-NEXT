import 'dart:convert';
import 'dart:io';

import '/types/courses.dart';

/// 亲情课表文本码：课表 JSON 经 gzip 压缩后 base64Url 编码，形如 `BKNKC1:<code>`。
/// 文本码供用户在微信等渠道互相发送，不经过服务器。
class FamilyCurriculumCodec {
  /// 前缀含格式版本号，便于以后兼容旧版本
  static const String prefix = 'BKNKC1:';

  static String encode(FamilyCurriculum curriculum) {
    final packed = gzip.encode(utf8.encode(jsonEncode(curriculum.toJson())));
    return '$prefix${base64Url.encode(packed)}';
  }

  /// 解析文本码；输入无效时抛 [FormatException]，其 message 可直接展示给用户。
  static FamilyCurriculum decode(String raw) {
    final text = raw.replaceAll(RegExp(r'\s+'), '');
    if (text.isEmpty) throw const FormatException('请先粘贴对方发来的课表文本码');
    if (!text.startsWith(prefix)) {
      throw const FormatException('这不是一段有效的课表文本码');
    }

    dynamic json;
    try {
      final packed = base64Url.decode(text.substring(prefix.length));
      json = jsonDecode(utf8.decode(gzip.decode(packed)));
    } catch (_) {
      throw const FormatException('文本码已损坏，请确认复制完整');
    }
    if (json is! Map) throw const FormatException('文本码内容无法识别');

    try {
      final data = FamilyCurriculum.fromJson(json.cast<String, dynamic>());
      if (data.classes.isEmpty && data.periods.isEmpty) {
        throw const FormatException('这段文本码里没有课表内容');
      }
      return data;
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('文本码内容无法识别');
    }
  }
}
