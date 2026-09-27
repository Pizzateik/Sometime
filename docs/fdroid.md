# F-Droid release checklist

Sometime's Android application ID is `de.eikrose.sometime`. Keep that ID for all future Android releases. The F-Droid flavor starts at `lib/main_fdroid.dart`, omits Play Billing from Android plugin registration, and produces an unsigned release APK for F-Droid to sign. Google Assistant App Actions require Google Play ingestion and are not advertised in the F-Droid listing.

## Before submitting

1. Verify the public source tree and all packaged dependencies and assets meet the [F-Droid inclusion policy](https://fdroid.gitlab.io/jekyll-fdroid/en/docs/Inclusion_Policy/). Source and original Sometime artwork are Apache-2.0-licensed; third-party licenses are in `THIRD_PARTY_NOTICES.md`. Keep proprietary SDKs out of the F-Droid artifact.
2. A dedicated website is optional. F-Droid requires a public source repository and FOSS license, while its metadata can link to `https://eikrose.de` as the project website. Confirm the domain serves the intended page before submitting it as a listing link. A privacy page is useful for users but is not an F-Droid inclusion prerequisite; set `AppConfig.privacyPolicyUrl` only after publishing its real URL. The app currently has no account, ads, analytics, or backend.
3. Use Flutter 3.47.2 and Dart 3.13.2. Run `flutter pub get`, `flutter analyze`, `flutter test`, and `flutter build apk --release --flavor fdroid`. Inspect the resulting APK's application ID, permissions, embedded libraries, and absence of Play Billing before release. Test tasks, reminders, widgets, import/export, and upgrade behavior on a physical Android device.
4. Commit the release source, then create and push a version tag pointing to that exact commit. `pubspec.yaml` version code must increase for each Android update. The existing `v1.0.0-rc.1` tag predates the ID and license changes; use the new `v1.0.0` release commit and tag for submission.
5. The English and German F-Droid listing, icon, screenshots, and version-code changelog live in `fastlane/metadata/android/`. Update the changelog filename and content when the version code changes. Review screenshot accuracy for the release.

## Submit to the official repository

The proposed F-Droid build recipe is in `fdroid/metadata/de.eikrose.sometime.yml`. Copy it to a fork of [fdroiddata](https://gitlab.com/fdroid/fdroiddata) as `metadata/de.eikrose.sometime.yml`, then open a merge request. Its build block points to the `v1.0.0` source tag, uses the `fdroid` flavor and `lib/main_fdroid.dart`, and specifies Flutter 3.47.2 and the APK output path. Validate the recipe with `fdroid lint de.eikrose.sometime` and fdroiddata CI/build before requesting review. A local Flutter build alone does not prove that F-Droid's isolated builder can reproduce it.

F-Droid normally signs source builds with its own per-app key. That signature differs from APKs published under a developer or Play key, so Android cannot upgrade between those channels in place. Decide whether to invest in a reproducible build and developer-signed binary verification **before** the first F-Droid publication if a shared signature matters. Do not upload a debug-signed APK as a release.

The universal F-Droid APK is about 57 MB. ABI-specific APKs could reduce downloads, but require separate F-Droid build blocks and distinct, correctly ordered version codes. Start with the tested universal build unless those extra recipes are validated.

The [submission guide](https://fdroid.gitlab.io/jekyll-fdroid/docs/Submitting_to_F-Droid_Quick_Start_Guide/) describes the metadata merge request and review. Inclusion is decided by F-Droid maintainers; this repository cannot publish into the official catalog by itself.
