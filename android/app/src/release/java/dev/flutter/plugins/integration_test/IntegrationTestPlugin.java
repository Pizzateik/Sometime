package dev.flutter.plugins.integration_test;

import androidx.annotation.NonNull;

import io.flutter.embedding.engine.plugins.FlutterPlugin;

/**
 * Keeps the generated Flutter plugin registrant valid for release builds.
 *
 * The Flutter tool lists the integration_test plugin in the generated
 * registrant, but the Gradle plugin loader correctly excludes its native
 * project from release dependencies. This release-only no-op satisfies the
 * generated reference without shipping integration test behavior.
 */
public final class IntegrationTestPlugin implements FlutterPlugin {
  @Override
  public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {}

  @Override
  public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {}
}
