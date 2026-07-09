import 'dart:developer' as developer;

class AppLogger {
  static void info(String message, {String? tag}) {
    developer.log(message, name: tag ?? 'Grokker');
  }

  static void warn(String message, {String? tag}) {
    developer.log(message, name: tag ?? 'Grokker', level: 900);
  }

  static void error(String message, {Object? error, StackTrace? stackTrace}) {
    developer.log(
      message,
      name: 'Grokker',
      level: 1000,
      error: error,
      stackTrace: stackTrace,
    );
  }
}
