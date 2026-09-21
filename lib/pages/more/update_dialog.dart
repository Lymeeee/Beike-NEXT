import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '/services/update/service.dart';
import '/utils/haptic.dart';

/// 发现新版本弹窗：展示版本号与 releases 简介。
/// 简介里的链接会被隐去，北科云盘镜像映射为底部按钮。
Future<void> showUpdateAvailableDialog(
  BuildContext context, {
  required GitHubRelease release,
  required String currentVersion,
}) {
  final theme = Theme.of(context);
  final mirrorUrl = release.mirrorUrl;
  final notes = release.notes;

  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('发现新版本 v${release.version}'),
      titleTextStyle: theme.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.bold,
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '当前构建 v$currentVersion',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: SingleChildScrollView(
                child: Text(
                  notes.isEmpty ? '本次发布没有填写更新简介。' : notes,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Haptics.light();
            Navigator.of(context).pop();
          },
          child: const Text('忽略'),
        ),
        if (mirrorUrl != null)
          FilledButton.tonalIcon(
            onPressed: () => _openLink(context, mirrorUrl),
            icon: const Icon(Icons.cloud_download_outlined, size: 18),
            label: const Text('北科云盘'),
          ),
        FilledButton.tonalIcon(
          onPressed: () => _openLink(context, release.htmlUrl),
          icon: const Icon(Icons.open_in_new, size: 18),
          label: const Text('Github'),
        ),
      ],
    ),
  );
}

Future<void> _openLink(BuildContext context, String url) async {
  Haptics.light();
  var launched = false;
  try {
    final uri = Uri.tryParse(url);
    if (uri != null) {
      launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  } catch (_) {}
  if (!context.mounted) return;
  if (launched) {
    // 浏览器已拉起，关闭弹窗
    Navigator.of(context).pop();
  } else {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('无法打开链接')));
  }
}
