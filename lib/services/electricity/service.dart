import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import '/types/electricity.dart';

class ElectricityService {
  static const _apiUrl =
      'http://fspapp.ustb.edu.cn/app.GouDian/index.jsp?m=alipay&c=AliPay&a=getDbYe';
  static const _configFileName = 'electricity_config.json';

  final Dio _dio;

  ElectricityService()
      : _dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          responseType: ResponseType.plain,
        ));

  /// Query the current remaining kWh for an ammeter number.
  /// Returns the kWh value as an integer.
  Future<int> queryAmmeter(int ammeterNumber) async {
    final response = await _dio.post(
      _apiUrl,
      data: 'DBNum=$ammeterNumber',
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
      ),
    );

    final text = response.data as String;
    final json = jsonDecode(text) as Map<String, dynamic>;
    final serviceKey = json['ServiceKey'];
    if (serviceKey != null && serviceKey.toString().isNotEmpty) {
      final remain = int.tryParse(serviceKey.toString());
      if (remain != null) return remain;
    }

    final message = json['message']?.toString();
    if (message != null && message.isNotEmpty) throw Exception(message);
    throw Exception('未查询到电量数据，请确认电表号是否正确');
  }

  // ---- Ammeter number persistence ----

  Future<File> _configFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_configFileName');
  }

  Future<int?> getSavedAmmeterNumber() async {
    try {
      final file = await _configFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>;
        return json['ammeter_number'] as int?;
      }
    } catch (_) {}
    return null;
  }

  Future<void> saveAmmeterNumber(int number) async {
    final file = await _configFile();
    await file.writeAsString(jsonEncode({'ammeter_number': number}));
  }

  // ---- History persistence ----

  Future<File> _historyFile(int ammeterNumber) async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/electricity_$ammeterNumber.json');
  }

  Future<List<RemainingElectricity>> getHistory(int ammeterNumber) async {
    try {
      final file = await _historyFile(ammeterNumber);
      if (await file.exists()) {
        final content = await file.readAsString();
        final list = jsonDecode(content) as List<dynamic>;
        return list
            .map((e) => RemainingElectricity.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  /// Query the API and record the result. Re-querying on the same day updates
  /// today's record instead of appending a duplicate.
  Future<({List<RemainingElectricity> history, String message})> fetchAndRecord(
      int ammeterNumber) async {
    final history = await getHistory(ammeterNumber);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final remain = await queryAmmeter(ammeterNumber);

    final hasToday = history.isNotEmpty && _dayOf(history.last.date) == today;
    final previousIndex = hasToday ? history.length - 2 : history.length - 1;
    final previous = previousIndex >= 0 ? history[previousIndex] : null;

    // Calculate average daily consumption against the last record of a
    // previous day.
    double average = 0.0;
    if (previous != null) {
      final daysDiff = today.difference(_dayOf(previous.date)).inDays;
      if (daysDiff > 0) {
        average = (previous.remain - remain) / daysDiff;
      }
    }

    final entry = RemainingElectricity(
      date: now,
      remain: remain,
      average: average,
    );

    if (hasToday) {
      history[history.length - 1] = entry;
    } else {
      history.add(entry);
    }

    // Persist
    final file = await _historyFile(ammeterNumber);
    await file.writeAsString(jsonEncode(history.map((e) => e.toJson()).toList()));

    return (history: history, message: hasToday ? '今日数据已更新' : '获取成功');
  }

  DateTime _dayOf(DateTime date) => DateTime(date.year, date.month, date.day);
}
