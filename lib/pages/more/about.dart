import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '/utils/app_bar.dart';
import '/utils/haptic.dart';
import '/utils/meta_info.dart';

/// 关于页
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  static const _appName = '大贝壳NEXT';
  static const _repoUrl = 'https://github.com/Lymeeee/Beike-NEXT';
  static const _upstreamUrl = 'https://github.com/isHarryh/The-Beike';

  static const _noBorderShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(12)),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PageAppBar(title: '关于'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        children: [
          _buildHeader(context),
          const SizedBox(height: 16),
          _buildTextCard(context, '关于这个 App', [
            '本 APP 为 GitHub 上 isHarryh 的大贝壳的 Fork，以此为底座进行了'
                '强迫症级别的 MD3 界面重构，以及加了一些自己常用的功能。',
            '哪里用得不舒心或者有什么新功能建议请使劲提意见喵谢谢喵。',
          ]),
          const SizedBox(height: 16),
          _buildActionCard(
            context,
            icon: Icons.code,
            title: '项目仓库',
            subtitle: 'github.com/Lymeeee/Beike-NEXT',
            onTap: () => _openLink(context, _repoUrl),
          ),
          const SizedBox(height: 16),
          _buildActionCard(
            context,
            icon: Icons.bug_report_outlined,
            title: '反馈问题',
            subtitle: '在仓库里提 Issue',
            onTap: () => _openLink(context, '$_repoUrl/issues'),
          ),
          const SizedBox(height: 16),
          _buildActionCard(
            context,
            icon: Icons.auto_awesome_outlined,
            title: '原作者项目',
            subtitle: 'isHarryh 的「大贝壳」',
            onTap: () => _openLink(context, _upstreamUrl),
          ),
          const SizedBox(height: 16),
          _buildTextCard(context, '隐私', [
            '本 APP 仅仅为第三方前端实现，一切联网更改都会直通到学校后端服务器，'
                '中间不存在任何中间人截获，包括开发者自己。',
          ]),
          const SizedBox(height: 16),
          _buildTextCard(context, '免责', [
            '本 APP 为学生个人业余时间开发，与北京科技大学官方无任何关系，'
                'APP 内并无任何例如抢课等破坏公平性的功能。',
            '受学校服务端安全政策限制，账号在登录一段时间后自动被注销系正常现象。',
          ]),
          const SizedBox(height: 16),
          _buildLicenseCard(context),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'Copyright © 2026 Lymeeee · GPLv3',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);

    return Card.filled(
      shape: _noBorderShape,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // app_icon.png 自带黑色底板，这里用启动图标的前景层：透明底校门，
            // 并跟随主题色（深色模式下才不会糊在卡片上）
            Image.asset(
              'assets/icons/app_glyph.png',
              width: 64,
              height: 64,
              color: theme.colorScheme.primary,
              colorBlendMode: BlendMode.srcIn,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _appName,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '北京科技大学校园助手',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextCard(
    BuildContext context,
    String title,
    List<String> paragraphs,
  ) {
    final theme = Theme.of(context);

    return Card.filled(
      shape: _noBorderShape,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < paragraphs.length; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              Text(
                paragraphs[i],
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return Card.filled(
      shape: _noBorderShape,
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, size: 22, color: theme.colorScheme.primary),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLicenseCard(BuildContext context) {
    final theme = Theme.of(context);

    return Card.filled(
      shape: _noBorderShape,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '开源许可',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '本项目开源协议为 GPLv3，欢迎自由使用与修改！',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: () {
                Haptics.light();
                showLicensePage(
                  context: context,
                  applicationName: _appName,
                  applicationVersion: MetaInfo.instance.appVersion,
                  applicationIcon: Image.asset(
                    'assets/icons/app_glyph.png',
                    width: 40,
                    height: 40,
                    color: theme.colorScheme.primary,
                    colorBlendMode: BlendMode.srcIn,
                  ),
                );
              },
              icon: const Icon(Icons.description_outlined, size: 18),
              label: const Text('查看第三方开源许可'),
            ),
          ],
        ),
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
    if (launched || !context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('无法打开链接')));
  }
}
