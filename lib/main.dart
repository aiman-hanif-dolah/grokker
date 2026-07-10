import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:marionette_flutter/marionette_flutter.dart';
import 'package:window_manager/window_manager.dart';

import 'app/grokker_app.dart';
import 'core/constants/app_constants.dart';
import 'styles/grokker_components.dart';

Future<void> main() async {
  // Marionette needs its own binding in debug (single WidgetsBinding rule).
  // Skip under `flutter test` so tests keep their own binding.
  final isFlutterTest = Platform.environment.containsKey('FLUTTER_TEST');
  if (kDebugMode && !isFlutterTest) {
    final logCollector = PrintLogCollector();
    MarionetteBinding.ensureInitialized(
      MarionetteConfiguration(
        // Custom Grokker design-system controls.
        isInteractiveWidget: (type) =>
            type == GrokkerPrimaryButton ||
            type == GrokkerOutlinedButton ||
            type == GrokkerGhostButton ||
            type == GrokkerIconFrameButton ||
            type == GrokkerFilterPill ||
            type == GrokkerSearchField,
        extractText: (element) {
          final w = element.widget;
          if (w is GrokkerPrimaryButton) return w.label;
          if (w is GrokkerOutlinedButton) return w.label;
          if (w is GrokkerGhostButton) return w.label;
          if (w is GrokkerFilterPill) return w.label;
          if (w is GrokkerMetaChip) return w.label;
          if (w is GrokkerEyebrow) return w.text;
          if (w is GrokkerBadge) return w.label;
          if (w is GrokkerSearchField) return w.hint;
          return null;
        },
        logCollector: logCollector,
        maxScreenshotSize: const Size(1600, 1000),
      ),
    );
    final defaultDebugPrint = debugPrint;
    debugPrint = (message, {wrapWidth}) {
      if (message != null) logCollector.addLog(message);
      defaultDebugPrint(message, wrapWidth: wrapWidth);
    };
  } else {
    WidgetsFlutterBinding.ensureInitialized();
  }

  await windowManager.ensureInitialized();

  const windowOptions = WindowOptions(
    title: AppConstants.appName,
    minimumSize: Size(
      AppConstants.minWindowWidth,
      AppConstants.minWindowHeight,
    ),
    size: Size(1400, 900),
    center: true,
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(const GrokkerApp());
}
