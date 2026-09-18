import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
// ignore: implementation_imports
import 'package:ustb_sso/src/captcha.dart' show PuzzleCaptchaSolver;
import 'package:ustb_sso/ustb_sso.dart';

import '/types/library.dart';

/// libzw 图书馆系统 CAS 风格扫码登录。
///
/// ustb_sso 库的 openAuth 走 oauth2（client_id）入口，会被 libzw authcenter 拒绝，
/// 因此入口与出口跳转需自实现；HttpSession/CookieJar 复用 ustb_sso。
/// 链路与坑位详见工作目录的 libzw 交接文档（2026-09 实测）。
class LibzwAuthProcedure {
  static const String origin = 'https://libzw.ustb.edu.cn';

  final HttpSession session = HttpSession();

  Uint8List? qrImageBytes;
  String? _entityId;
  String? _lck;
  String? _appId;
  String? _returnUrl;
  String? _randomToken;
  String? _sid;
  bool _cancelled = false;

  void cancel() => _cancelled = true;

  /// 步骤 ①-③：CAS 风格入口，取得 lck 与 entityId（扫码/短信共用）
  Future<void> _openCasEntry() async {
    // ① auth/address 换取 toLoginPage 地址
    final addr = await session.get(
      '$origin/ic-web/auth/address',
      params: {
        'finalAddress': origin,
        'manager': 'false',
        'consoleType': '16',
      },
    );
    final addrJson = (jsonDecode(addr.body) as Map).cast<String, dynamic>();
    if (addrJson['code'] != 0) {
      throw Exception('获取登录入口失败: ${addrJson['message']}');
    }
    final toLoginUrl = addrJson['data'] as String;

    // ② toLoginPage → 302 → sso authenticate?service=...
    var resp = await session.get(toLoginUrl);
    var next = _nextHopOrThrow(resp, toLoginUrl, '登录跳转失败');

    // ③ sso authenticate → 302 → /ac/#/index?lck=...&entityId=...
    resp = await session.get(next);
    final loc = _nextHopOrThrow(resp, next, '获取认证上下文失败');
    final acUri = Uri.parse(loc.replaceFirst('/#/', '/'));
    _lck = acUri.queryParameters['lck'];
    _entityId = acUri.queryParameters['entityId'] ?? origin;
    if (_lck == null) throw Exception('未能获取认证上下文 lck');
  }

  /// 步骤 ①-⑥：CAS 入口 → 获取 lck → 拉取微信二维码图片
  Future<void> initQrCode() async {
    await _openCasEntry();

    // ④ getMicroQr
    final qr = await session.post(
      'https://sso.ustb.edu.cn/idp/authn/getMicroQr',
      json: {'entityId': _entityId, 'lck': _lck},
    );
    final qrJson = (jsonDecode(qr.body) as Map).cast<String, dynamic>();
    if ('${qrJson['code']}' != '200') {
      throw Exception('获取二维码信息失败: ${qrJson['message']}');
    }
    final qrData = (qrJson['data'] as Map).cast<String, dynamic>();
    _appId = qrData['appId'] as String;
    _returnUrl = qrData['returnUrl'] as String;
    _randomToken = qrData['randomToken'] as String;

    // ⑤ qrpage 提取 sid
    final page = await session.get(
      'https://sis.ustb.edu.cn/connect/qrpage',
      params: {
        'appid': _appId!,
        'return_url': _returnUrl!,
        'rand_token': _randomToken!,
        'embed_flag': '1',
      },
    );
    _sid = RegExp(r'sid\s?=\s?(\w{32})').firstMatch(page.body)?.group(1);
    if (_sid == null) throw Exception('未能获取二维码会话');

    // ⑥ 下载二维码图片
    final img = await session.get(
      'https://sis.ustb.edu.cn/connect/qrimg',
      params: {'sid': _sid!},
    );
    qrImageBytes = img.bodyBytes;
  }

  /// 步骤 ⑦：轮询扫码状态，返回 passCode（扫码确认后）
  Future<String> waitForPassCode({
    Duration timeout = const Duration(seconds: 180),
    void Function()? onScanned,
  }) async {
    if (_sid == null) throw StateError('请先调用 initQrCode()');
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      if (_cancelled) throw Exception('已取消登录');
      final st = await session.get(
        'https://sis.ustb.edu.cn/connect/state',
        params: {'sid': _sid!},
      );
      final stJson = (jsonDecode(st.body) as Map).cast<String, dynamic>();
      final code = stJson['code'];
      if (code == 1) {
        onScanned?.call();
        return stJson['data'] as String;
      }
      if (code == 3 || code == 202) throw Exception('二维码已失效，请重试');
      if (code == 101 || code == 102) throw Exception('二维码状态异常，请重试');
      // code 2/4：已扫未确认 / 超时轮次，继续等待
    }
    throw Exception('扫码超时，请重试');
  }

  /// 步骤 ⑧-⑨：认证出口跳转链 + 换取 IC token，返回可持久化的会话
  Future<LibzwSession> completeAuth(String passCode) async {
    if (_returnUrl == null || _appId == null || _randomToken == null) {
      throw StateError('请先调用 initQrCode()');
    }
    final returnUri = Uri.parse(_returnUrl!);
    var hopUrl = returnUri
        .replace(queryParameters: {
          ...returnUri.queryParameters,
          'appid': _appId!,
          'auth_code': passCode,
          'rand_token': _randomToken!,
        })
        .toString();

    await _followChain(hopUrl);
    return _fetchSession();
  }

  /// 跟随跳转链（302 / JS 跳转 / 桥页），直到到达终点页
  Future<void> _followChain(String startUrl) async {
    var hopUrl = startUrl;
    for (var hop = 0; hop < 15; hop++) {
      if (_cancelled) throw Exception('已取消登录');
      final r = await session.get(hopUrl);
      if (_isRedirect(r)) {
        final loc = r.headers['location'];
        if (loc == null || loc.isEmpty) break;
        hopUrl = _resolve(loc, hopUrl);
        continue;
      }
      final js = _extractJsRedirect(r.body);
      if (js != null) {
        hopUrl = _resolve(js, hopUrl);
        continue;
      }
      break; // 到达终点
    }
  }

  /// 取 ic-cookie 并换取 IC token，组装可持久化会话
  Future<LibzwSession> _fetchSession() async {
    final icCookie = session.cookies.get('ic-cookie');
    if (icCookie == null) throw Exception('登录链未取得 ic-cookie');

    final ui = await session.get('$origin/ic-web/auth/userInfo');
    final uiJson = (jsonDecode(ui.body) as Map).cast<String, dynamic>();
    if (uiJson['code'] != 0) {
      throw Exception('获取用户信息失败: ${uiJson['message']}');
    }
    final data = (uiJson['data'] as Map).cast<String, dynamic>();

    return LibzwSession(
      token: data['token'] as String,
      icCookie: icCookie,
      accNo: '${data['accNo'] ?? ''}',
      trueName: data['trueName'] as String?,
      logonName: data['logonName'] as String?,
    );
  }

  // ---- 短信验证码登录（CAS 上下文；滑块验证码自动求解，不通过自动换题重试）----

  String? _authChainCode;

  /// 短信登录前置：CAS 入口 + 查询登录方式（确认学校开放短信登录）
  Future<void> initSmsAuth() async {
    await _openCasEntry();
    final resp = await session.post(
      'https://sso.ustb.edu.cn/idp/authn/queryAuthMethods',
      json: {'lck': _lck, 'entityId': _entityId},
    );
    final j = (jsonDecode(resp.body) as Map).cast<String, dynamic>();
    final list = j['data'];
    if (list is! List) throw Exception('查询登录方式失败: ${j['message']}');
    for (final item in list) {
      final m = (item as Map).cast<String, dynamic>();
      if (m['moduleCode'] == 'userAndSms') {
        _authChainCode = '${m['authChainCode'] ?? ''}';
      }
    }
    if ((_authChainCode ?? '').isEmpty) {
      throw Exception('学校当前未开放短信验证码登录');
    }
  }

  /// 发送短信验证码（滑块验证码自动求解，失败自动换题重试）
  Future<void> sendSmsMsg(String phone) async {
    if (_lck == null || (_authChainCode ?? '').isEmpty) {
      throw StateError('请先调用 initSmsAuth()');
    }
    String lastError = '验证码发送失败';
    for (var attempt = 0; attempt < 6; attempt++) {
      if (_cancelled) throw Exception('已取消登录');
      String? fatal;
      try {
        final cap = await session
            .get('https://sso.ustb.edu.cn/idp/captcha/getBlockPuzzle');
        final cj = (jsonDecode(cap.body) as Map).cast<String, dynamic>();
        final cd = (cj['data'] as Map).cast<String, dynamic>();

        // 图形验证码自动求解
        final solver = PuzzleCaptchaSolver();
        final result = solver.handleBytes(
          Uint8List.fromList(base64Decode('${cd['originalImageBase64']}')),
          Uint8List.fromList(base64Decode('${cd['jigsawImageBase64']}')),
        );
        final pointJson = jsonEncode({
          'x': (result.x - 5).clamp(0, 99999),
          'y': 5,
        });

        final resp = await session.post(
          'https://sso.ustb.edu.cn/idp/authn/sendSmsMsg',
          json: {
            'loginName': phone,
            'pointJson': pointJson,
            'token': cd['token'],
            'lck': _lck,
          },
        );
        final rj = (jsonDecode(resp.body) as Map).cast<String, dynamic>();
        final inner = rj['data'] is Map ? (rj['data'] as Map)['code'] : null;
        if ('$inner' == '200') return;
        final msg = '${rj['message'] ?? ''}';
        lastError = msg.isEmpty ? '发送失败(${rj['code']})' : msg;
        if (!lastError.contains('图形验证')) fatal = lastError;
      } catch (e) {
        lastError = '图形验证码识别失败，正在重试…(${attempt + 1}/6)';
      }
      if (fatal != null) throw Exception(fatal);
      await Future.delayed(const Duration(seconds: 1));
    }
    throw Exception(lastError);
  }

  /// 提交短信验证码完成登录（authExecute → 桥页 → 与扫码共用的跳转链）
  Future<LibzwSession> completeSmsAuth(String phone, String code) async {
    if (_lck == null || (_authChainCode ?? '').isEmpty) {
      throw StateError('请先调用 initSmsAuth()');
    }
    final resp = await session.post(
      'https://sso.ustb.edu.cn/idp/authn/authExecute',
      json: {
        'authModuleCode': 'userAndSms',
        'authChainCode': _authChainCode,
        'entityId': _entityId,
        'requestType': 'chain_type',
        'lck': _lck,
        'authPara': {
          'loginName': phone,
          'smsCode': code,
          'verifyCode': '',
        },
      },
    );
    final j = (jsonDecode(resp.body) as Map).cast<String, dynamic>();
    if (j['code'] != 200) {
      throw Exception('${j['message'] ?? '验证码错误'}');
    }
    final loginToken = j['loginToken'] as String;

    // 认证引擎桥页 → locationValue → 后续与扫码一致的跳转链
    final engine = await session.post(
      'https://sso.ustb.edu.cn/idp/authCenter/authnEngine?locale=zh-CN',
      body: 'loginToken=$loginToken',
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
    );
    final next = _extractJsRedirect(engine.body);
    if (next == null) throw Exception('登录跳转失败，请重试');
    await _followChain(_resolve(next, 'https://sso.ustb.edu.cn'));
    return _fetchSession();
  }

  // ---- 内部工具：三种跳转形态（302 / window.location / 桥页 locationValue）----

  static bool _isRedirect(http.Response r) =>
      r.statusCode >= 300 && r.statusCode < 400 && r.statusCode != 304;

  static String _resolve(String location, String base) {
    final l = location.trim().replaceAll('&amp;', '&');
    return Uri.parse(base).resolve(l).toString();
  }

  static String? _extractJsRedirect(String body) {
    if (body.length > 60000) return null;
    final patterns = [
      RegExp(r"""window\.location\.href\s*=\s*['"]([^'"]+)['"]"""),
      RegExp(r"""window\.location\.replace\s*\(\s*['"]([^'"]+)['"]\s*\)"""),
      RegExp(r'''var\s+locationValue\s*=\s*"([^"]+)"'''),
      RegExp(r'''http-equiv=["']?refresh["']?[^>]*url=([^"'>;\s]+)''',
          caseSensitive: false),
    ];
    for (final p in patterns) {
      final m = p.firstMatch(body);
      if (m != null) {
        return m.group(1)!
            .replaceAll('&amp;', '&')
            .replaceAll('&quot;', '"');
      }
    }
    return null;
  }

  static String _nextHopOrThrow(http.Response r, String base, String what) {
    if (_isRedirect(r)) {
      final loc = r.headers['location'];
      if (loc != null && loc.isNotEmpty) return _resolve(loc, base);
    }
    final js = _extractJsRedirect(r.body);
    if (js != null) return _resolve(js, base);
    throw Exception('$what (HTTP ${r.statusCode})');
  }
}
