# Repository guidance

- This is a Flutter app with Android and iOS native code. Keep task writes in `TodoController` so local storage, reminders, and widgets observe the same state.
- Read only the project notes relevant to the change:
  - Task dates, routines, and reminders: `docs/scheduling.md`
  - Verification and device coverage: `docs/verification.md`
  - Assistant and other native entry points: `docs/PLATFORM.md`
- Use Flutter 3.47.2 and Dart 3.13.2. The standard checks are `flutter analyze` and `flutter test`.
