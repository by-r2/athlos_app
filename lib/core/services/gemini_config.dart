/// Gemini API configuration.
///
/// Pass via `--dart-define` at build time:
///   flutter run --dart-define=GEMINI_API_KEY=your_key
const geminiApiKey = String.fromEnvironment('GEMINI_API_KEY');

bool get isGeminiConfigured => geminiApiKey.isNotEmpty;
