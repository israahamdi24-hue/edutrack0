import 'package:cloud_functions/cloud_functions.dart';

abstract interface class StudentAttendanceQrService {
  Future<String> recordPresence(String qrPayload);
}

class CallableStudentAttendanceQrService implements StudentAttendanceQrService {
  CallableStudentAttendanceQrService({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  @override
  Future<String> recordPresence(String qrPayload) async {
    final trimmedPayload = qrPayload.trim();
    if (trimmedPayload.isEmpty) {
      throw ArgumentError.value(qrPayload, 'qrPayload', 'cannot be empty');
    }

    final result = await _functions
        .httpsCallable('recordStudentAttendance')
        .call<Map<String, dynamic>>({'qrPayload': trimmedPayload});
    if (result.data['success'] != true) {
      final message = result.data['message'];
      throw StudentAttendanceValidationException(
        message is String && message.isNotEmpty
            ? message
            : 'Le serveur n’a pas confirmé la présence.',
      );
    }
    final message = result.data['message'];
    return message is String && message.isNotEmpty
        ? message
        : 'Votre demande de présence a été traitée.';
  }
}

class StudentAttendanceValidationException implements Exception {
  const StudentAttendanceValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}
