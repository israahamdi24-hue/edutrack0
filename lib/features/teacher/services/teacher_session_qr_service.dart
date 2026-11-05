import 'package:cloud_functions/cloud_functions.dart';

class TeacherSessionQrService {
  TeacherSessionQrService({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  Future<SessionQrToken> generate(String sessionId) async {
    final result = await _functions
        .httpsCallable('generateSessionQr')
        .call<Map<String, dynamic>>({'sessionId': sessionId});
    final payload = result.data['qrPayload'];
    final expiresAt = result.data['expiresAt'];
    if (payload is! String || expiresAt is! num) {
      throw const FormatException('Réponse QR invalide du serveur.');
    }
    return SessionQrToken(
      payload: payload,
      expiresAt: DateTime.fromMillisecondsSinceEpoch(expiresAt.toInt()),
    );
  }
}

class SessionQrToken {
  const SessionQrToken({required this.payload, required this.expiresAt});

  final String payload;
  final DateTime expiresAt;
}
