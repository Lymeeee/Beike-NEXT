import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:pointycastle/export.dart';

import '/types/empty_classroom.dart';

/// Service for querying empty (free) classrooms at USTB.
///
/// The API is protected by a CSRF token mechanism. The flow is:
/// 1. Fetch /config.json → get encrypted domainConfig
/// 2. AES-256-CBC decrypt domainConfig → get csrkKey
/// 3. Generate CSRF token from csrkKey + current timestamp
/// 4. Call APIs with csrkToken query parameter
class EmptyClassroomService extends ChangeNotifier {
  final Dio _dio;

  // AES key and IV — parsed as UTF-8 strings by CryptoJS
  static const _aesKey = '80bdbdbaf7494add99198960d715d41b';
  static const _aesIv = 'bdbaf7494add9919';

  String? _csrkKey;
  String? _currentToken;
  bool _initialized = false;

  List<Building> _buildings = [];
  List<SectionType> _sectionTypes = [];
  List<Node> _nodes = [];
  List<FreeClassroomNode> _freeRoomsByNode = [];
  List<FreeClassroomTimeRange> _freeRoomsByTime = [];

  // Current selections
  String? _selectedBuildingId;
  String? _selectedSectionId;
  String? _selectedNodeId; // -1 = all, empty = none
  int _timeFilterId = 4; // 0=全天,1=上午,2=下午,3=晚上,4=按节次
  String _selectedDate = '';

  bool _isLoading = false;
  String? _error;

  EmptyClassroomService({Dio? dio})
    : _dio =
          dio ??
          Dio(BaseOptions(
            baseUrl: 'https://ustb.smartclass.cn',
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 10),
          ));

  // --- Getters ---

  bool get isInitialized => _initialized;
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Building> get buildings => _buildings;
  List<SectionType> get sectionTypes => _sectionTypes;
  List<Node> get nodes => _nodes;
  List<FreeClassroomNode> get freeRoomsByNode => _freeRoomsByNode;
  List<FreeClassroomTimeRange> get freeRoomsByTime => _freeRoomsByTime;

  String? get selectedBuildingId => _selectedBuildingId;
  String? get selectedSectionId => _selectedSectionId;
  String? get selectedNodeId => _selectedNodeId;
  int get timeFilterId => _timeFilterId;
  String get selectedDate => _selectedDate;

  bool get isSearchByNode => _timeFilterId == 4;

  // --- Initialization ---

  /// Fetch config, decrypt, and load buildings + section types.
  Future<void> init() async {
    if (_initialized) return;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _fetchAndDecryptConfig();
      _selectedDate = _formatDate(DateTime.now());
      await Future.wait([_fetchBuildings(), _fetchSectionTypes()]);
      _initialized = true;
      await refresh();
    } catch (e) {
      _error = e.toString();
      if (kDebugMode) print('EmptyClassroomService init error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- Crypto ---

  /// AES-256-CBC decryption matching CryptoJS behavior:
  /// key and iv are parsed as UTF-8 strings, ciphertext is hex-encoded.
  String _aesDecrypt(String hexCiphertext) {
    final keyBytes = utf8.encode(_aesKey);
    final ivBytes = utf8.encode(_aesIv);
    final ciphertext = Uint8List.fromList(
      List.generate(
        hexCiphertext.length ~/ 2,
        (i) => int.parse(hexCiphertext.substring(i * 2, i * 2 + 2), radix: 16),
      ),
    );

    final cbc = CBCBlockCipher(AESEngine())
      ..init(false, ParametersWithIV(KeyParameter(keyBytes), ivBytes));

    final padded = Uint8List(ciphertext.length);
    for (var i = 0; i < ciphertext.length; i += 16) {
      cbc.processBlock(ciphertext, i, padded, i);
    }

    // PKCS7 unpad
    final padLen = padded.last;
    return utf8.decode(padded.sublist(0, padded.length - padLen));
  }

  /// Generate CSRF token from csrkKey + timestamp (matching the JS algorithm).
  String _generateCsrfToken(String csrkKey, [int? timestampMs]) {
    final t = timestampMs ?? DateTime.now().millisecondsSinceEpoch;
    var remaining = t;
    var j = 1000000000000;
    final buf = StringBuffer();
    while (j != 0) {
      final k = remaining ~/ j;
      buf.write(csrkKey[k]);
      remaining -= k * j;
      j = j ~/ 10;
    }
    return buf.toString();
  }

  /// Get a valid CSRF token, regenerating if older than 30 minutes.
  String _getCsrfToken() {
    _currentToken = _generateCsrfToken(_csrkKey!, DateTime.now().millisecondsSinceEpoch);
    return _currentToken!;
  }

  Map<String, String> _buildParams([Map<String, String>? extraParams]) {
    return <String, String>{
      'csrkToken': _getCsrfToken(),
      if (extraParams != null) ...extraParams,
    };
  }

  // --- Config ---

  Future<void> _fetchAndDecryptConfig() async {
    final response = await _dio.get('/config.json',
        options: Options(responseType: ResponseType.json));
    final domainConfig = response.data['domainConfig'] as String;
    final decrypted = jsonDecode(_aesDecrypt(domainConfig)) as Map<String, dynamic>;
    _csrkKey = decrypted['csrkKey'] as String;

    // generalEduIp may be empty (same-origin) — we already use the page domain
    if (kDebugMode) {
      print('EmptyClassroom: csrkKey=$_csrkKey');
      print('EmptyClassroom: generalEduIp=${decrypted['generalEduIp']}');
    }
  }

  // --- API: Buildings ---

  Future<void> _fetchBuildings() async {
    final params = _buildParams();
    final response = await _dio.get('/general/api/open/building/listBuildings',
        queryParameters: params);
    if (response.data['code'] == 0) {
      _buildings = (response.data['data'] as List)
          .map((j) => Building.fromJson(j as Map<String, dynamic>))
          .toList();
      if (_buildings.isNotEmpty && _selectedBuildingId == null) {
        _selectedBuildingId = _buildings.first.id;
      }
    }
  }

  // --- API: Section Types ---

  Future<void> _fetchSectionTypes() async {
    final params = _buildParams();
    final response = await _dio.get('/general/api/open/teachingCycle/listNodeTypes',
        queryParameters: params);
    if (response.data['code'] == 0) {
      _sectionTypes = (response.data['data'] as List)
          .map((j) => SectionType.fromJson(j as Map<String, dynamic>))
          .toList();

      // USTB hardcodes to "默认节次" in the web page, matching that behavior.
      const ustbDefaultSectionId = '49c166931e8a70ff2a57a5780dcbb892';
      final defaultSection = _sectionTypes.cast<SectionType?>().firstWhere(
            (s) => s!.id == ustbDefaultSectionId,
            orElse: () => _sectionTypes.isNotEmpty ? _sectionTypes.first : null,
          );
      if (defaultSection != null && _selectedSectionId == null) {
        _selectedSectionId = defaultSection.id;
        await _fetchNodes();
      }
    }
  }

  // --- API: Nodes (periods) ---

  Future<void> _fetchNodes() async {
    if (_selectedSectionId == null) return;
    final params = _buildParams({'nodeTypeId': _selectedSectionId!});
    final response = await _dio.get('/general/api/open/teachingCycle/listNodes',
        queryParameters: params);
    if (response.data['code'] == 0) {
      _nodes = (response.data['data'] as List)
          .map((j) => Node.fromJson(j as Map<String, dynamic>))
          .toList();
      if (_selectedNodeId == null) {
        _selectedNodeId = '-1'; // All nodes
      }
    }
  }

  // --- API: Free Classrooms (by node) ---

  Future<void> _fetchFreeClassRooms() async {
    final body = {
      'buildingId': _selectedBuildingId ?? '',
      'cycleTypeId': _selectedSectionId ?? '',
      'nodeId': (_selectedNodeId == '-1' || _selectedNodeId == null)
          ? ''
          : _selectedNodeId,
    };
    final params = _buildParams();
    if (kDebugMode) print('FreeClassRooms request: $body');
    final response = await _dio.post(
      '/general/api/classroom/freeClassRooms',
      queryParameters: params,
      data: jsonEncode(body),
      options: Options(
        headers: {'Content-Type': 'application/json;charset=utf-8'},
        responseType: ResponseType.json,
      ),
    );
    if (kDebugMode) {
      print('FreeClassRooms response code: ${response.data['code']}');
      print('FreeClassRooms data length: ${(response.data['data'] as List?)?.length ?? 0}');
    }
    if (response.data['code'] == 0) {
      final data = response.data['data'] as List;
      _freeRoomsByNode = data
          .map((j) => FreeClassroomNode.fromJson(j as Map<String, dynamic>))
          .toList();
      if (kDebugMode) print('FreeClassRooms parsed: ${_freeRoomsByNode.length} nodes');
    } else {
      if (kDebugMode) print('FreeClassRooms API error: ${response.data['msg']}');
      _freeRoomsByNode = [];
    }
  }

  // --- API: Free Classrooms (by time range) ---

  Future<void> _fetchFreeJoinClassRooms() async {
    String startTime;
    String endTime;
    switch (_timeFilterId) {
      case 0: // 全天
        startTime = '$_selectedDate 00:00:00';
        endTime = '$_selectedDate 23:59:59';
        break;
      case 1: // 上午
        startTime = '$_selectedDate 00:00:00';
        endTime = '$_selectedDate 12:00:00';
        break;
      case 2: // 下午
        startTime = '$_selectedDate 12:00:01';
        endTime = '$_selectedDate 19:00:00';
        break;
      case 3: // 晚上
        startTime = '$_selectedDate 19:00:01';
        endTime = '$_selectedDate 23:59:59';
        break;
      default:
        startTime = '$_selectedDate 00:00:00';
        endTime = '$_selectedDate 23:59:59';
    }

    final body = {
      'buildingId': _selectedBuildingId ?? '',
      'startTime': startTime,
      'endTime': endTime,
    };
    final params = _buildParams();
    final response = await _dio.post(
      '/general/api/classroom/freeJoinClassRooms',
      queryParameters: params,
      data: jsonEncode(body),
      options: Options(
        headers: {'Content-Type': 'application/json;charset=utf-8'},
      ),
    );
    if (response.data['code'] == 0) {
      _freeRoomsByTime = (response.data['data'] as List)
          .map((j) =>
              FreeClassroomTimeRange.fromJson(j as Map<String, dynamic>))
          .toList();
    } else {
      _freeRoomsByTime = [];
    }
  }

  // --- Public actions ---

  Future<void> refresh() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      if (isSearchByNode) {
        await _fetchFreeClassRooms();
      } else {
        await _fetchFreeJoinClassRooms();
      }
    } catch (e, stack) {
      _error = e.toString();
      if (kDebugMode) {
        print('EmptyClassroom refresh error: $e');
        print('Stack: $stack');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> selectBuilding(String id) async {
    _selectedBuildingId = id;
    notifyListeners();
    await refresh();
  }

  Future<void> selectSection(String id) async {
    _selectedSectionId = id;
    _selectedNodeId = '-1';
    notifyListeners();
    await _fetchNodes();
    await refresh();
  }

  Future<void> selectNode(String id) async {
    _selectedNodeId = id;
    notifyListeners();
    await refresh();
  }

  Future<void> selectTimeFilter(int id) async {
    _timeFilterId = id;
    if (id == 4) {
      // Switch to node-based search
      _selectedNodeId = '-1';
    }
    notifyListeners();
    await refresh();
  }

  Future<void> selectDate(DateTime date) async {
    _selectedDate = _formatDate(date);
    notifyListeners();
    await refresh();
  }

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  void dispose() {
    _dio.close();
    super.dispose();
  }
}
