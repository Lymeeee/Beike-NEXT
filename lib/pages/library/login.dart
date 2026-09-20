import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:ustb_sso/ustb_sso.dart';

import '/services/library/auth.dart';
import '/types/library.dart';
import '/utils/login_dialog.dart';
import '/utils/ustb_sso.dart';

/// 弹出图书馆登录对话框（微信扫码 / 短信验证码）；成功返回会话数据，取消/失败返回 null
Future<LibzwSession?> showLibzwLoginDialog(
  BuildContext context, {
  String? defaultSmsPhone,
  ValueChanged<String>? onUpdateSmsPhone,
}) {
  return showDialog<LibzwSession>(
    context: context,
    barrierDismissible: false,
    builder: (context) => LibzwLoginDialog(
      defaultSmsPhone: defaultSmsPhone,
      onUpdateSmsPhone: onUpdateSmsPhone,
    ),
  );
}

class LibzwLoginDialog extends StatefulWidget {
  const LibzwLoginDialog({super.key, this.defaultSmsPhone, this.onUpdateSmsPhone});

  /// 预填的短信登录手机号（上次使用时记住的）
  final String? defaultSmsPhone;

  /// 手机号变化时回写（为空串表示清空）
  final ValueChanged<String>? onUpdateSmsPhone;

  @override
  State<LibzwLoginDialog> createState() => _LibzwLoginDialogState();
}

class _LibzwLoginDialogState extends State<LibzwLoginDialog> {
  final LibzwSsoEngine _engine = LibzwSsoEngine();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LoginDialog(
      title: '统一身份认证',
      description: '座位与研修室管理系统',
      icon: Icons.local_library,
      iconColor: theme.colorScheme.primary,
      headerColor: theme.colorScheme.primaryContainer,
      onHeaderColor: theme.colorScheme.onPrimaryContainer,
      child: UstbSsoAuthWidget(
        engine: _engine,
        onSuccess: (response, session) {
          if (mounted) Navigator.of(context).pop(response as LibzwSession);
        },
        defaultSmsPhone: widget.defaultSmsPhone,
        onUpdateSmsPhone: widget.onUpdateSmsPhone,
      ),
    );
  }
}

/// 图书馆（libzw）SSO 引擎：CAS 风格入口，包装 [LibzwAuthProcedure]
class LibzwSsoEngine implements SsoAuthEngine {
  LibzwAuthProcedure? _qr;
  LibzwAuthProcedure? _sms;
  LibzwAuthProcedure? _active;
  Object? _result;

  @override
  Future<void> openQrAuth() async {
    _qr?.cancel();
    final procedure = LibzwAuthProcedure();
    _qr = _active = procedure;
    await procedure.initQrCode();
  }

  @override
  Future<Uint8List> fetchQrImage() async => _qr!.qrImageBytes!;

  @override
  Future<String> waitForPassCode() => _qr!.waitForPassCode();

  @override
  Future<void> completeQrAuth(String passCode) async {
    _result = await _qr!.completeAuth(passCode);
  }

  @override
  Future<void> openSmsAuth() async {
    _sms?.cancel();
    final procedure = LibzwAuthProcedure();
    _sms = _active = procedure;
    await procedure.initSmsAuth();
  }

  @override
  Future<void> sendSmsCode(String phoneNumber) => _sms!.sendSmsMsg(phoneNumber);

  @override
  Future<void> completeSmsAuth(String phoneNumber, String smsCode) async {
    _result = await _sms!.completeSmsAuth(phoneNumber, smsCode);
  }

  @override
  Object? get result => _result;

  @override
  HttpSession get session => _active!.session;

  @override
  String get footerDomain => Uri.parse(LibzwAuthProcedure.origin).host;

  @override
  void cancel() {
    _qr?.cancel();
    _sms?.cancel();
  }
}
