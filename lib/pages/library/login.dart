import 'dart:typed_data';

import 'package:flutter/material.dart';

import '/services/library/auth.dart';
import '/types/library.dart';
import '/utils/haptic.dart';
import '/utils/login_dialog.dart';

/// 弹出图书馆登录对话框（微信扫码 / 短信验证码）；成功返回会话数据，取消/失败返回 null
Future<LibzwSession?> showLibzwLoginDialog(BuildContext context) {
  return showDialog<LibzwSession>(
    context: context,
    barrierDismissible: true,
    builder: (context) => const LibzwLoginDialog(),
  );
}

class LibzwLoginDialog extends StatefulWidget {
  const LibzwLoginDialog({super.key});

  @override
  State<LibzwLoginDialog> createState() => _LibzwLoginDialogState();
}

class _LibzwLoginDialogState extends State<LibzwLoginDialog> {
  // ---- 二维码 ----
  LibzwAuthProcedure? _qrAuth;
  Uint8List? _qrImageBytes;
  String _qrStatus = '正在获取二维码…';
  String? _qrError;
  bool _qrPreparing = true;

  // ---- 短信 ----
  LibzwAuthProcedure? _smsAuth;
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _smsCodeController = TextEditingController();
  String? _smsError;
  bool _smsSending = false;
  bool _smsCodeSent = false;
  bool _smsSubmitting = false;
  int _smsCountdown = 0;

  @override
  void initState() {
    super.initState();
    _startQr();
    _phoneController.addListener(() => setState(() {}));
    _smsCodeController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _qrAuth?.cancel();
    _smsAuth?.cancel();
    _phoneController.dispose();
    _smsCodeController.dispose();
    super.dispose();
  }

  // ---- 二维码登录 ----

  Future<void> _startQr() async {
    setState(() {
      _qrPreparing = true;
      _qrError = null;
      _qrImageBytes = null;
      _qrStatus = '正在获取二维码…';
    });
    final auth = LibzwAuthProcedure();
    _qrAuth?.cancel();
    _qrAuth = auth;
    try {
      await auth.initQrCode();
      if (!mounted) return;
      setState(() {
        _qrImageBytes = auth.qrImageBytes;
        _qrPreparing = false;
        _qrStatus = '请用微信扫一扫，并在手机上确认登录';
      });
      final passCode = await auth.waitForPassCode();
      if (!mounted) return;
      setState(() => _qrStatus = '正在完成登录…');
      final session = await auth.completeAuth(passCode);
      if (mounted) Navigator.of(context).pop(session);
    } catch (e) {
      if (mounted) {
        setState(() {
          _qrPreparing = false;
          _qrError = '$e';
          _qrStatus = '登录失败';
        });
      }
    }
  }

  // ---- 短信登录 ----

  Future<void> _sendSmsCode() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) return;
    Haptics.medium();
    setState(() {
      _smsSending = true;
      _smsError = null;
    });
    try {
      final auth = LibzwAuthProcedure();
      _smsAuth?.cancel();
      _smsAuth = auth;
      await auth.initSmsAuth();
      await auth.sendSmsMsg(phone);
      if (!mounted) return;
      setState(() {
        _smsSending = false;
        _smsCodeSent = true;
        _smsCountdown = 60;
      });
      _startCountdown();
    } catch (e) {
      if (mounted) {
        setState(() {
          _smsSending = false;
          _smsError = '$e';
        });
      }
    }
  }

  void _startCountdown() {
    if (_smsCountdown <= 0) return;
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() => _smsCountdown--);
        _startCountdown();
      }
    });
  }

  Future<void> _submitSmsCode() async {
    final phone = _phoneController.text.trim();
    final code = _smsCodeController.text.trim();
    if (phone.isEmpty || code.isEmpty) return;
    Haptics.medium();
    setState(() {
      _smsSubmitting = true;
      _smsError = null;
    });
    try {
      final session = await _smsAuth!.completeSmsAuth(phone, code);
      if (mounted) Navigator.of(context).pop(session);
    } catch (e) {
      if (mounted) {
        setState(() {
          _smsSubmitting = false;
          _smsError = '$e';
        });
      }
    }
  }

  // ---- UI ----

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LoginDialog(
      title: '图书馆登录',
      description: '北京科技大学图书馆选座系统',
      icon: Icons.local_library,
      iconColor: theme.colorScheme.primary,
      headerColor: theme.colorScheme.primaryContainer,
      onHeaderColor: theme.colorScheme.onPrimaryContainer,
      child: DefaultTabController(
        length: 2,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const TabBar(
              tabs: [
                Tab(text: '微信扫码登录'),
                Tab(text: '短信验证码登录'),
              ],
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 330,
              child: TabBarView(
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildQrTab(theme),
                  _buildSmsTab(theme),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQrTab(ThemeData theme) {
    if (_qrError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 10),
            Text(_qrError!, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            FilledButton.tonalIcon(
              onPressed: () {
                Haptics.light();
                _startQr();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
      );
    }
    return Column(
      children: [
        const SizedBox(height: 8),
        SizedBox(
          width: 180,
          height: 180,
          child: _qrImageBytes != null
              ? AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: _qrPreparing ? 0.3 : 1.0,
                  child: Image.memory(_qrImageBytes!, fit: BoxFit.contain),
                )
              : Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.qr_code_2,
                    size: 88,
                    color: theme.colorScheme.onSurfaceVariant
                        .withValues(alpha: 0.6),
                  ),
                ),
        ),
        const SizedBox(height: 10),
        if (_qrPreparing && _qrImageBytes == null)
          const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        const SizedBox(height: 8),
        Text(_qrStatus, textAlign: TextAlign.center),
        const SizedBox(height: 6),
        Text(
          '账号与密码不会保存在本地，仅保存登录令牌',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.outline),
        ),
      ],
    );
  }

  Widget _buildSmsTab(ThemeData theme) {
    final phoneNotEmpty = _phoneController.text.trim().isNotEmpty;
    final canSend = !_smsSending && _smsCountdown <= 0 && phoneNotEmpty;
    final canSubmit = _smsCodeSent &&
        !_smsSubmitting &&
        _smsCodeController.text.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        TextField(
          controller: _phoneController,
          enabled: !_smsSending && !_smsSubmitting,
          keyboardType: TextInputType.phone,
          maxLength: 100,
          decoration: const InputDecoration(
            labelText: '手机号码',
            prefixIcon: Icon(Icons.phone),
            counterText: '',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 14),
        if (!_smsCodeSent)
          FilledButton.icon(
            onPressed: canSend
                ? () {
                    Haptics.medium();
                    _sendSmsCode();
                  }
                : null,
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
            icon: _smsSending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send),
            label: Text(_smsSending ? '正在发送…' : '发送验证码'),
          )
        else ...[
          TextField(
            controller: _smsCodeController,
            enabled: !_smsSubmitting,
            keyboardType: TextInputType.number,
            maxLength: 100,
            decoration: InputDecoration(
              labelText: '验证码',
              prefixIcon: const Icon(Icons.numbers),
              counterText: '',
              border: const OutlineInputBorder(),
              isDense: true,
              suffixIcon: _smsCountdown > 0
                  ? Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Center(
                        widthFactor: 1,
                        child: Text(
                          '${_smsCountdown}s',
                          style:
                              TextStyle(color: theme.colorScheme.outline),
                        ),
                      ),
                    )
                  : TextButton(
                      onPressed: canSend
                          ? () {
                              Haptics.light();
                              _sendSmsCode();
                            }
                          : null,
                      child: const Text('重新发送'),
                    ),
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: canSubmit
                ? () {
                    Haptics.medium();
                    _submitSmsCode();
                  }
                : null,
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
            icon: _smsSubmitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.login),
            label: Text(_smsSubmitting ? '正在登录…' : '登录'),
          ),
        ],
        if (_smsError != null) ...[
          const SizedBox(height: 10),
          Text(
            _smsError!,
            textAlign: TextAlign.center,
            style: TextStyle(color: theme.colorScheme.error, fontSize: 13),
          ),
        ],
        const SizedBox(height: 10),
        Text(
          '验证码由学校统一认证系统发送；滑块验证由本地自动识别',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.outline),
        ),
      ],
    );
  }
}
