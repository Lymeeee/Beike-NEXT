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

    throw Exception(json['message'] ?? '无法解析电表数据');
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

  /// Query the API and record the result. If today's data already exists, returns
  /// the cached history without making a new API call.
  Future<({List<RemainingElectricity> history, String message})> fetchAndRecord(
      int ammeterNumber) async {
    final history = await getHistory(ammeterNumber);

    // Check if we already have data for today
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (history.isNotEmpty) {
      final lastRecordDate = DateTime(
        history.last.date.year,
        history.last.date.month,
        history.last.date.day,
      );
      if (lastRecordDate == today) {
        return (history: history, message: '今日已经获取过电表数据，明天再来吧');
      }
    }

    // Query the API
    final remain = await queryAmmeter(ammeterNumber);

    // Calculate average daily consumption
    double average = 0.0;
    if (history.isNotEmpty) {
      final last = history.last;
      final daysDiff = now.difference(last.date).inDays;
      if (daysDiff > 0) {
        average = (last.remain - remain) / daysDiff;
      }
    }

    final entry = RemainingElectricity(
      date: now,
      remain: remain,
      average: average,
    );

    history.add(entry);

    // Persist
    final file = await _historyFile(ammeterNumber);
    await file.writeAsString(jsonEncode(history.map((e) => e.toJson()).toList()));

    return (history: history, message: '获取成功');
  }
}
