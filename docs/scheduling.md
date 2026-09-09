# Task planning

The task editor stores a short description, a local date, a time, and an optional routine.
Dates and times are independent. A time without a date uses the creation date for sorting.
Scheduled tasks appear first in each category, with the latest planned time first.
Unscheduled tasks keep their manual order. A move between categories keeps all task details.

A routine stores one current task and at most one future task.
Completion keeps the existing animation and creates the next task after the completion transition.
The next task stays hidden until its local date arrives. Its time does not delay activation on that date.
The app checks future tasks at startup, on resume, and at local midnight while the app remains open.
Missed dates do not produce a list of duplicate tasks.

Weekly routines use the selected weekdays. Monthly routines use one day of the month.
If a month does not contain that day, the routine uses the last day of the month.
Yearly routines use a month and day. February 29 uses February 28 in a year without February 29.
The original rule stays unchanged after this adjustment.

Restoring a completed task removes its future task if that task is still hidden.
If the next task is already active, the restored task becomes a task without a routine.
This prevents two active copies of the same routine.
Completed tasks still leave the visible list after the local day changes.
The app removes archived completion records after seven days when it checks the saved state.

Existing saved tasks load without the new optional fields. The app keeps saved space names and identifiers.
The app schedules local reminders and Android pinned task notifications.
The app does not write to an external calendar.

# Icons and Android build

The icon generator reads the three PNG source files in `assets/icon`.
Android 26 and later use separate foreground and background layers.
Android 33 and later also use the supplied monochrome layer.
The launcher controls themed icon colors. The icon code does not depend on the Flutter appearance setting.
iOS uses the opaque color composite. All generated assets can be recreated with `tool/generate_icons.ps1`.

Flutter 3.47.2 reports a Kotlin Gradle Plugin warning for `dynamic_color` 1.8.1.
The current Android build succeeds. This warning does not require a VS Code setting change.
Before a future Flutter upgrade, check whether `dynamic_color` supports built-in Kotlin.
Follow the [Flutter migration guide](https://docs.flutter.dev/release/breaking-changes/migrate-to-built-in-kotlin/for-app-developers) when that dependency supports the change.
