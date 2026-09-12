# PLAY STORE READINESS

Audit date: September 9, 2026.
The code checks pass. The current artifacts are local test builds, not signed Play Store uploads.

## READY

- `flutter analyze`: no issues.
- `flutter test`: 119 tests passed (including release regression suite).
- `flutter build apk --release`: passed, 21.5 MB (arm64-v8a).
- `flutter build appbundle --release`: passed, 55.4 MB (Play Store App Bundle).
- The installed release APK passed an emulator cold start after force-stop. Saved tasks remained visible. The crash buffer was empty.
- Android configuration: `eu.eikrose.sometime`, version 1.0.0 (1), minimum SDK 24, target SDK 35, compile SDK 35.
- The adaptive launcher icon includes foreground and monochrome layers. Its background is `#FF5C5C`.
- The bundle uses membership WebP gradients. It contains no old gradient PNG files.
- App text uses Geist. The membership display name uses Parisienne. App icon mappings use Phosphor.
- Light and dark creation previews show clear selected segments, weekday buttons, and monthly buttons.

## FIXED

- Midnight checks now run without a future routine. Completed tasks can leave the current day correctly.
- Selected segment thumbs have a full height, clear contrast, and a short 1.05 contact scale.
- Drag selection responds at drag start and sends feedback only for a value change.
- Settings save errors show a retry action. Async callbacks check lifecycle state.
- Notification changes follow settings and locale changes. Native notification labels use the app language.
- Widget snapshots use local calendar dates and tolerate malformed native data.
- Android widgets use shared colors, Geist, dashed rectangular completion controls, and subtle dashed dividers.
- The medium widget uses a bottom-right square plus button. Row limits reserve its space.
- The name input no longer expands the first-run dialog.
- The yearly picker accepts February 29 in any current year.
- Membership image loading releases native image resources and handles load errors.
- New debug entitlement overrides carry a debug-only flag. Release code ignores that flag as an entitlement source.
- Purchase setup follows settings load. Canceled purchases can retry, and purchase callbacks handle errors.
- Android accepts an external release signing configuration from `~/.sometime-signing/key.properties` or `SOMETIME_SIGNING_PROPERTIES`.
- README architecture and notification notes now match the app.
- Eliminated 17.7 MB uncompressed font bloat by removing redundant CJK fonts. App uses Geist for text and Parisienne for membership display names.
- Protected state lookups, drag-drop handling, recurrence rules, and DateTime parser against null/bounds crashes.

## REMAINING MANUAL ITEMS

- Supply an upload key through the external signing file with `storeFile`, `storePassword`, `keyAlias`, and `keyPassword`.
- Build a new AAB with that key before a Play upload. Do not commit the signing file or keystore.
- Confirm the final application ID and version code before the first Play upload.
- Configure Play Console products and test real purchases, cancellation, and restore through a Play test track.
- Check legacy supporter data from older debug installs. Those records have no debug provenance flag. Use clean release test data.
- Set the production privacy policy and support links in `lib/app/app_config.dart`.
- Complete the store listing, screenshots, content rating, Data Safety form, and applicable testing requirements in Play Console.
- Complete the Google Play declaration for `SCHEDULE_EXACT_ALARM` under user-facing task reminders (do not use `USE_EXACT_ALARM`).
- Check Google Play Billing data use before completing Data Safety. Billing adds Internet and network-state permissions.
- Complete physical-device tests for notification denial, reboot, clock changes, timezone changes, and battery restrictions.
- Complete end-to-end widget completion and plus-link tests after process death and app update.
- Complete the medium widget visual check on a launcher. Native views build, but this audit did not confirm final launcher placement.
- Complete device visual checks for task edit, completed tasks, space management, support, membership export, and Material You.
- Check TalkBack, large text, and reduced motion on a physical device.
- Build and test the changed iOS widget on macOS. Windows cannot validate its native build.

## BLOCKERS

No analyzer, test, APK build, or AAB build blocker remains.
Store submission is not approved by this report. The manual release checks above remain open.

## Build notes

The audit used Flutter 3.47.2 and Dart 3.13.2 from the project SDK.
Run each command from the project root. Use `.tools/flutter/bin/flutter.bat` if Flutter is not on PATH.

The Kotlin migration warning for the application was resolved by removing the redundant Kotlin plugin declaration.
The remaining notice originates from `dynamic_color` 1.8.1.
Follow the [Flutter migration guide](https://docs.flutter.dev/release/breaking-changes/migrate-to-built-in-kotlin/for-app-developers) when compatible dependencies are available.

`objective_c` 9.5.0 comes through `share_plus`, its platform interface, and `path_provider_foundation`.
Both release builds now pass from the normal `Sometime` project path with native hooks enabled.

The APK contains three processor architectures. Compressed native libraries account for about 55 MiB in universal builds.
The 16 membership WebP gradients account for about 15 MiB. The Play bundle supports device-specific delivery.
The app has no added analytics or advertising SDK. Google Play Billing includes its own network dependencies.
