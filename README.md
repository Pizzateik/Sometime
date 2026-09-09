# Sometime

**Today. Soon. Sometime.**

A calm todo app organized around when something matters, not where it belongs.

<!-- TODO: Add a hero image at docs/images/hero.png. -->
> Screenshot coming soon.

## Why Sometime?

Most todo apps put tasks for today beside tasks that may matter weeks later. Sometime separates these time horizons without adding projects, tags, accounts, or more setup.

Organization should reduce organization, not create more.

### Today

Things that matter now.

### Soon

Things you want to return to in the near future.

### Sometime

Things worth remembering without putting them on today's list.

## Preview

The repository does not include product screenshots yet.

<!--
TODO: Add these images when they are ready:
- docs/images/hero.png
- docs/images/home.png
- docs/images/creation.png
- docs/images/widget.png
- docs/images/appearance.png
-->

## Features

- Today, Soon, and Sometime task horizons.
- Up to five Spaces for separate areas of life or work.
- Natural date and time recognition.
- Local reminders and recurring tasks.
- Android pinned task notifications.
- Android home screen widgets.
- Drag interactions to reorder and move tasks.
- Completion history with local archive cleanup.
- Light, dark, soft, and Material You appearance options.
- System or custom color for Material You on supported Android devices.
- Onboarding and in-app tutorials.
- Import and export of local data.
- English, German, Spanish, Portuguese (Brazil), French, and Japanese localization.
- Offline-first task storage on the device.

Supporter purchase code exists, but production purchases are currently disabled. The app does not advertise Supporter purchases as available.

## Privacy

- No account is required.
- The app has no analytics.
- The app has no advertising.
- The app sends no task telemetry.
- Task data is stored locally.
- The project has no cloud backend of its own.

Sometime uses Android and iOS platform services for system functions such as notifications and widgets. The purchase integration can use platform store services when enabled, but production purchases are currently disabled.

## Tech

- Flutter and Dart.
- `shared_preferences` for local storage.
- `dynamic_color` for Material You color support.
- Flutter localization and `intl` for translated text and dates.
- `file_selector` and `share_plus` for local data transfer.
- `in_app_purchase` for the disabled Supporter purchase code.
- Native Kotlin integrations for Android reminders and App Widgets with `RemoteViews`.
- A native Swift widget target for iOS.
- Geist, Parisienne, and SometimeIcons font assets.

The primary brand color is `#FF5C5C`. The main app typeface is Geist.

## Project structure

```text
Sometime/
├── lib/
│   ├── app/              App setup, theme, strings, and formatters
│   ├── membership/       Supporter card assets and views
│   ├── models/           Tasks, Spaces, settings, and local storage
│   ├── screens/          Onboarding, task pages, and settings
│   ├── services/         Reminders, widgets, and data transfer
│   ├── state/            App controllers
│   ├── utils/            Natural date and time parsing
│   └── widgets/          Reusable task and input widgets
├── android/              Android app and native integrations
├── ios/                  iOS app and widget target
├── assets/               Fonts, icons, and visual assets
├── test/                 Unit and widget tests
├── integration_test/     Device tests
├── docs/                 Scheduling and verification notes
└── tool/                 Local build and asset scripts
```

## Getting started

Use Flutter 3.47.2. The repository pins this version in `.fvmrc` and requires Dart 3.13.2 or later within the supported SDK range.

For Android development, install the Android SDK and use a device or emulator with Android 7.0 (API 24) or later. Use macOS and Xcode for iOS work.

```sh
git clone https://github.com/<your-account>/Sometime.git
cd Sometime
flutter pub get
flutter run
```

Production signing credentials are intentionally not included in the repository. Debug development does not require them.

## Building

Run the local checks with these commands:

```sh
flutter pub get
flutter analyze
flutter test
flutter run
```

Release builds need an external signing file at `~/.sometime-signing/key.properties`. Set `SOMETIME_SIGNING_PROPERTIES` when you use another path. Keep the file and its keystore outside the repository.

```sh
flutter build appbundle --release
```

## Contributing

The repository is private while Sometime is prepared for its first Android release. Issues and pull requests are welcome after the repository becomes public.

1. Create a focused branch.
2. Make a focused change.
3. Run `flutter analyze` and `flutter test`.
4. Open a pull request with a short description.

## Status

Sometime is intended for a future open-source release. The repository is private while the first Android release is prepared. It has no store listing yet. Further iOS work and platform checks may follow later.

## License

No license file exists yet. Licensing information will be added before public release. Until then, do not assume reuse rights.
