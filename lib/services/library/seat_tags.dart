/// 座位特征标注表（人工维护）。
///
/// 学校接口不下发座位特征（deviceAttributes 为空），靠窗/插座等信息
/// 由用户人工指定后填入这里。座位号即座位上显示的编号，如 F1A001。
/// 后续如需支持"前缀/范围"写法，在此处扩展匹配逻辑即可。
class LibrarySeatTags {
  /// 靠窗座位号
  static const Set<String> windowSeats = <String>{};

  /// 有插座座位号
  static const Set<String> powerSeats = <String>{};

  static bool get hasData => windowSeats.isNotEmpty || powerSeats.isNotEmpty;

  static bool isWindow(String devName) => windowSeats.contains(devName);

  static bool isPower(String devName) => powerSeats.contains(devName);

  /// powerMode: 0=不限, 1=必须有插座, 2=必须无插座
  static bool matches(
    String devName, {
    bool requireWindow = false,
    int powerMode = 0,
  }) {
    if (requireWindow && !isWindow(devName)) return false;
    if (powerMode == 1 && !isPower(devName)) return false;
    if (powerMode == 2 && isPower(devName)) return false;
    return true;
  }
}
