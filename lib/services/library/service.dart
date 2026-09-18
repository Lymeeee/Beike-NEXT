import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '/types/library.dart';

/// 图书馆业务接口异常（携带服务端 message 与 code）
class LibzwApiException implements Exception {
  final int code;
  final String message;

  LibzwApiException(this.code, this.message);

  bool get isNotLoggedIn => code == 300;

  @override
  String toString() => message;
}

/// libzw 图书馆服务：座位 / 研修间 / 我的预约。
///
/// 全部接口经 `/ic-web` 前缀；认证实际依赖 `Cookie: ic-cookie`（token 头保留双保险）。
/// 传参形态（2026-09-17 实测）：GET 走 query string；**POST 走 JSON body**
/// （前端 axios 封装把 `params` 直接作为 post 的 data，数组字段如 resvDev/resvMember 为真数组）。
class LibraryService extends ChangeNotifier {
  static const String origin = 'https://libzw.ustb.edu.cn';

  final Dio _dio;

  LibzwSession? _session;
  bool _isLoading = false;
  String? _error;

  LibraryService({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: '$origin/ic-web',
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 20),
            ));

  bool get isOnline => _session?.isValid ?? false;
  LibzwSession? get session => _session;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void applySession(LibzwSession? session) {
    _session = session;
    if (session?.token != null) {
      _dio.options.headers['token'] = session!.token;
    } else {
      _dio.options.headers.remove('token');
    }
    // 实测：服务端认证实际依赖 ic-cookie（仅 token 头会 300），必须一并携带
    if ((session?.icCookie ?? '').isNotEmpty) {
      _dio.options.headers['Cookie'] = 'ic-cookie=${session!.icCookie}';
    } else {
      _dio.options.headers.remove('Cookie');
    }
    _dio.options.headers['lan'] = '1';
    _safeNotify();
  }

  /// 用本地保存的会话尝试恢复登录：先验 token，失败再用 ic-cookie 换新 token
  Future<bool> restore(LibzwSession? saved) async {
    if (saved == null || !saved.isValid) return false;
    applySession(saved);
    try {
      await getUserInfo();
      return true;
    } on LibzwApiException catch (e) {
      if (!e.isNotLoggedIn) return true; // 其他错误不算掉线
    } catch (_) {
      return true; // 网络问题先按已登录处理，后续请求会再报错
    }
    try {
      await refreshToken();
      return true;
    } catch (_) {
      applySession(null);
      return false;
    }
  }

  /// 仅凭 ic-cookie 换取新 token（用于旧 token 失效后的免重登）
  Future<void> refreshToken() async {
    final ic = _session?.icCookie;
    if (ic == null || ic.isEmpty) throw LibzwApiException(300, '会话已过期');
    // Cookie 头已由 applySession 写入全局请求头
    final resp = await _dio.get('/auth/userInfo');
    final map = _asMap(resp.data);
    _checkCode(map);
    final data = _asMap(map['data']);
    _session = LibzwSession(
      token: data['token'] as String,
      icCookie: ic,
      accNo: '${data['accNo'] ?? ''}',
      trueName: data['trueName'] as String?,
      logonName: data['logonName'] as String?,
    );
    applySession(_session);
  }

  Future<void> getUserInfo() async {
    final map = await _request('GET', '/auth/userInfo');
    final data = _asMap(map);
    final old = _session;
    if (old != null) {
      applySession(LibzwSession(
        token: old.token,
        icCookie: old.icCookie,
        accNo: '${data['accNo'] ?? ''}',
        trueName: data['trueName'] as String?,
        logonName: data['logonName'] as String?,
      ));
    }
  }

  // ---- 座位 / 场馆 ----

  /// 场馆菜单（楼层 → 馆区 树，含空闲数）
  Future<List<LibzwArea>> getSeatMenu() async {
    final data = await _request('GET', '/seatMenu');
    return (data as List)
        .map((e) => LibzwArea.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  /// 指定馆区某天的全部座位（含占用信息）
  Future<List<LibzwDevice>> querySeats(int roomId, String ymd) async {
    final data = await _request('GET', '/reserve', params: {
      'roomIds': '$roomId',
      'resvDates': ymd,
      'sysKind': '8',
    });
    return _parseDevices(data);
  }

  /// 馆区开放时间，如 ('07:00', '22:00')
  Future<(String, String)?> getRoomOpenTimes(int roomId, String dateDash) async {
    final data = await _request('GET', '/room/openTimes', params: {
      'classKind': '8',
      'beginDate': dateDash,
      'endDate': dateDash,
      'roomId': '$roomId',
    });
    if (data is List && data.isNotEmpty) {
      final first = (data.first as Map).cast<String, dynamic>();
      final times = first['openTimes'];
      if (times is List && times.isNotEmpty) {
        final t = (times.first as Map).cast<String, dynamic>();
        final start = _hhmm('${t['openStartTime'] ?? ''}');
        final end = _hhmm('${t['openEndTime'] ?? ''}');
        if (start != null && end != null) return (start, end);
      }
    }
    return null;
  }

  // ---- 研修间 ----

  /// 研修间类型列表（二层研修小间 / 四层南北研修室 …）
  Future<List<LibzwPsgKind>> getPsgKinds() async {
    final data = await _request('GET', '/devKind/labDevKinds', params: {
      'classKind': '1',
      'labIds': '',
    });
    return (data as List)
        .map((e) => LibzwPsgKind.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  /// 某类研修间在指定日期的房间列表
  Future<List<LibzwDevice>> queryPsgRooms(int kindId, String ymd) async {
    final data = await _request('GET', '/reserve', params: {
      'sysKind': '1',
      'resvDates': ymd,
      'kindIds': '$kindId',
      'page': '1',
      'pageNum': '200',
    });
    return _parseDevices(data);
  }

  // ---- 我的预约 ----

  /// 我的预约列表（含座位与研修间）。
  /// 注意：不要传 needStatus——实测 needStatus=0 会被当"按状态0过滤"返回空数组，不传才是全部。
  Future<List<LibzwReservation>> getMyReservations({
    required String beginDateDash,
    required String endDateDash,
    int page = 1,
    int pageNum = 50,
  }) async {
    final data = await _request('GET', '/reserve/resvInfo', params: {
      'beginDate': beginDateDash,
      'endDate': endDateDash,
      'page': '$page',
      'pageNum': '$pageNum',
    });
    return (data as List)
        .map((e) => LibzwReservation.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<int> getResvCount() async {
    final data = await _request('GET', '/reserve/count');
    return data is num ? data.toInt() : int.tryParse('$data') ?? 0;
  }

  // ---- 预约操作 ----

  /// 提交预约。座位：sysKind=8、resvProperty=0；研修间：sysKind=1、resvKind=2、resvProperty=32。
  /// 返回服务端提示语（成功时）。
  Future<String> submitReserve({
    required int sysKind,
    required int devId,
    required String beginTime,
    required String endTime,
    String testName = '',
    String memo = '',
    int resvProperty = 0,
    int resvKind = 0,
    String appUrl = '',
  }) async {
    final session = _session;
    if (session == null || !session.isValid) {
      throw LibzwApiException(300, '请先登录');
    }
    final params = <String, dynamic>{
      'sysKind': sysKind,
      'appAccNo': session.accNo,
      'memberKind': 1,
      'resvMember': [session.accNo],
      'resvBeginTime': beginTime,
      'resvEndTime': endTime,
      'testName': testName,
      // 学校 resvCode=0（无需验证码），照官方前端行为发送空值
      'captcha': '',
      'resvProperty': resvProperty,
      'resvDev': [devId],
      'memo': memo,
      if (resvKind > 0) ...{
        'resvKind': resvKind,
        'appUrl': appUrl,
      },
    };
    final map = await _requestRaw('POST', '/reserve', params: params);
    return '${map['message'] ?? '预约成功'}';
  }

  /// 暂离
  Future<String> tempLeave(int resvId) async {
    final map = await _requestRaw('POST', '/seatOperation/tempLeave',
        params: {'resvId': resvId});
    return '${map['message'] ?? '操作成功'}';
  }

  /// 签离（结束当前预约）
  Future<String> endReserve(int resvId) async {
    final map =
        await _requestRaw('POST', '/reserve/endReserve', params: {'resvId': resvId});
    return '${map['message'] ?? '操作成功'}';
  }

  /// 提前结束
  Future<String> endAhaed(String uuid) async {
    final map = await _requestRaw('POST', '/reserve/endAhaed', params: {'uuid': uuid});
    return '${map['message'] ?? '操作成功'}';
  }

  /// 删除/取消预约
  Future<String> deleteReservation(String uuid) async {
    final map = await _requestRaw('POST', '/reserve/delete', params: {'uuid': uuid});
    return '${map['message'] ?? '操作成功'}';
  }

  // ---- 内部 ----

  List<LibzwDevice> _parseDevices(dynamic data) => (data as List)
      .map((e) => LibzwDevice.fromJson((e as Map).cast<String, dynamic>()))
      .toList();

  static Map<String, dynamic> _asMap(dynamic v) =>
      v is Map ? v.cast<String, dynamic>() : <String, dynamic>{};

  void _checkCode(Map<String, dynamic> map) {
    final code = map['code'];
    if (code != 0) {
      throw LibzwApiException(
        code is num ? code.toInt() : int.tryParse('$code') ?? -1,
        '${map['message'] ?? '请求失败'}',
      );
    }
  }

  Future<dynamic> _request(
    String method,
    String path, {
    Map<String, dynamic>? params,
  }) async {
    final map = await _requestRaw(method, path, params: params);
    return map['data'];
  }

  Future<Map<String, dynamic>> _requestRaw(
    String method,
    String path, {
    Map<String, dynamic>? params,
  }) async {
    _isLoading = true;
    _error = null;
    _safeNotify();
    try {
      // 实测：POST 为 JSON body（前端 axios 封装行为），GET 为 query string
      final resp = method == 'POST'
          ? await _dio.post(path, data: params)
          : await _dio.get(path, queryParameters: params);
      final map = _asMap(resp.data);
      _checkCode(map);
      return map;
    } on LibzwApiException catch (e) {
      if (e.isNotLoggedIn) applySession(null);
      _error = e.message;
      rethrow;
    } on DioException catch (e) {
      _error = '网络请求失败 (${e.type.name})';
      throw LibzwApiException(-1, _error!);
    } finally {
      _isLoading = false;
      _safeNotify();
    }
  }

  static String? _hhmm(String raw) {
    // '0700' / '07:00' → '07:00'
    final s = raw.replaceAll(':', '');
    if (s.length != 4) return null;
    return '${s.substring(0, 2)}:${s.substring(2)}';
  }

  bool _disposed = false;

  /// 页面销毁后请求才返回时，避免 notifyListeners 抛错
  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _dio.close();
    super.dispose();
  }
}
