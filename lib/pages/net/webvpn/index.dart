import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '/utils/app_bar.dart';
import '/utils/webvpn.dart';

class WebVpnPage extends StatefulWidget {
  const WebVpnPage({super.key});

  @override
  State<WebVpnPage> createState() => _WebVpnPageState();
}

class _WebVpnPageState extends State<WebVpnPage> {
  final _rawController = TextEditingController();
  final _vpnController = TextEditingController();
  String? _rawError;
  String? _vpnError;

  void _onRawSubmit(String value) {
    final text = value.trim();
    if (text.isEmpty) {
      _vpnController.clear();
      setState(() => _rawError = null);
      return;
    }
    try {
      _vpnController.text = translateUp(text);
      setState(() => _rawError = null);
    } catch (_) {
      _vpnController.clear();
      setState(() => _rawError = '网址格式不正确，请检查是否包含 https://');
    }
  }

  void _onVpnSubmit(String value) {
    final text = value.trim();
    if (text.isEmpty) {
      _rawController.clear();
      setState(() => _vpnError = null);
      return;
    }
    try {
      _rawController.text = translateDown(text);
      setState(() => _vpnError = null);
    } catch (_) {
      _rawController.clear();
      setState(() => _vpnError = 'WebVPN网址格式不正确');
    }
  }

  @override
  void dispose() {
    _rawController.dispose();
    _vpnController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: PageAppBar(title: 'WebVPN'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Card.filled(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.link, color: theme.colorScheme.primary, size: 22),
                        const SizedBox(width: 8),
                        Text('原始网址', style: theme.textTheme.titleMedium),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _rawController,
                      decoration: InputDecoration(
                        hintText: "输入后按回车转换（别忘了前面的https://呦）",
                        border: const OutlineInputBorder(),
                        errorText: _rawError,
                      ),
                      onSubmitted: _onRawSubmit,
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () {
                          if (_rawController.text.isNotEmpty) {
                            Clipboard.setData(
                              ClipboardData(text: _rawController.text),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('已复制原始网址')),
                            );
                          }
                        },
                        icon: const Icon(Icons.copy, size: 16),
                        label: const Text('复制'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Icon(Icons.swap_vert,
                  color: theme.colorScheme.primary, size: 32),
            ),
            const SizedBox(height: 16),
            Card.filled(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.vpn_lock,
                            color: theme.colorScheme.primary, size: 22),
                        const SizedBox(width: 8),
                        Text('WebVPN网址', style: theme.textTheme.titleMedium),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _vpnController,
                      decoration: InputDecoration(
                        hintText: '输入WebVPN网址后按回车转换',
                        border: const OutlineInputBorder(),
                        errorText: _vpnError,
                      ),
                      onSubmitted: _onVpnSubmit,
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () {
                          if (_vpnController.text.isNotEmpty) {
                            Clipboard.setData(
                              ClipboardData(text: _vpnController.text),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('已复制WebVPN网址')),
                            );
                          }
                        },
                        icon: const Icon(Icons.copy, size: 16),
                        label: const Text('复制'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card.filled(
              color: theme.colorScheme.surfaceContainerHighest,
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  '本功能可以利用图书馆WebVPN访问仅限校园网访问的网页，'
                  '包括但不限于知网，校园网自服务等，为你不在校时使用资源提供便利。',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
