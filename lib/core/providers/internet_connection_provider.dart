import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

final internetConnectionProvider = FutureProvider.autoDispose<bool>((
  ref,
) async {
  final client = http.Client();
  ref.onDispose(client.close);

  try {
    final response = await client
        .get(Uri.https('example.com', '/'))
        .timeout(const Duration(seconds: 3));
    return response.statusCode >= 200 && response.statusCode < 500;
  } on Object {
    return false;
  }
});
