import 'package:flutter/material.dart';

abstract final class AppConfig {
  static const developerName = 'Eik';

  // Set to true to restore the production Supporter purchase flow.
  static const enableSupporterPurchases = false;

  // Set these values before release. Empty links do not appear as actions.
  static const portfolioUrl = '';
  static const sourceCodeUrl = '';

  // Keep this empty until the final public policy URL exists.
  static const privacyPolicyUrl = '';

  static const supporterProductId = 'sometime_supporter';
  static const iconBackground = Color(0xFFFF5C5C);
  static const iconForeground = 'assets/icon/Android_Adaptive_Foreground.svg';
  static const membershipCream = Color(0xFFFFE9CE);
  static const membershipCardRadius = 24.0;
}
