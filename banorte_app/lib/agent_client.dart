import 'dart:convert';

import 'package:http/http.dart' as http;

/// Transporte hacia el agente: un turno = POST /turn → mensajes A2UI.
class AgentClient {
  AgentClient({this.baseUrl = const String.fromEnvironment('BACKEND_URL', defaultValue: 'http://localhost:8000')});

  final String baseUrl;
  final String conversationId = DateTime.now().microsecondsSinceEpoch.toString();

  Future<List<Map<String, dynamic>>> sendTurn({String? texto, Map<String, dynamic>? action}) async {
    final res = await http.post(
      Uri.parse('$baseUrl/turn'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'conversation_id': conversationId, 'texto': texto, 'action': action}),
    );
    final body = utf8.decode(res.bodyBytes);
    if (res.statusCode != 200) throw Exception('El agente respondió ${res.statusCode}: $body');
    return (jsonDecode(body)['messages'] as List).cast<Map<String, dynamic>>();
  }
}
