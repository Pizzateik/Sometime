Verification date: August 31, 2026.
The checks used Flutter 3.47.2 and Dart 3.13.2 on Windows.
The Android device was a Pixel 8 emulator with Android 16, API 36, and SwiftShader software graphics.

| Check | Result |
| --- | --- |
| `flutter analyze` | No issues |
| `flutter test` | All 23 tests passed |
| Dart format check | No changes required |
| Android device function test | Passed |
| Android profile interaction test | Passed and recorded frame timings |
| Android release builds | ARM64 and x86_64 APKs built |
| Web release build | Built and checked in the local browser |
| Native iOS build | Not run. This host has no macOS or Xcode |

The widget tests cover task creation, completion, storage recovery, text contrast, and accessible touch targets.
They also cover reduced motion, screen rotation, and 200% text size.
The layout tests use iOS and Android themes at 320 × 568 and 844 × 390 logical pixels.
These tests include keyboard insets and safe areas.
Theme tests do not replace native iOS tests.

The Android function test used the native keyboard and local device storage.
The final release APK also passed a separate manual test with native key events.
That test added “Milch kaufen” to Demnächst and completed the task.
The task and its completion state remained after a forced process stop and cold start.
The local browser check also confirmed persistence after a page reload.

The profile test used live frame scheduling after a warmup.
It recorded 12 completion changes and three input surface open and close cycles.
The keyboard opened during each input cycle.
The [full frame report](performance-android-emulator.json) contains the raw timings.

| Frame measurement | Result |
| --- | --- |
| Recorded frames | 371 |
| Mean UI build time | 1.238 ms |
| UI build time, 99th percentile | 5.254 ms |
| UI builds above the report budget | 0 |
| Mean raster time | 12.243 ms |
| Raster time, 99th percentile | 29.789 ms |
| Raster frames above the report budget | 79 |

The software renderer missed the frame budget for some frames.
These results do not prove stable 60 or 120 FPS on physical devices.
The row animation updates its own subtree, and the input surface has a separate animation controller.
The app does not use a full-screen blur.

The remaining device checks need an iPhone and an Android phone, including a device with a 120 Hz display.
They must cover the native keyboard, safe areas, VoiceOver or TalkBack, and frame timing.
The iOS build also needs a Mac with Xcode.

The local APKs use a development signing key.
Store distribution requires a release key and the correct application identifiers.

The native Android captures show the [main screen](previews/android-home.png) and the [input surface with its keyboard](previews/android-sheet.png).
