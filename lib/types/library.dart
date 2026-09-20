import '/types/base.dart';

/// 图书馆（libzw.ustb.edu.cn）会话数据，持久化到本地
class LibzwSession extends BaseDataClass {
  /// 在本机 config 存储中的 key
  static const String storeKey = 'library_account_data';

  final String? token;
  final String? icCookie;
  final String? accNo;
  final String? trueName;
  final String? logonName;

  /// 上次短信登录使用的手机号（仅本机记忆，用于登录框预填）
  final String? lastSmsPhone;

  LibzwSession({
    this.token,
    this.icCookie,
    this.accNo,
    this.trueName,
    this.logonName,
    this.lastSmsPhone,
  });

  bool get isValid => (token?.isNotEmpty ?? false) && (accNo?.isNotEmpty ?? false);

  LibzwSession copyWith({String? token, String? icCookie, String? lastSmsPhone}) =>
      LibzwSession(
        token: token ?? this.token,
        icCookie: icCookie ?? this.icCookie,
        accNo: accNo,
        trueName: trueName,
        logonName: logonName,
        lastSmsPhone: lastSmsPhone ?? this.lastSmsPhone,
      );

  factory LibzwSession.fromJson(Map<String, dynamic> json) => LibzwSession(
        token: json['token'] as String?,
        icCookie: json['icCookie'] as String?,
        accNo: json['accNo'] as String?,
        trueName: json['trueName'] as String?,
        logonName: json['logonName'] as String?,
        lastSmsPhone: json['lastSmsPhone'] as String?,
      );

  @override
  Map<String, dynamic> toJson() => {
        'token': token,
        'icCookie': icCookie,
        'accNo': accNo,
        'trueName': trueName,
        'logonName': logonName,
        'lastSmsPhone': lastSmsPhone,
      };

  @override
  Map<String, dynamic> getEssentials() => {'accNo': accNo, 'trueName': trueName};
}

/// seatMenu 返回的楼层/馆区树节点
class LibzwArea {
  final int id;
  final String name;
  final int totalCount;
  final int remainCount;
  final List<LibzwArea> children;

  LibzwArea({
    required this.id,
    required this.name,
    this.totalCount = 0,
    this.remainCount = 0,
    this.children = const [],
  });

  static int _asInt(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

  factory LibzwArea.fromJson(Map<String, dynamic> json) => LibzwArea(
        id: _asInt(json['id']),
        name: '${json['name'] ?? ''}',
        totalCount: _asInt(json['totalCount']),
        remainCount: _asInt(json['remainCount']),
        children: (json['children'] as List?)
                ?.map((e) => LibzwArea.fromJson((e as Map).cast<String, dynamic>()))
                .toList() ??
            const [],
      );
}

class LibzwOpenTime {
  final String openStartTime;
  final String openEndTime;

  LibzwOpenTime({required this.openStartTime, required this.openEndTime});

  factory LibzwOpenTime.fromJson(Map<String, dynamic> json) => LibzwOpenTime(
        openStartTime: '${json['openStartTime'] ?? ''}',
        openEndTime: '${json['openEndTime'] ?? ''}',
      );
}

/// 预约规则（各时间字段单位：分钟）
class LibzwResvRule {
  final int ruleId;
  final int maxResvTime;
  final int minResvTime;
  final int timeInterval;
  final int earliestResvTime;
  final int latestResvTime;
  final int cancelTime;
  final int limit;

  LibzwResvRule({
    required this.ruleId,
    required this.maxResvTime,
    required this.minResvTime,
    required this.timeInterval,
    required this.earliestResvTime,
    required this.latestResvTime,
    required this.cancelTime,
    required this.limit,
  });

  bool get enabled => ruleId > 0;

  factory LibzwResvRule.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
    return LibzwResvRule(
      ruleId: asInt(json['ruleId']),
      maxResvTime: asInt(json['maxResvTime']),
      minResvTime: asInt(json['minResvTime']),
      timeInterval: asInt(json['timeInterval']),
      earliestResvTime: asInt(json['earliestResvTime']),
      latestResvTime: asInt(json['latestResvTime']),
      cancelTime: asInt(json['cancelTime']),
      limit: asInt(json['limit']),
    );
  }
}

/// 座位/房间上的既有预约占用记录
class LibzwResvInfo {
  final String? uuid;
  final int resvId;
  final int startTime;
  final int endTime;
  final int resvStatus;

  LibzwResvInfo({
    this.uuid,
    required this.resvId,
    required this.startTime,
    required this.endTime,
    required this.resvStatus,
  });

  DateTime get start => DateTime.fromMillisecondsSinceEpoch(startTime);
  DateTime get end => DateTime.fromMillisecondsSinceEpoch(endTime);

  factory LibzwResvInfo.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
    return LibzwResvInfo(
      uuid: json['uuid'] as String?,
      resvId: asInt(json['resvId']),
      startTime: asInt(json['startTime']),
      endTime: asInt(json['endTime']),
      resvStatus: asInt(json['resvStatus']),
    );
  }
}

/// 座位/研修间设备（/reserve 查询返回项，两类结构一致）
class LibzwDevice {
  final int devId;
  final String devName;
  final int minUser;
  final int maxUser;
  final int devProp;
  final int devStatus;
  final int openState;
  final String? coordinate;
  final int roomId;
  final String roomName;
  final int kindId;
  final String kindName;
  final int labId;
  final String labName;
  final String openStart;
  final String openEnd;
  final List<LibzwOpenTime> openTimes;
  final LibzwResvRule? resvRule;
  final List<LibzwResvInfo> resvInfo;
  final bool onlyView;

  LibzwDevice({
    required this.devId,
    required this.devName,
    this.minUser = 1,
    this.maxUser = 1,
    this.devProp = 0,
    this.devStatus = 0,
    this.openState = 0,
    this.coordinate,
    required this.roomId,
    required this.roomName,
    this.kindId = 0,
    this.kindName = '',
    this.labId = 0,
    this.labName = '',
    this.openStart = '',
    this.openEnd = '',
    this.openTimes = const [],
    this.resvRule,
    this.resvInfo = const [],
    this.onlyView = false,
  });

  /// devProp 位 2 = 在座位图上展示（可预约位）；位 64 = 隔位标记
  bool get pageShow => (devProp & 2) != 0;

  bool get reservable => pageShow && !onlyView && resvRule != null && resvRule!.enabled;

  /// 指定区间内是否空闲（含边界判定：区间相交即视为占用）
  bool isFreeBetween(DateTime begin, DateTime end) {
    for (final info in resvInfo) {
      if ((info.resvStatus & 128) != 0) continue; // 已结束
      if (info.end.isAfter(begin) && info.start.isBefore(end)) return false;
    }
    return true;
  }

  factory LibzwDevice.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
    final rule = json['resvRule'];
    return LibzwDevice(
      devId: asInt(json['devId']),
      devName: '${json['devName'] ?? ''}',
      minUser: asInt(json['minUser']),
      maxUser: asInt(json['maxUser']),
      devProp: asInt(json['devProp']),
      devStatus: asInt(json['devStatus']),
      openState: asInt(json['openState']),
      coordinate: json['coordinate'] as String?,
      roomId: asInt(json['roomId']),
      roomName: '${json['roomName'] ?? ''}',
      kindId: asInt(json['kindId']),
      kindName: '${json['kindName'] ?? ''}',
      labId: asInt(json['labId']),
      labName: '${json['labName'] ?? ''}',
      openStart: '${json['openStart'] ?? ''}',
      openEnd: '${json['openEnd'] ?? ''}',
      openTimes: (json['openTimes'] as List?)
              ?.map((e) => LibzwOpenTime.fromJson((e as Map).cast<String, dynamic>()))
              .toList() ??
          const [],
      resvRule: rule is Map ? LibzwResvRule.fromJson(rule.cast<String, dynamic>()) : null,
      resvInfo: (json['resvInfo'] as List?)
              ?.map((e) => LibzwResvInfo.fromJson((e as Map).cast<String, dynamic>()))
              .toList() ??
          const [],
      onlyView: json['onlyView'] == true,
    );
  }
}

/// 我的预约记录中的设备信息
class LibzwResvDeviceInfo {
  final int devId;
  final String devName;
  final String roomName;
  final String labName;
  final int classKind;

  LibzwResvDeviceInfo({
    required this.devId,
    required this.devName,
    this.roomName = '',
    this.labName = '',
    this.classKind = 0,
  });

  factory LibzwResvDeviceInfo.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
    return LibzwResvDeviceInfo(
      devId: asInt(json['devId']),
      devName: '${json['devName'] ?? ''}',
      roomName: '${json['roomName'] ?? ''}',
      labName: '${json['labName'] ?? ''}',
      classKind: asInt(json['classKind']),
    );
  }
}

/// 预约状态位（与网页端一致）
abstract class LibzwResvStatus {
  static const int pending = 2; // 待生效
  static const int active = 4; // 已生效
  static const int breached = 16; // 已违约
  static const int ended = 128; // 已结束
  static const int auditing = 256; // 待审核
  static const int auditFailed = 512; // 审核未通过
  static const int auditPassed = 1024; // 审核通过
  static const int tempLeave = 2048; // 已暂离
  static const int waitAgree = 8192; // 待同意
  static const int report = 16384; // 举报

  static String describe(int status) {
    final parts = <String>[];
    if ((status & report) != 0) parts.add('举报');
    if ((status & waitAgree) != 0) parts.add('待同意');
    if ((status & tempLeave) != 0) parts.add('已暂离');
    if ((status & breached) != 0) parts.add('已违约');
    if ((status & ended) != 0) parts.add('已结束');
    if ((status & auditFailed) != 0) parts.add('审核未通过');
    if ((status & auditing) != 0) parts.add('待审核');
    if (parts.isEmpty && (status & auditPassed) != 0) parts.add('审核通过');
    if (parts.isEmpty && (status & active) != 0) parts.add('已生效');
    if (parts.isEmpty && (status & pending) != 0) parts.add('待生效');
    return parts.isEmpty ? '未知状态' : parts.join('·');
  }
}

/// 我的预约记录（字段取自真实响应；时间字段为毫秒数字或字符串，均兼容）
class LibzwReservation {
  final String? uuid;
  final int resvId;
  final int resvStatus;
  final int classKind;
  final String? appAccNo;
  final DateTime? begin;
  final DateTime? end;
  final String? testName;
  final String? memo;
  final bool endEarly;
  final String? tempLeaveEndTime;
  final String? checkInfo;
  final List<LibzwResvDeviceInfo> devices;

  LibzwReservation({
    this.uuid,
    required this.resvId,
    required this.resvStatus,
    this.classKind = 0,
    this.appAccNo,
    this.begin,
    this.end,
    this.testName,
    this.memo,
    this.endEarly = false,
    this.tempLeaveEndTime,
    this.checkInfo,
    this.devices = const [],
  });

  bool get isEnded => (resvStatus & LibzwResvStatus.ended) != 0;
  bool get canCancel =>
      (resvStatus & LibzwResvStatus.active) == 0 &&
      (resvStatus & LibzwResvStatus.ended) == 0;
  bool get canTempLeave =>
      (resvStatus & 64) != 0 &&
      (resvStatus & LibzwResvStatus.ended) == 0 &&
      (resvStatus & LibzwResvStatus.tempLeave) == 0;
  bool get canEndEarly => endEarly;

  /// 类型标签：1=研修间 8=座位 16=活动 32=考研座位
  String get kindLabel => switch (classKind) {
        1 => '研修间',
        8 => '座位',
        16 => '活动',
        32 => '考研座位',
        _ => '',
      };

  String get place {
    if (devices.isEmpty) return '';
    final d = devices.first;
    return [
      d.labName,
      if (d.roomName.isNotEmpty && d.roomName != d.devName) d.roomName,
      d.devName,
    ].where((s) => s.isNotEmpty).join(' ');
  }

  static DateTime? _parseTime(dynamic v) {
    if (v == null) return null;
    if (v is num) {
      final ms = v.toInt();
      return DateTime.fromMillisecondsSinceEpoch(ms > 100000000000 ? ms : ms * 1000);
    }
    return DateTime.tryParse('$v');
  }

  factory LibzwReservation.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
    final rawEndEarly = json['endEarly'];
    return LibzwReservation(
      uuid: json['uuid'] as String?,
      resvId: asInt(json['resvId']),
      resvStatus: asInt(json['resvStatus']),
      classKind: asInt(json['classKind']),
      appAccNo: json['appAccNo']?.toString(),
      begin: _parseTime(json['resvBeginTime']),
      end: _parseTime(json['resvEndTime']),
      testName: json['testName'] as String?,
      memo: json['memo'] as String?,
      endEarly: rawEndEarly == true || rawEndEarly == 1 || rawEndEarly == '1',
      tempLeaveEndTime: json['tempLeaveEndTime']?.toString(),
      checkInfo: json['checkInfo'] as String?,
      devices: (json['resvDevInfoList'] as List?)
              ?.map((e) => LibzwResvDeviceInfo.fromJson((e as Map).cast<String, dynamic>()))
              .toList() ??
          const [],
    );
  }
}

/// 研修间类型（二层研修小间 / 四层南北研修室 等）
class LibzwPsgKind {
  final int kindId;
  final String kindName;

  LibzwPsgKind({required this.kindId, required this.kindName});

  factory LibzwPsgKind.fromJson(Map<String, dynamic> json) {
    final id = json['kindId'];
    return LibzwPsgKind(
      kindId: id is num ? id.toInt() : int.tryParse('$id') ?? 0,
      kindName: '${json['kindName'] ?? ''}',
    );
  }
}
