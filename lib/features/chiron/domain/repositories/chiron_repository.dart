import '../entities/chiron_message.dart';

abstract interface class ChironRepository {
  Stream<String> sendMessage({
    required String userMessage,
    required List<ChironMessage> history,
    required String userContext,
  });
}
