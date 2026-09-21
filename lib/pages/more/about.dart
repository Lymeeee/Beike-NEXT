import 'package:flutter/material.dart';
import '/utils/app_bar.dart';

/// 关于页（内容待补充）
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PageAppBar(title: '关于'),
      body: const SizedBox.shrink(),
    );
  }
}
