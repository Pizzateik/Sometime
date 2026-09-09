import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

abstract final class AppHaptics {
  static bool enabled = true;

  static bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  static void selection() {
    if (enabled && _supported) unawaited(HapticFeedback.selectionClick());
  }

  static void medium() {
    if (enabled && _supported) unawaited(HapticFeedback.mediumImpact());
  }

  static void strong() {
    if (enabled && _supported) unawaited(HapticFeedback.heavyImpact());
  }
}
