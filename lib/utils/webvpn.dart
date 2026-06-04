import 'dart:typed_data';
import 'package:pointycastle/api.dart';
import 'package:pointycastle/block/aes.dart';

const _key = 'wrdvpnisthebest!';
const _iv = 'wrdvpnisthebest!';
const _vpnHost = 'https://elib.ustb.edu.cn';

Uint8List _aesCfb128(bool encrypt, Uint8List key, Uint8List iv, Uint8List data) {
  final engine = AESEngine();
  engine.init(encrypt, KeyParameter(key));

  const blockSize = 16;
  final feedback = Uint8List.fromList(iv);
  final output = Uint8List(data.length);

  for (int i = 0; i < data.length; i++) {
    if (i % blockSize == 0) {
      // Generate keystream block
      engine.processBlock(feedback, 0, feedback, 0);
    }
    final keystreamByte = feedback[i % blockSize];
    output[i] = data[i] ^ keystreamByte;
    // Update feedback: for encryption, use ciphertext; for decryption, use ciphertext (input)
    feedback[i % blockSize] = encrypt ? output[i] : data[i];
  }

  return output;
}

String _padText(String text) {
  const seg = 16;
  if (text.length % seg == 0) return text;
  return text.padRight(text.length + seg - text.length % seg, '0');
}

String _encryptHost(String host) {
  final textLen = host.length;
  final padded = _padText(host);

  final keyBytes = Uint8List.fromList(_key.codeUnits);
  final ivBytes = Uint8List.fromList(_iv.codeUnits);

  final encrypted = _aesCfb128(true, keyBytes, ivBytes,
      Uint8List.fromList(padded.codeUnits));

  final ivHex = ivBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  final cipherHex = encrypted
      .take(textLen)
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join();

  return '$ivHex$cipherHex';
}

String _decryptHost(String data) {
  final ivHex = data.substring(0, 32);
  final cipherHex = data.substring(32);

  final ivBytes = Uint8List(16);
  for (int i = 0; i < 16; i++) {
    ivBytes[i] = int.parse(ivHex.substring(i * 2, i * 2 + 2), radix: 16);
  }

  final cipherLen = cipherHex.length ~/ 2;
  final cipherBytes = Uint8List(cipherLen);
  for (int i = 0; i < cipherLen; i++) {
    cipherBytes[i] = int.parse(cipherHex.substring(i * 2, i * 2 + 2), radix: 16);
  }

  final keyBytes = Uint8List.fromList(_key.codeUnits);

  final decrypted = _aesCfb128(false, keyBytes, ivBytes, cipherBytes);

  return String.fromCharCodes(decrypted);
}

String translateUp(String rawUrl) {
  if (!rawUrl.startsWith('https://') && !rawUrl.startsWith('http://')) {
    throw ArgumentError('网址必须以 https:// 或 http:// 开头');
  }
  final uri = Uri.parse(rawUrl);
  if (uri.host.isEmpty) {
    throw ArgumentError('网址格式不正确，缺少域名');
  }

  var protocol = uri.scheme;
  final host = uri.host;
  if (uri.hasPort) {
    protocol = '$protocol-${uri.port}';
  }

  final encrypted = _encryptHost(host);

  var result = '$_vpnHost/$protocol/$encrypted${uri.path}';
  if (uri.hasQuery) {
    result += '?${uri.query}';
  }
  return result;
}

String translateDown(String vpnUrl) {
  if (!vpnUrl.contains('elib.ustb.edu.cn')) {
    throw ArgumentError('WebVPN网址必须包含 elib.ustb.edu.cn');
  }
  final uri = Uri.parse(vpnUrl);
  final segments = uri.pathSegments;

  if (segments.length < 2) {
    throw ArgumentError('WebVPN网址格式不正确');
  }

  var protocol = segments[0];
  final encHost = segments[1];

  var host = _decryptHost(encHost);
  if (protocol.contains('-')) {
    final parts = protocol.split('-');
    host = '$host:${parts[1]}';
    protocol = parts[0];
  }

  final path = segments.length > 2
      ? '/${segments.sublist(2).join('/')}'
      : '/';

  return '$protocol://$host$path';
}
