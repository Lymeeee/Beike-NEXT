import 'package:dio/dio.dart';

/// 匹配简介里的链接（排除空白与常见中英文标点，避免把句末标点带进 URL）
final RegExp _urlPattern =
    RegExp(r'''https?://[^\s<>()\[\]"'，。；：、！？（）【】]+''');

/// 更新检查用的 GitHub Release 信息
class GitHubRelease {
  /// 归一化版本号（去掉 v 前缀与 +build，如 1.2.3；tag 无法解析时为空串）
  final String version;

  /// releases 简介原文（Markdown）
  final String body;

  /// release 页面地址
  final String htmlUrl;

  GitHubRelease({
    required this.version,
    required this.body,
    required this.htmlUrl,
  });

  /// 简介里的北科云盘镜像链接，没有则为 null
  String? get mirrorUrl {
    for (final match in _urlPattern.allMatches(body)) {
      final url = match.group(0)!;
      if (url.contains('yunpan.ustb.edu.cn')) {
        // 链接写在句末时可能带上英文句号
        return url.replaceFirst(RegExp(r'[.,]+$'), '');
      }
    }
    return null;
  }

  /// 展示用简介：隐去链接（链接会变成按钮）、去掉常见 Markdown 记号
  String get notes {
    final cleaned = body
        .replaceAll(_urlPattern, '')
        .replaceAll(RegExp(r'^#{1,6}\s*', multiLine: true), '')
        .replaceAll('**', '')
        .replaceAll(RegExp(r'^[-*+]\s+', multiLine: true), '· ');

    final lines = <String>[];
    for (var line in cleaned.split('\n')) {
      line = line.trim().replaceFirst(RegExp(r'[\s。，、；,.;]+$'), '');
      if (line.isEmpty) continue;
      // 链接被移除后只剩标签的行（如"北科云盘镜像："）由按钮替代，不再展示
      if (line.endsWith('：') || line.endsWith(':')) continue;
      lines.add(line);
    }
    return lines.join('\n');
  }
}

/// 版本更新检查：拉取 GitHub Releases 的最新正式版（跳过预发布）。
///
/// 两个 App 共用同一套实现，仅仓库地址不同：
/// Pearl → Lymeeee/Pearl，Beike NEXT → Lymeeee/Beike-NEXT。
class UpdateService {
  static const String repo = 'Lymeeee/Beike-NEXT';

  final Dio _dio;

  UpdateService({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 6),
              receiveTimeout: const Duration(seconds: 10),
            ));

  /// 拉取最新正式版；tag 不是 vX.Y.Z 形式时返回 null
  Future<GitHubRelease?> fetchLatestRelease() async {
    final resp = await _dio.get(
      'https://api.github.com/repos/$repo/releases/latest',
      options: Options(headers: {
        'Accept': 'application/vnd.github+json',
        'User-Agent': 'Pearl-UpdateCheck',
      }),
    );
    final map = (resp.data as Map).cast<String, dynamic>();
    final version = normalizeVersion('${map['tag_name'] ?? ''}');
    if (version.isEmpty) return null;
    return GitHubRelease(
      version: version,
      body: '${map['body'] ?? ''}',
      htmlUrl: '${map['html_url'] ?? 'https://github.com/$repo/releases'}',
    );
  }
}

/// 归一化版本号：去掉 v 前缀与 +build；不是数字点分形式时返回空串
String normalizeVersion(String raw) {
  var version = raw.trim();
  if (version.startsWith('v') || version.startsWith('V')) {
    version = version.substring(1);
  }
  final plus = version.indexOf('+');
  if (plus >= 0) version = version.substring(0, plus);
  return RegExp(r'^\d+(\.\d+)*$').hasMatch(version) ? version : '';
}

/// [a] 是否比 [b] 新（双方须为 [normalizeVersion] 归一化后的非空版本号）
bool isNewerVersion(String a, String b) {
  final pa = a.split('.').map(int.parse).toList();
  final pb = b.split('.').map(int.parse).toList();
  final length = pa.length > pb.length ? pa.length : pb.length;
  for (var i = 0; i < length; i++) {
    final x = i < pa.length ? pa[i] : 0;
    final y = i < pb.length ? pb[i] : 0;
    if (x != y) return x > y;
  }
  return false;
}
