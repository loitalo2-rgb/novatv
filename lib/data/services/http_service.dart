import 'dart:convert';

import 'package:http/http.dart' as http;

class HttpFailure implements Exception {
  HttpFailure(this.message);
  final String message;

  @override
  String toString() => message;
}

class HttpService {
  HttpService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _headers = {
    'User-Agent': 'NovaTV/1.0 (Flutter; +https://example.invalid)',
    'Accept': '*/*',
  };

  Future<String> getText(String url, {Duration timeout = const Duration(seconds: 60)}) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !uri.hasScheme || !(uri.scheme == 'http' || uri.scheme == 'https')) {
      throw HttpFailure('Link inválido: informe um endereço http:// ou https://');
    }

    try {
      final response = await _client.get(uri, headers: _headers).timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpFailure('O servidor respondeu ${response.statusCode}.');
      }
      return utf8.decode(response.bodyBytes, allowMalformed: true);
    } on HttpFailure {
      rethrow;
    } catch (error) {
      throw HttpFailure('Falha ao baixar a lista: $error');
    }
  }

  void close() => _client.close();
}
