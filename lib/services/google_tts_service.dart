import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class GoogleTtsService {
  static const String femalevoice = "cmn-CN-Standard-A";
  static const String malevoice = "cmn-CN-Standard-B";

  static Future<http.Response> texttospeech(String text, String voicetype) async {
    await dotenv.load();
    final String? apiKey = dotenv.env['GOOGLE_KEY'];

    final Uri url = Uri.parse(
      "https://texttospeech.googleapis.com/v1beta1/text:synthesize?key=$apiKey",
    );

    final String body = json.encode(<String, Map<String, Object>>{
      "audioConfig": <String, Object>{
        "audioEncoding": "LINEAR16",
        "pitch": 0,
        "speakingRate": 1,
      },
      "input": <String, String>{"text": text},
      "voice": <String, String>{"languageCode": "cmn-CN", "name": voicetype},
    });

    final Future<http.Response> response = http.post(
      url,
      headers: <String, String>{"Content-type": "application/json"},
      body: body,
    );

    return response;
  }
}
