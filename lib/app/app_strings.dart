import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

class AppStrings {
  const AppStrings(this.locale);

  final Locale locale;

  static const supportedLocales = <Locale>[
    Locale('en'),
    Locale('de'),
    Locale('es'),
    Locale('pt', 'BR'),
    Locale('fr'),
    Locale('ja'),
  ];

  static Locale resolveLocale(Locale? locale) {
    if (locale == null) return const Locale('en');
    if (locale.languageCode == 'pt' &&
        locale.countryCode?.toUpperCase() == 'BR') {
      return const Locale('pt', 'BR');
    }
    if (const {'en', 'de', 'es', 'fr', 'ja'}.contains(locale.languageCode)) {
      return Locale(locale.languageCode);
    }
    return const Locale('en');
  }

  String get _language => switch (locale.languageCode) {
    'pt' when locale.countryCode?.toUpperCase() == 'BR' => 'pt-BR',
    'de' || 'es' || 'fr' || 'ja' => locale.languageCode,
    _ => 'en',
  };

  bool get de => _language == 'de';

  static AppStrings of(BuildContext context) =>
      AppStrings(resolveLocale(Localizations.localeOf(context)));

  String _t(String key) =>
      (_translations[_language] ?? _translations['en']!).containsKey(key)
      ? _translations[_language]![key]!
      : _translations['en']![key]!;

  String get settings => _t('settings');
  String get appIcon => _t('appIcon');
  String get appName => 'Sometime';
  String get appDescription => _t('appDescription');
  String get whyBuilt => _t('whyBuilt');
  String get whyBuiltBody => _t('whyBuiltBody');
  String get offlineFirst => _t('offlineFirst');
  String get adFree => _t('adFree');
  String get openSource => _t('openSource');
  String get noAccount => _t('noAccount');
  String get experience => _t('experience');
  String get notifications => _t('notifications');
  String get language => _t('language');
  String get dataPrivacy => _t('dataPrivacy');
  String get exportData => _t('exportData');
  String get importData => _t('importData');
  String get importQuestion => _t('importQuestion');
  String get importExplanation => _t('importExplanation');
  String get importAction => _t('importAction');
  String get transferError => _t('transferError');
  String get transferSuccess => _t('transferSuccess');
  String get saveCard => _t('saveCard');
  String get displayName => _t('displayName');
  String get haptics => _t('haptics');
  String get morningReminder => _t('morningReminder');
  String get notificationSettings => _t('notificationSettings');
  String get storage => _t('storage');
  String get onDevice => _t('onDevice');
  String get deleteAll => _t('deleteAll');
  String get about => _t('about');
  String madeBy(String name) => _t('madeBy').replaceAll('{name}', name);
  String get sourceCode => _t('sourceCode');
  String get privacyPolicy => _t('privacyPolicy');
  String get licenses => _t('licenses');
  String get version => _t('version');
  String get support => _t('support');
  String get supporterThanks => _t('supporterThanks');
  String get rerollCardDescription => _t('rerollCardDescription');
  String get rerollCardQuestion => _t('rerollCardQuestion');
  String get rerollCardExplanation => _t('rerollCardExplanation');
  String get reroll => _t('reroll');
  String get supportNote => _t('supportNote');
  String get supportBody => _t('supportBody');
  String get becomeSupporter => _t('becomeSupporter');
  String get restore => _t('restore');
  String get supporter => 'Sometime Supporter';
  String get nameQuestion => _t('nameQuestion');
  String get welcomeToSometime => _t('welcomeToSometime');
  String get onboardingNameQuestion => _t('onboardingNameQuestion');
  String get nameHint => _t('nameHint');
  String get you => _t('you');
  String get continueLabel => _t('continueLabel');
  String get skip => _t('skip');
  String get cancel => _t('cancel');
  String get save => _t('save');
  String get create => _t('create');
  String get notSet => _t('notSet');
  String get style => _t('style');
  String get mode => _t('mode');
  String get materialYou => 'Material You';
  String get color => _t('color');
  String get customColor => _t('customColor');
  String get system => _t('system');
  String get english => 'English';
  String get german => 'Deutsch';
  String get spanish => 'Español';
  String get portugueseBrazil => 'Português (Brasil)';
  String get french => 'Français';
  String get japanese => '日本語';
  String get crisp => _t('crisp');
  String get normal => crisp;
  String get soft => _t('soft');
  String get light => _t('light');
  String get dark => _t('dark');
  String get today => _t('today');
  String get soon => _t('soon');
  String get sometime => _t('sometime');
  String get completed => _t('completed');
  String get emptySpace => _t('emptySpace');
  String groupName(int index) => [today, soon, sometime][index];
  String get title => _t('title');
  String get description => _t('description');
  String get date => _t('date');
  String get time => _t('time');
  String get reminder => _t('reminder');
  String get routine => _t('routine');
  String get weekly => _t('weekly');
  String get monthly => _t('monthly');
  String get yearly => _t('yearly');
  String get none => _t('none');
  String reminderName(int index) => _reminders[_language]![index];
  List<String> get weekdayInitials => _weekdays[_language]!;
  String get closeInput => _t('closeInput');
  String get newTask => _t('newTask');
  String get firstEmptyHomeHint => _t('firstEmptyHomeHint');
  String get firstTaskEditTutorialTitle => _t('firstTaskEditTutorialTitle');
  String firstTaskEditTutorialBody({required bool showPin}) =>
      _t(showPin ? 'firstTaskBodyPin' : 'firstTaskBodyNoPin');
  String get spaceManagementTutorialTitle => _t('spaceManagementTutorialTitle');
  String get spaceManagementTutorialBody => _t('spaceManagementTutorialBody');
  String get move => _t('move');
  String get tutorialPin => _t('tutorialPin');
  String get gotIt => _t('gotIt');
  String get editTask => _t('editTask');
  String get addTask => _t('addTask');
  String get saveChanges => _t('saveChanges');
  String get newSpace => _t('newSpace');
  String get renameSpace => _t('renameSpace');
  String get deleteSpace => _t('deleteSpace');
  String get deleteSpaceQuestion => _t('deleteSpaceQuestion');
  String get deleteSpaceExplanation => _t('deleteSpaceExplanation');
  String get undo => _t('undo');
  String get deletedEntry => _t('deletedEntry');
  String get delete => _t('delete');
  String get edit => _t('edit');
  String get pin => _t('pin');
  String get pinToNotification => _t('pinToNotification');
  String get unpin => _t('unpin');
  String get retry => _t('retry');
  String get loadError => _t('loadError');
  String get deleteQuestion => _t('deleteQuestion');
  String get deleteExplanation => _t('deleteExplanation');
  String get settingsSaveError => _t('settingsSaveError');
  String get taskSaveError => _t('taskSaveError');
  String get maxSpaces => _t('maxSpaces');
  String get openSettings => _t('openSettings');
  String openSpace(String name) => _t('openSpace').replaceAll('{name}', name);
  String get releaseToClose => _t('releaseToClose');
  String get pinnedToNotifications => _t('pinnedToNotifications');
  String get hue => _t('hue');
  String get saturation => _t('saturation');
  String get brightness => _t('brightness');
  String get useColor => _t('useColor');
  String get storeConnecting => _t('storeConnecting');
  String get storeWaiting => _t('storeWaiting');
  String get supportUnavailable => _t('supportUnavailable');
  String get purchaseError => _t('purchaseError');
  String get purchaseCanceled => _t('purchaseCanceled');
  String get noPurchase => _t('noPurchase');
  String get supportThankYou => _t('supportThankYou');
  String get debug => 'DEBUG';
  String get previewSupporterState => _t('previewSupporterState');
  String get resetSupporterLocally => _t('resetSupporterLocally');
  String get unlockSupporterLocally => _t('unlockSupporterLocally');
  String get regenerateMembershipCard => _t('regenerateMembershipCard');
  String get systemLanguage => _t('systemLanguage');
  String get exactAlarmWarning => _t('exactAlarmWarning');

  String externalLink(String label) =>
      _t('externalLink').replaceAll('{label}', label);

  String notificationProblem(String value) {
    final key = switch (value) {
      'Notifications are off. Enable them in Settings.' => 'notificationsOff',
      'Notifications are not available. The task will still be saved.' =>
        'notificationsUnavailable',
      'Notifications could not be updated. Your task data is kept.' =>
        'notificationsUpdateFailed',
      'Android may delay reminders. Allow exact alarms in system settings.' =>
        'exactAlarmWarning',
      'Some reminders could not be scheduled.' => 'remindersScheduleFailed',
      'iOS allows 64 pending reminders. Open Sometime to schedule later reminders.' =>
        'iosReminderLimit',
      _ => null,
    };
    return key == null ? value : _t(key);
  }

  String supporterSince(DateTime date) {
    final localizedDate = DateFormat('MMM yyyy', _language).format(date);
    return _t('supporterSince')
        .replaceAll('{date}', localizedDate)
        .replaceAll('{month}', DateFormat('MMM', _language).format(date))
        .replaceAll('{year}', date.year.toString())
        .replaceAll('..', '.');
  }

  String supporterCardSemantics(String name, DateTime date) =>
      _t('supporterCardSemantics')
          .replaceAll('{name}', name)
          .replaceAll('{date}', supporterSince(date));

  static const _translations = <String, Map<String, String>>{
    'en': {
      'settings': 'Settings',
      'appIcon': 'Sometime app icon',
      'appDescription':
          'A calmer place for what matters today, soon, or sometime.',
      'whyBuilt': 'Why I built Sometime',
      'whyBuiltBody': "Hello 👋 I'm Eik, and I built Sometime while studying because most todo apps mixed what I had to do today with things I might want to do weeks or months later.\n\nSometime separates those time horizons without adding projects, tags, or more organization.",
      'offlineFirst': 'Offline-first',
      'adFree': 'Ad-free',
      'openSource': 'Open source',
      'noAccount': 'No account required',
      'experience': 'Experience',
      'notifications': 'Notifications',
      'language': 'Language',
      'dataPrivacy': 'Data & Privacy',
      'exportData': 'Export data',
      'importData': 'Import data',
      'importQuestion': 'Import Sometime backup?',
      'importExplanation':
          'This will replace the data currently stored on this device.',
      'importAction': 'Import',
      'transferError': 'The file could not be processed. Check the file format and try again.',
      'transferSuccess': 'Done',
      'saveCard': 'Save membership card',
      'displayName': 'Display name',
      'haptics': 'Haptics',
      'morningReminder': 'Morning reminder time',
      'notificationSettings': 'Notification settings',
      'storage': 'STORAGE',
      'onDevice': 'On this device',
      'deleteAll': 'Delete all data',
      'about': 'ABOUT SOMETIME',
      'madeBy': 'Made by {name}',
      'sourceCode': 'Source Code',
      'privacyPolicy': 'Privacy Policy',
      'licenses': 'Open Source Licenses',
      'version': 'Version',
      'support': 'Support Sometime',
      'supporterThanks': 'Thanks for supporting Sometime',
      'rerollCardDescription': 'Click to reroll Supporter Card Design',
      'rerollCardQuestion': 'Reroll card design?',
      'rerollCardExplanation':
          'This will replace your current Supporter Card design.',
      'reroll': 'Reroll',
      'supportNote':
          'Sometime is independently developed, ad-free, and open source.',
      'supportBody': 'If you enjoy using Sometime, you can support me and help fund its continued development.',
      'becomeSupporter': 'Become a Supporter',
      'restore': 'Restore Purchases',
      'nameQuestion': 'What should Sometime call you?',
      'welcomeToSometime': 'Welcome to Sometime',
      'onboardingNameQuestion': 'How should we call you?',
      'nameHint': 'Name',
      'you': 'You',
      'continueLabel': 'Continue',
      'skip': 'Skip',
      'cancel': 'Cancel',
      'save': 'Save',
      'create': 'Create',
      'notSet': 'Not set',
      'style': 'Style',
      'mode': 'Mode',
      'color': 'Color',
      'customColor': 'Own color',
      'system': 'System',
      'crisp': 'Crisp',
      'soft': 'Soft',
      'light': 'Light',
      'dark': 'Dark',
      'today': 'Today',
      'soon': 'Soon',
      'sometime': 'Sometime',
      'completed': 'Completed',
      'emptySpace': 'Everything is done :D',
      'title': 'Title',
      'description': 'Description',
      'date': 'Date',
      'time': 'Time',
      'reminder': 'Reminder',
      'routine': 'Routine',
      'weekly': 'Weekly',
      'monthly': 'Monthly',
      'yearly': 'Yearly',
      'none': 'None',
      'closeInput': 'Close input',
      'newTask': 'New task',
      'firstEmptyHomeHint': 'Nothing here yet',
      'firstTaskEditTutorialTitle': 'Manage your task',
      'firstTaskBodyPin': 'Long-press a task to reveal its controls. Use them to move, edit, or pin it.',
      'firstTaskBodyNoPin': 'Long-press a task to reveal its controls. Use them to move or edit it.',
      'spaceManagementTutorialTitle': 'Manage Spaces',
      'spaceManagementTutorialBody':
          'Press and hold a Space to create, rename, or delete Spaces.',
      'move': 'Move',
      'tutorialPin': 'Pin',
      'gotIt': 'Got it',
      'editTask': 'Edit task',
      'addTask': 'Add task',
      'saveChanges': 'Save changes',
      'newSpace': 'New space',
      'renameSpace': 'Rename space',
      'deleteSpace': 'Delete Space',
      'deleteSpaceQuestion': 'Delete this Space?',
      'deleteSpaceExplanation': 'Tasks in this Space will also be deleted.',
      'undo': 'Undo',
      'deletedEntry': 'Item deleted',
      'delete': 'Delete',
      'edit': 'Edit',
      'pin': 'Pin to notification',
      'pinToNotification': 'Pin to notification',
      'unpin': 'Unpin',
      'retry': 'Try again',
      'loadError': 'Tasks could not be loaded.',
      'deleteQuestion': 'Delete all data?',
      'deleteExplanation': 'This deletes tasks, spaces, routines, and local preferences from this device. A store purchase remains restorable.',
      'externalLink': '{label}, external link',
      'settingsSaveError': 'Settings could not be saved.',
      'taskSaveError': 'The task could not be saved.',
      'maxSpaces': 'You can have up to 5 Spaces.',
      'openSettings': 'Open Settings',
      'openSpace': 'Open {name}',
      'releaseToClose': 'Release to close',
      'pinnedToNotifications': 'Pinned to notifications',
      'hue': 'Hue',
      'saturation': 'Saturation',
      'brightness': 'Brightness',
      'useColor': 'Use color',
      'storeConnecting': 'Connecting to the App Store…',
      'storeWaiting': 'Waiting for the App Store…',
      'supportUnavailable': 'Support is not available right now.',
      'purchaseError': 'The purchase could not be completed.',
      'purchaseCanceled': 'Purchase canceled.',
      'noPurchase': 'No purchase to restore was found.',
      'supportThankYou': 'Thank you for supporting Sometime!',
      'previewSupporterState': 'Preview supporter state',
      'resetSupporterLocally': 'Reset supporter locally',
      'unlockSupporterLocally': 'Unlock supporter locally',
      'regenerateMembershipCard': 'Regenerate membership card',
      'systemLanguage': 'System',
      'supporterSince': 'Supporter since {month} {year}',
      'supporterCardSemantics': 'Sometime Supporter Card for {name}, {date}',
      'notificationsOff': 'Notifications are off. Enable them in Settings.',
      'notificationsUnavailable':
          'Notifications are not available. The task will still be saved.',
      'notificationsUpdateFailed':
          'Notifications could not be updated. Your task data is kept.',
      'exactAlarmWarning':
          'Android may delay reminders. Allow exact alarms in system settings.',
      'remindersScheduleFailed': 'Some reminders could not be scheduled.',
      'iosReminderLimit': 'iOS allows 64 pending reminders. Open Sometime to schedule later reminders.',
    },
    'de': {
      'settings': 'Einstellungen',
      'appIcon': 'Sometime-App-Symbol',
      'appDescription': 'Ein ruhigerer Ort für das, was heute, bald oder irgendwann wichtig ist.',
      'whyBuilt': 'Warum ich Sometime entwickelt habe',
      'whyBuiltBody': 'Hallo 👋 Ich bin Eik und habe Sometime während meines Studiums entwickelt, weil die meisten Todo-Apps Aufgaben für heute mit Dingen vermischen, die vielleicht erst in Wochen oder Monaten wichtig werden.\n\nSometime trennt diese Zeithorizonte, ohne Projekte, Tags oder zusätzliche Organisation einzuführen.',
      'offlineFirst': 'Offline verfügbar',
      'adFree': 'Ohne Werbung',
      'openSource': 'Open Source',
      'noAccount': 'Kein Konto nötig',
      'experience': 'Darstellung',
      'notifications': 'Mitteilungen',
      'language': 'Sprache',
      'dataPrivacy': 'Daten und Datenschutz',
      'exportData': 'Daten exportieren',
      'importData': 'Daten importieren',
      'importQuestion': 'Sometime-Backup importieren?',
      'importExplanation': 'Dies ersetzt die Daten, die aktuell auf diesem Gerät gespeichert sind.',
      'importAction': 'Importieren',
      'transferError': 'Die Datei konnte nicht verarbeitet werden. Prüfe das Dateiformat und versuche es erneut.',
      'transferSuccess': 'Fertig',
      'saveCard': 'Membership-Karte speichern',
      'displayName': 'Anzeigename',
      'haptics': 'Haptik',
      'morningReminder': 'Zeit der morgendlichen Erinnerung',
      'notificationSettings': 'Mitteilungseinstellungen',
      'storage': 'SPEICHER',
      'onDevice': 'Auf diesem Gerät',
      'deleteAll': 'Alle Daten löschen',
      'about': 'ÜBER SOMETIME',
      'madeBy': 'Von {name}',
      'sourceCode': 'Quellcode',
      'privacyPolicy': 'Datenschutzerklärung',
      'licenses': 'Open-Source-Lizenzen',
      'version': 'Version',
      'support': 'Sometime unterstützen',
      'supporterThanks': 'Danke, dass du Sometime unterstützt',
      'rerollCardDescription':
          'Tippen, um das Supporter-Kartendesign neu zu würfeln',
      'rerollCardQuestion': 'Kartendesign neu würfeln?',
      'rerollCardExplanation':
          'Dein aktuelles Supporter-Kartendesign wird dadurch ersetzt.',
      'reroll': 'Neu würfeln',
      'supportNote':
          'Sometime wird unabhängig, werbefrei und als Open Source entwickelt.',
      'supportBody': 'Wenn dir Sometime gefällt, kannst du mich unterstützen und damit die weitere Entwicklung finanzieren.',
      'becomeSupporter': 'Supporter werden',
      'restore': 'Käufe wiederherstellen',
      'nameQuestion': 'Wie soll Sometime dich nennen?',
      'welcomeToSometime': 'Willkommen bei Sometime',
      'onboardingNameQuestion': 'Wie sollen wir dich nennen?',
      'nameHint': 'Name',
      'you': 'Du',
      'continueLabel': 'Weiter',
      'skip': 'Überspringen',
      'cancel': 'Abbrechen',
      'save': 'Speichern',
      'create': 'Erstellen',
      'notSet': 'Nicht festgelegt',
      'style': 'Stil',
      'mode': 'Modus',
      'color': 'Farbe',
      'customColor': 'Eigene Farbe',
      'system': 'System',
      'crisp': 'Klar',
      'soft': 'Sanft',
      'light': 'Hell',
      'dark': 'Dunkel',
      'today': 'Heute',
      'soon': 'Demnächst',
      'sometime': 'Irgendwann',
      'completed': 'Erledigt',
      'emptySpace': 'Alles erledigt :D',
      'title': 'Titel',
      'description': 'Beschreibung',
      'date': 'Datum',
      'time': 'Zeit',
      'reminder': 'Erinnerung',
      'routine': 'Routine',
      'weekly': 'Wöchentlich',
      'monthly': 'Monatlich',
      'yearly': 'Jährlich',
      'none': 'Keine',
      'closeInput': 'Eingabe schließen',
      'newTask': 'Neue Aufgabe',
      'firstEmptyHomeHint': 'Noch nichts hier',
      'firstTaskEditTutorialTitle': 'Aufgabe verwalten',
      'firstTaskBodyPin': 'Halte eine Aufgabe lange gedrückt, um ihre Schaltflächen anzuzeigen. Damit kannst du sie verschieben, bearbeiten oder anheften.',
      'firstTaskBodyNoPin': 'Halte eine Aufgabe lange gedrückt, um ihre Schaltfläche anzuzeigen. Damit kannst du sie verschieben oder bearbeiten.',
      'spaceManagementTutorialTitle': 'Spaces verwalten',
      'spaceManagementTutorialBody': 'Halte einen Space gedrückt, um Spaces zu erstellen, umzubenennen oder zu löschen.',
      'move': 'Verschieben',
      'tutorialPin': 'Anheften',
      'gotIt': 'Verstanden',
      'editTask': 'Aufgabe bearbeiten',
      'addTask': 'Aufgabe hinzufügen',
      'saveChanges': 'Änderungen speichern',
      'newSpace': 'Neuer Space',
      'renameSpace': 'Space umbenennen',
      'deleteSpace': 'Space löschen',
      'deleteSpaceQuestion': 'Diesen Space löschen?',
      'deleteSpaceExplanation':
          'Tasks in diesem Space werden ebenfalls gelöscht.',
      'undo': 'Rückgängig',
      'deletedEntry': 'Eintrag gelöscht',
      'delete': 'Löschen',
      'edit': 'Bearbeiten',
      'pin': 'An Mitteilung anheften',
      'pinToNotification': 'An Benachrichtigungen anpinnen',
      'unpin': 'Anheftung lösen',
      'retry': 'Erneut versuchen',
      'loadError': 'Aufgaben konnten nicht geladen werden.',
      'deleteQuestion': 'Alle Daten löschen?',
      'deleteExplanation': 'Dies löscht Aufgaben, Spaces, Routinen und lokale Einstellungen auf diesem Gerät. Ein Store-Kauf bleibt wiederherstellbar.',
      'externalLink': '{label}, externer Link',
      'settingsSaveError': 'Einstellungen konnten nicht gespeichert werden.',
      'taskSaveError': 'Die Aufgaben konnten nicht gespeichert werden.',
      'maxSpaces': 'Du kannst bis zu 5 Spaces haben.',
      'openSettings': 'Einstellungen öffnen',
      'openSpace': '{name} öffnen',
      'releaseToClose': 'Zum Schließen loslassen',
      'pinnedToNotifications': 'An Mitteilungen angeheftet',
      'hue': 'Farbton',
      'saturation': 'Sättigung',
      'brightness': 'Helligkeit',
      'useColor': 'Farbe verwenden',
      'storeConnecting': 'Verbindung zum App Store wird hergestellt…',
      'storeWaiting': 'Warten auf den App Store…',
      'supportUnavailable': 'Support ist gerade nicht verfügbar.',
      'purchaseError': 'Der Kauf konnte nicht abgeschlossen werden.',
      'purchaseCanceled': 'Kauf abgebrochen.',
      'noPurchase': 'Kein wiederherstellbarer Kauf gefunden.',
      'supportThankYou': 'Danke, dass du Sometime unterstützt!',
      'previewSupporterState': 'Supporter-Status anzeigen',
      'resetSupporterLocally': 'Supporter lokal zurücksetzen',
      'unlockSupporterLocally': 'Supporter lokal freischalten',
      'regenerateMembershipCard': 'Membership-Karte neu erstellen',
      'systemLanguage': 'System',
      'supporterSince': 'Supporter seit {month} {year}',
      'supporterCardSemantics': 'Sometime Supporter-Karte für {name}, {date}',
      'notificationsOff':
          'Mitteilungen sind aus. Aktiviere sie in den Einstellungen.',
      'notificationsUnavailable': 'Mitteilungen sind nicht verfügbar. Die Aufgabe wird trotzdem gespeichert.',
      'notificationsUpdateFailed': 'Mitteilungen konnten nicht aktualisiert werden. Die Aufgabendaten bleiben erhalten.',
      'exactAlarmWarning': 'Android kann Erinnerungen verzögern. Erlaube in den Systemeinstellungen exakte Alarme.',
      'remindersScheduleFailed':
          'Einige Erinnerungen konnten nicht geplant werden.',
      'iosReminderLimit': 'iOS erlaubt 64 ausstehende Erinnerungen. Öffne Sometime, um weitere Erinnerungen zu planen.',
    },
    'es': {
      'settings': 'Ajustes',
      'appIcon': 'Icono de Sometime',
      'appDescription':
          'Un lugar más tranquilo para lo que importa hoy, pronto o algún día.',
      'whyBuilt': 'Por qué creé Sometime',
      'whyBuiltBody': 'Hola 👋 Soy Eik y creé Sometime mientras estudiaba porque la mayoría de las aplicaciones de tareas mezclaban lo que tenía que hacer hoy con cosas que quizá quisiera hacer dentro de semanas o meses.\n\nSometime separa esos horizontes de tiempo sin añadir proyectos, etiquetas ni más organización.',
      'offlineFirst': 'Funciona sin conexión',
      'adFree': 'Sin anuncios',
      'openSource': 'Código abierto',
      'noAccount': 'Sin cuenta',
      'experience': 'Apariencia',
      'notifications': 'Notificaciones',
      'language': 'Idioma',
      'dataPrivacy': 'Datos y privacidad',
      'exportData': 'Exportar datos',
      'importData': 'Importar datos',
      'importQuestion': '¿Importar copia de Sometime?',
      'importExplanation':
          'Esto reemplazará los datos guardados en este dispositivo.',
      'importAction': 'Importar',
      'transferError': 'No se pudo procesar el archivo. Comprueba el formato e inténtalo de nuevo.',
      'transferSuccess': 'Listo',
      'saveCard': 'Guardar tarjeta de miembro',
      'displayName': 'Nombre visible',
      'haptics': 'Vibración',
      'morningReminder': 'Hora del recordatorio matutino',
      'notificationSettings': 'Ajustes de notificaciones',
      'storage': 'ALMACENAMIENTO',
      'onDevice': 'En este dispositivo',
      'deleteAll': 'Eliminar todos los datos',
      'about': 'SOBRE SOMETIME',
      'madeBy': 'Creado por {name}',
      'sourceCode': 'Código fuente',
      'privacyPolicy': 'Política de privacidad',
      'licenses': 'Licencias de código abierto',
      'version': 'Versión',
      'support': 'Apoya a Sometime',
      'supporterThanks': 'Gracias por apoyar Sometime',
      'rerollCardDescription':
          'Toca para cambiar el diseño de la tarjeta de apoyo',
      'rerollCardQuestion': '¿Cambiar el diseño de la tarjeta?',
      'rerollCardExplanation':
          'Esto reemplazará el diseño actual de tu tarjeta de apoyo.',
      'reroll': 'Cambiar diseño',
      'supportNote': 'Sometime se desarrolla de forma independiente, sin anuncios y como código abierto.',
      'supportBody': 'Si te gusta Sometime, puedes apoyarme y ayudar a financiar su desarrollo.',
      'becomeSupporter': 'Hazte supporter',
      'restore': 'Restaurar compras',
      'nameQuestion': '¿Cómo debe llamarte Sometime?',
      'welcomeToSometime': 'Te damos la bienvenida a Sometime',
      'onboardingNameQuestion': '¿Cómo te llamamos?',
      'nameHint': 'Nombre',
      'you': 'Tú',
      'continueLabel': 'Continuar',
      'skip': 'Omitir',
      'cancel': 'Cancelar',
      'save': 'Guardar',
      'create': 'Crear',
      'notSet': 'Sin establecer',
      'style': 'Estilo',
      'mode': 'Modo',
      'color': 'Color',
      'customColor': 'Color propio',
      'system': 'Sistema',
      'crisp': 'Nítido',
      'soft': 'Suave',
      'light': 'Claro',
      'dark': 'Oscuro',
      'today': 'Hoy',
      'soon': 'Pronto',
      'sometime': 'Algún día',
      'completed': 'Completado',
      'emptySpace': 'Todo listo :D',
      'title': 'Título',
      'description': 'Descripción',
      'date': 'Fecha',
      'time': 'Hora',
      'reminder': 'Recordatorio',
      'routine': 'Rutina',
      'weekly': 'Semanal',
      'monthly': 'Mensual',
      'yearly': 'Anual',
      'none': 'Ninguno',
      'closeInput': 'Cerrar entrada',
      'newTask': 'Nueva tarea',
      'firstEmptyHomeHint': 'Todavía no hay nada',
      'firstTaskEditTutorialTitle': 'Gestiona tu tarea',
      'firstTaskBodyPin': 'Mantén pulsada una tarea para ver sus controles. Úsalos para moverla, editarla o fijarla.',
      'firstTaskBodyNoPin': 'Mantén pulsada una tarea para ver sus controles. Úsalos para moverla o editarla.',
      'spaceManagementTutorialTitle': 'Gestiona los Spaces',
      'spaceManagementTutorialBody': 'Mantén pulsado un Space para crear, cambiar el nombre o eliminar Spaces.',
      'move': 'Mover',
      'tutorialPin': 'Fijar',
      'gotIt': 'Entendido',
      'editTask': 'Editar tarea',
      'addTask': 'Añadir tarea',
      'saveChanges': 'Guardar cambios',
      'newSpace': 'Nuevo Space',
      'renameSpace': 'Cambiar nombre',
      'deleteSpace': 'Eliminar Space',
      'deleteSpaceQuestion': '¿Eliminar este Space?',
      'deleteSpaceExplanation':
          'También se eliminarán las tareas de este Space.',
      'undo': 'Deshacer',
      'deletedEntry': 'Elemento eliminado',
      'delete': 'Eliminar',
      'edit': 'Editar',
      'pin': 'Fijar en notificaciones',
      'pinToNotification': 'Fijar en notificaciones',
      'unpin': 'Desfijar',
      'retry': 'Reintentar',
      'loadError': 'No se pudieron cargar las tareas.',
      'deleteQuestion': '¿Eliminar todos los datos?',
      'deleteExplanation': 'Esto elimina las tareas, los Spaces, las rutinas y las preferencias locales de este dispositivo. Las compras se pueden restaurar.',
      'externalLink': '{label}, enlace externo',
      'settingsSaveError': 'No se pudieron guardar los ajustes.',
      'taskSaveError': 'No se pudo guardar la tarea.',
      'maxSpaces': 'Puedes tener hasta 5 Spaces.',
      'openSettings': 'Abrir ajustes',
      'openSpace': 'Abrir {name}',
      'releaseToClose': 'Suelta para cerrar',
      'pinnedToNotifications': 'Fijada en notificaciones',
      'hue': 'Tono',
      'saturation': 'Saturación',
      'brightness': 'Brillo',
      'useColor': 'Usar color',
      'storeConnecting': 'Conectando con App Store…',
      'storeWaiting': 'Esperando a App Store…',
      'supportUnavailable': 'El soporte no está disponible ahora.',
      'purchaseError': 'No se pudo completar la compra.',
      'purchaseCanceled': 'Compra cancelada.',
      'noPurchase': 'No se encontró ninguna compra para restaurar.',
      'supportThankYou': '¡Gracias por apoyar Sometime!',
      'previewSupporterState': 'Vista previa del estado supporter',
      'resetSupporterLocally': 'Restablecer supporter localmente',
      'unlockSupporterLocally': 'Desbloquear supporter localmente',
      'regenerateMembershipCard': 'Regenerar tarjeta de miembro',
      'systemLanguage': 'Sistema',
      'supporterSince': 'Supporter desde {month} de {year}',
      'supporterCardSemantics':
          'Tarjeta de supporter de Sometime para {name}, {date}',
      'notificationsOff':
          'Las notificaciones están desactivadas. Actívalas en Ajustes.',
      'notificationsUnavailable':
          'Las notificaciones no están disponibles. La tarea se guardará.',
      'notificationsUpdateFailed': 'No se pudieron actualizar las notificaciones. Los datos de la tarea se conservan.',
      'exactAlarmWarning': 'Android puede retrasar los recordatorios. Permite alarmas exactas en los ajustes del sistema.',
      'remindersScheduleFailed':
          'No se pudieron programar algunos recordatorios.',
      'iosReminderLimit': 'iOS permite 64 recordatorios pendientes. Abre Sometime para programar más.',
    },
    'pt-BR': {
      'settings': 'Configurações',
      'appIcon': 'Ícone do Sometime',
      'appDescription': 'Um lugar mais tranquilo para o que importa hoje, em breve ou algum dia.',
      'whyBuilt': 'Por que criei o Sometime',
      'whyBuiltBody': 'Olá 👋 Eu sou o Eik e criei o Sometime enquanto estudava, porque a maioria dos aplicativos de tarefas misturava o que eu precisava fazer hoje com coisas que talvez só quisesse fazer semanas ou meses depois.\n\nO Sometime separa esses horizontes de tempo sem adicionar projetos, etiquetas ou mais organização.',
      'offlineFirst': 'Funciona offline',
      'adFree': 'Sem anúncios',
      'openSource': 'Código aberto',
      'noAccount': 'Sem conta',
      'experience': 'Aparência',
      'notifications': 'Notificações',
      'language': 'Idioma',
      'dataPrivacy': 'Dados e privacidade',
      'exportData': 'Exportar dados',
      'importData': 'Importar dados',
      'importQuestion': 'Importar backup do Sometime?',
      'importExplanation':
          'Isso substituirá os dados salvos neste dispositivo.',
      'importAction': 'Importar',
      'transferError': 'Não foi possível processar o arquivo. Verifique o formato e tente novamente.',
      'transferSuccess': 'Concluído',
      'saveCard': 'Salvar cartão de membro',
      'displayName': 'Nome de exibição',
      'haptics': 'Vibração',
      'morningReminder': 'Horário do lembrete da manhã',
      'notificationSettings': 'Configurações de notificações',
      'storage': 'ARMAZENAMENTO',
      'onDevice': 'Neste dispositivo',
      'deleteAll': 'Excluir todos os dados',
      'about': 'SOBRE O SOMETIME',
      'madeBy': 'Feito por {name}',
      'sourceCode': 'Código-fonte',
      'privacyPolicy': 'Política de privacidade',
      'licenses': 'Licenças de código aberto',
      'version': 'Versão',
      'support': 'Apoie o Sometime',
      'supporterThanks': 'Obrigado por apoiar o Sometime',
      'rerollCardDescription':
          'Toque para sortear outro design do cartão de apoiador',
      'rerollCardQuestion': 'Sortear outro design?',
      'rerollCardExplanation':
          'Isso substituirá o design atual do seu cartão de apoiador.',
      'reroll': 'Sortear novamente',
      'supportNote': 'O Sometime é desenvolvido de forma independente, sem anúncios e como código aberto.',
      'supportBody': 'Se você gosta do Sometime, pode me apoiar e ajudar a financiar seu desenvolvimento.',
      'becomeSupporter': 'Seja um apoiador',
      'restore': 'Restaurar compras',
      'nameQuestion': 'Como o Sometime deve chamar você?',
      'welcomeToSometime': 'Boas-vindas ao Sometime',
      'onboardingNameQuestion': 'Como devemos chamar você?',
      'nameHint': 'Nome',
      'you': 'Você',
      'continueLabel': 'Continuar',
      'skip': 'Pular',
      'cancel': 'Cancelar',
      'save': 'Salvar',
      'create': 'Criar',
      'notSet': 'Não definido',
      'style': 'Estilo',
      'mode': 'Modo',
      'color': 'Cor',
      'customColor': 'Cor própria',
      'system': 'Sistema',
      'crisp': 'Nítido',
      'soft': 'Suave',
      'light': 'Claro',
      'dark': 'Escuro',
      'today': 'Hoje',
      'soon': 'Em breve',
      'sometime': 'Algum dia',
      'completed': 'Concluído',
      'emptySpace': 'Está tudo feito :D',
      'title': 'Título',
      'description': 'Descrição',
      'date': 'Data',
      'time': 'Hora',
      'reminder': 'Lembrete',
      'routine': 'Rotina',
      'weekly': 'Semanal',
      'monthly': 'Mensal',
      'yearly': 'Anual',
      'none': 'Nenhum',
      'closeInput': 'Fechar entrada',
      'newTask': 'Nova tarefa',
      'firstEmptyHomeHint': 'Ainda não há nada aqui',
      'firstTaskEditTutorialTitle': 'Gerencie sua tarefa',
      'firstTaskBodyPin': 'Pressione e segure uma tarefa para ver os controles. Use-os para mover, editar ou fixar a tarefa.',
      'firstTaskBodyNoPin': 'Pressione e segure uma tarefa para ver os controles. Use-os para mover ou editar a tarefa.',
      'spaceManagementTutorialTitle': 'Gerencie os Spaces',
      'spaceManagementTutorialBody':
          'Pressione e segure um Space para criar, renomear ou excluir Spaces.',
      'move': 'Mover',
      'tutorialPin': 'Fixar',
      'gotIt': 'Entendi',
      'editTask': 'Editar tarefa',
      'addTask': 'Adicionar tarefa',
      'saveChanges': 'Salvar alterações',
      'newSpace': 'Novo Space',
      'renameSpace': 'Renomear Space',
      'deleteSpace': 'Excluir Space',
      'deleteSpaceQuestion': 'Excluir este Space?',
      'deleteSpaceExplanation':
          'As tarefas deste Space também serão excluídas.',
      'undo': 'Desfazer',
      'deletedEntry': 'Item excluído',
      'delete': 'Excluir',
      'edit': 'Editar',
      'pin': 'Fixar nas notificações',
      'pinToNotification': 'Fixar nas notificações',
      'unpin': 'Desafixar',
      'retry': 'Tentar novamente',
      'loadError': 'Não foi possível carregar as tarefas.',
      'deleteQuestion': 'Excluir todos os dados?',
      'deleteExplanation': 'Isso exclui tarefas, Spaces, rotinas e preferências locais deste dispositivo. Uma compra da loja pode ser restaurada.',
      'externalLink': '{label}, link externo',
      'settingsSaveError': 'Não foi possível salvar as configurações.',
      'taskSaveError': 'Não foi possível salvar a tarefa.',
      'maxSpaces': 'Você pode ter até 5 Spaces.',
      'openSettings': 'Abrir configurações',
      'openSpace': 'Abrir {name}',
      'releaseToClose': 'Solte para fechar',
      'pinnedToNotifications': 'Fixada nas notificações',
      'hue': 'Matiz',
      'saturation': 'Saturação',
      'brightness': 'Brilho',
      'useColor': 'Usar cor',
      'storeConnecting': 'Conectando à App Store…',
      'storeWaiting': 'Aguardando a App Store…',
      'supportUnavailable': 'O suporte não está disponível agora.',
      'purchaseError': 'Não foi possível concluir a compra.',
      'purchaseCanceled': 'Compra cancelada.',
      'noPurchase': 'Nenhuma compra para restaurar foi encontrada.',
      'supportThankYou': 'Obrigado por apoiar o Sometime!',
      'previewSupporterState': 'Visualizar estado de apoiador',
      'resetSupporterLocally': 'Redefinir apoiador localmente',
      'unlockSupporterLocally': 'Desbloquear apoiador localmente',
      'regenerateMembershipCard': 'Regenerar cartão de membro',
      'systemLanguage': 'Sistema',
      'supporterSince': 'Apoiador desde {month} de {year}',
      'supporterCardSemantics':
          'Cartão de apoiador do Sometime para {name}, {date}',
      'notificationsOff':
          'As notificações estão desativadas. Ative-as em Configurações.',
      'notificationsUnavailable':
          'As notificações não estão disponíveis. A tarefa ainda será salva.',
      'notificationsUpdateFailed': 'Não foi possível atualizar as notificações. Os dados da tarefa foram mantidos.',
      'exactAlarmWarning': 'O Android pode atrasar lembretes. Permita alarmes exatos nas configurações do sistema.',
      'remindersScheduleFailed': 'Não foi possível agendar alguns lembretes.',
      'iosReminderLimit': 'O iOS permite 64 lembretes pendentes. Abra o Sometime para agendar mais lembretes.',
    },
    'fr': {
      'settings': 'Réglages',
      'appIcon': 'Icône de Sometime',
      'appDescription': 'Un endroit plus calme pour ce qui compte aujourd’hui, bientôt ou un jour.',
      'whyBuilt': "Pourquoi j'ai créé Sometime",
      'whyBuiltBody': "Bonjour 👋 Je m'appelle Eik et j'ai créé Sometime pendant mes études, car la plupart des applications de tâches mélangeaient ce que je devais faire aujourd'hui avec des choses qui pourraient attendre des semaines ou des mois.\n\nSometime sépare ces horizons temporels sans ajouter de projets, d'étiquettes ni d'organisation superflue.",
      'offlineFirst': 'Hors ligne d’abord',
      'adFree': 'Sans publicité',
      'openSource': 'Open source',
      'noAccount': 'Aucun compte requis',
      'experience': 'Apparence',
      'notifications': 'Notifications',
      'language': 'Langue',
      'dataPrivacy': 'Données et confidentialité',
      'exportData': 'Exporter les données',
      'importData': 'Importer les données',
      'importQuestion': 'Importer une sauvegarde Sometime ?',
      'importExplanation': 'Les données actuellement stockées sur cet appareil seront remplacées.',
      'importAction': 'Importer',
      'transferError': 'Le fichier n’a pas pu être traité. Vérifiez son format et réessayez.',
      'transferSuccess': 'Terminé',
      'saveCard': 'Enregistrer la carte de membre',
      'displayName': 'Nom affiché',
      'haptics': 'Retour tactile',
      'morningReminder': 'Heure du rappel du matin',
      'notificationSettings': 'Réglages des notifications',
      'storage': 'STOCKAGE',
      'onDevice': 'Sur cet appareil',
      'deleteAll': 'Supprimer toutes les données',
      'about': 'À PROPOS DE SOMETIME',
      'madeBy': 'Créé par {name}',
      'sourceCode': 'Code source',
      'privacyPolicy': 'Politique de confidentialité',
      'licenses': 'Licences open source',
      'version': 'Version',
      'support': 'Soutenir Sometime',
      'supporterThanks': 'Merci de soutenir Sometime',
      'rerollCardDescription':
          'Touchez pour changer le design de la carte de soutien',
      'rerollCardQuestion': 'Changer le design de la carte ?',
      'rerollCardExplanation':
          'Le design actuel de votre carte de soutien sera remplacé.',
      'reroll': 'Changer le design',
      'supportNote': 'Sometime est développé indépendamment, sans publicité et en open source.',
      'supportBody': 'Si Sometime vous plaît, vous pouvez me soutenir et contribuer à son développement.',
      'becomeSupporter': 'Devenir soutien',
      'restore': 'Restaurer les achats',
      'nameQuestion': 'Comment Sometime doit-il vous appeler ?',
      'welcomeToSometime': 'Bienvenue sur Sometime',
      'onboardingNameQuestion': 'Comment devons-nous vous appeler ?',
      'nameHint': 'Nom',
      'you': 'Vous',
      'continueLabel': 'Continuer',
      'skip': 'Passer',
      'cancel': 'Annuler',
      'save': 'Enregistrer',
      'create': 'Créer',
      'notSet': 'Non défini',
      'style': 'Style',
      'mode': 'Mode',
      'color': 'Couleur',
      'customColor': 'Couleur personnalisée',
      'system': 'Système',
      'crisp': 'Net',
      'soft': 'Doux',
      'light': 'Clair',
      'dark': 'Sombre',
      'today': "Aujourd'hui",
      'soon': 'Bientôt',
      'sometime': 'Un jour',
      'completed': 'Terminé',
      'emptySpace': 'Tout est fait :D',
      'title': 'Titre',
      'description': 'Description',
      'date': 'Date',
      'time': 'Heure',
      'reminder': 'Rappel',
      'routine': 'Routine',
      'weekly': 'Chaque semaine',
      'monthly': 'Chaque mois',
      'yearly': 'Chaque année',
      'none': 'Aucun',
      'closeInput': 'Fermer la saisie',
      'newTask': 'Nouvelle tâche',
      'firstEmptyHomeHint': 'Rien ici pour le moment',
      'firstTaskEditTutorialTitle': 'Gérer votre tâche',
      'firstTaskBodyPin': 'Maintenez une tâche pour afficher ses commandes. Utilisez-les pour la déplacer, la modifier ou l’épingler.',
      'firstTaskBodyNoPin': 'Maintenez une tâche pour afficher ses commandes. Utilisez-les pour la déplacer ou la modifier.',
      'spaceManagementTutorialTitle': 'Gérer les Spaces',
      'spaceManagementTutorialBody':
          'Maintenez un Space pour créer, renommer ou supprimer des Spaces.',
      'move': 'Déplacer',
      'tutorialPin': 'Épingler',
      'gotIt': 'Compris',
      'editTask': 'Modifier la tâche',
      'addTask': 'Ajouter une tâche',
      'saveChanges': 'Enregistrer les modifications',
      'newSpace': 'Nouveau Space',
      'renameSpace': 'Renommer le Space',
      'deleteSpace': 'Supprimer le Space',
      'deleteSpaceQuestion': 'Supprimer ce Space ?',
      'deleteSpaceExplanation':
          'Les tâches de ce Space seront aussi supprimées.',
      'undo': 'Annuler',
      'deletedEntry': 'Élément supprimé',
      'delete': 'Supprimer',
      'edit': 'Modifier',
      'pin': 'Épingler aux notifications',
      'pinToNotification': 'Épingler aux notifications',
      'unpin': 'Désépingler',
      'retry': 'Réessayer',
      'loadError': 'Impossible de charger les tâches.',
      'deleteQuestion': 'Supprimer toutes les données ?',
      'deleteExplanation': 'Cette action supprime les tâches, les Spaces, les routines et les préférences locales de cet appareil. Un achat peut être restauré.',
      'externalLink': '{label}, lien externe',
      'settingsSaveError': 'Impossible d’enregistrer les réglages.',
      'taskSaveError': 'Impossible d’enregistrer la tâche.',
      'maxSpaces': 'Vous pouvez avoir jusqu’à 5 Spaces.',
      'openSettings': 'Ouvrir les réglages',
      'openSpace': 'Ouvrir {name}',
      'releaseToClose': 'Relâchez pour fermer',
      'pinnedToNotifications': 'Épinglée aux notifications',
      'hue': 'Teinte',
      'saturation': 'Saturation',
      'brightness': 'Luminosité',
      'useColor': 'Utiliser la couleur',
      'storeConnecting': 'Connexion à l’App Store…',
      'storeWaiting': 'En attente de l’App Store…',
      'supportUnavailable': 'Le soutien est indisponible pour le moment.',
      'purchaseError': 'L’achat n’a pas pu être effectué.',
      'purchaseCanceled': 'Achat annulé.',
      'noPurchase': 'Aucun achat à restaurer trouvé.',
      'supportThankYou': 'Merci de soutenir Sometime !',
      'previewSupporterState': 'Prévisualiser le statut de soutien',
      'resetSupporterLocally': 'Réinitialiser le soutien localement',
      'unlockSupporterLocally': 'Déverrouiller le soutien localement',
      'regenerateMembershipCard': 'Régénérer la carte de membre',
      'systemLanguage': 'Système',
      'supporterSince': 'Soutien depuis {month} {year}',
      'supporterCardSemantics': 'Carte de soutien Sometime pour {name}, {date}',
      'notificationsOff':
          'Les notifications sont désactivées. Activez-les dans les réglages.',
      'notificationsUnavailable': 'Les notifications sont indisponibles. La tâche sera tout de même enregistrée.',
      'notificationsUpdateFailed': 'Impossible de mettre à jour les notifications. Les données de la tâche sont conservées.',
      'exactAlarmWarning': 'Android peut retarder les rappels. Autorisez les alarmes exactes dans les réglages système.',
      'remindersScheduleFailed':
          'Certains rappels n’ont pas pu être programmés.',
      'iosReminderLimit': 'iOS autorise 64 rappels en attente. Ouvrez Sometime pour en programmer d’autres.',
    },
    'ja': {
      'settings': '設定',
      'appIcon': 'Sometimeのアプリアイコン',
      'appDescription': '今日、すぐに、いつか大切になることを、もっと落ち着いて管理できます。',
      'whyBuilt': 'Sometimeを作った理由',
      'whyBuiltBody': 'こんにちは 👋 Eikです。学生の頃、ほとんどのToDoアプリが今日やることと、数週間後や数か月後にやりたいことを混ぜていたので、Sometimeを作りました。\n\nSometimeは、プロジェクトやタグなどの余分な整理を増やさずに、時間軸を分けて管理できます。',
      'offlineFirst': 'オフライン優先',
      'adFree': '広告なし',
      'openSource': 'オープンソース',
      'noAccount': 'アカウント不要',
      'experience': '表示',
      'notifications': '通知',
      'language': '言語',
      'dataPrivacy': 'データとプライバシー',
      'exportData': 'データを書き出す',
      'importData': 'データを読み込む',
      'importQuestion': 'Sometimeのバックアップを読み込みますか？',
      'importExplanation': 'この端末に保存されているデータは置き換えられます。',
      'importAction': '読み込む',
      'transferError': 'ファイルを処理できませんでした。形式を確認して、もう一度お試しください。',
      'transferSuccess': '完了',
      'saveCard': 'メンバーカードを保存',
      'displayName': '表示名',
      'haptics': '触覚フィードバック',
      'morningReminder': '朝のリマインダー時刻',
      'notificationSettings': '通知設定',
      'storage': 'ストレージ',
      'onDevice': 'この端末',
      'deleteAll': 'すべてのデータを削除',
      'about': 'SOMETIMEについて',
      'madeBy': '{name}が開発',
      'sourceCode': 'ソースコード',
      'privacyPolicy': 'プライバシーポリシー',
      'licenses': 'オープンソースライセンス',
      'version': 'バージョン',
      'support': 'Sometimeを支援',
      'supporterThanks': 'Sometimeを支援していただきありがとうございます',
      'rerollCardDescription': 'タップしてサポーターカードのデザインを変更',
      'rerollCardQuestion': 'カードのデザインを変更しますか？',
      'rerollCardExplanation': '現在のサポーターカードのデザインは置き換えられます。',
      'reroll': 'デザインを変更',
      'supportNote': 'Sometimeは独立して開発している、広告のないオープンソースアプリです。',
      'supportBody': 'Sometimeを気に入っていただけたら、支援して開発を助けてください。',
      'becomeSupporter': '支援する',
      'restore': '購入を復元',
      'nameQuestion': 'Sometimeでは何とお呼びすればよいですか？',
      'welcomeToSometime': 'Sometimeへようこそ',
      'onboardingNameQuestion': 'お名前を教えてください',
      'nameHint': '名前',
      'you': 'あなた',
      'continueLabel': '続ける',
      'skip': 'スキップ',
      'cancel': 'キャンセル',
      'save': '保存',
      'create': '作成',
      'notSet': '未設定',
      'style': 'スタイル',
      'mode': 'モード',
      'color': '色',
      'customColor': 'カスタムカラー',
      'system': 'システム',
      'crisp': 'くっきり',
      'soft': 'ソフト',
      'light': 'ライト',
      'dark': 'ダーク',
      'today': '今日',
      'soon': 'すぐに',
      'sometime': 'いつか',
      'completed': '完了',
      'emptySpace': 'すべて完了 :D',
      'title': 'タイトル',
      'description': '説明',
      'date': '日付',
      'time': '時刻',
      'reminder': 'リマインダー',
      'routine': 'ルーティン',
      'weekly': '毎週',
      'monthly': '毎月',
      'yearly': '毎年',
      'none': 'なし',
      'closeInput': '入力を閉じる',
      'newTask': '新しいタスク',
      'firstEmptyHomeHint': 'まだ何もありません',
      'firstTaskEditTutorialTitle': 'タスクを管理',
      'firstTaskBodyPin': 'タスクを長押しすると操作ボタンが表示されます。移動、編集、ピン留めに使えます。',
      'firstTaskBodyNoPin': 'タスクを長押しすると操作ボタンが表示されます。移動や編集に使えます。',
      'spaceManagementTutorialTitle': 'Spaceを管理',
      'spaceManagementTutorialBody': 'Spaceを長押しすると、Spaceの作成、名前変更、削除ができます。',
      'move': '移動',
      'tutorialPin': 'ピン留め',
      'gotIt': 'わかりました',
      'editTask': 'タスクを編集',
      'addTask': 'タスクを追加',
      'saveChanges': '変更を保存',
      'newSpace': '新しいSpace',
      'renameSpace': 'Spaceの名前を変更',
      'deleteSpace': 'Spaceを削除',
      'deleteSpaceQuestion': 'このSpaceを削除しますか？',
      'deleteSpaceExplanation': 'このSpaceのタスクも削除されます。',
      'undo': '元に戻す',
      'deletedEntry': '項目を削除しました',
      'delete': '削除',
      'edit': '編集',
      'pin': '通知にピン留め',
      'pinToNotification': '通知にピン留め',
      'unpin': 'ピン留めを解除',
      'retry': 'もう一度試す',
      'loadError': 'タスクを読み込めませんでした。',
      'deleteQuestion': 'すべてのデータを削除しますか？',
      'deleteExplanation': 'この端末のタスク、Space、ルーティン、ローカル設定を削除します。購入は復元できます。',
      'externalLink': '{label}、外部リンク',
      'settingsSaveError': '設定を保存できませんでした。',
      'taskSaveError': 'タスクを保存できませんでした。',
      'maxSpaces': 'Spaceは最大5個までです。',
      'openSettings': '設定を開く',
      'openSpace': '{name}を開く',
      'releaseToClose': '閉じるには指を離す',
      'pinnedToNotifications': '通知にピン留め済み',
      'hue': '色相',
      'saturation': '彩度',
      'brightness': '明るさ',
      'useColor': 'この色を使う',
      'storeConnecting': 'App Storeに接続しています…',
      'storeWaiting': 'App Storeを待っています…',
      'supportUnavailable': '現在サポートを利用できません。',
      'purchaseError': '購入を完了できませんでした。',
      'purchaseCanceled': '購入をキャンセルしました。',
      'noPurchase': '復元できる購入が見つかりません。',
      'supportThankYou': 'Sometimeを支援していただきありがとうございます！',
      'previewSupporterState': 'サポーター状態をプレビュー',
      'resetSupporterLocally': 'サポーター状態を端末でリセット',
      'unlockSupporterLocally': 'サポーター状態を端末で解除',
      'regenerateMembershipCard': 'メンバーカードを再生成',
      'systemLanguage': 'システム',
      'supporterSince': '{year}年{month}からサポーター',
      'supporterCardSemantics': '{name}さんのSometimeサポーターカード、{date}',
      'notificationsOff': '通知がオフです。設定で有効にしてください。',
      'notificationsUnavailable': '通知を利用できません。タスクは保存されます。',
      'notificationsUpdateFailed': '通知を更新できませんでした。タスクデータは保持されます。',
      'exactAlarmWarning':
          'Androidではリマインダーが遅れることがあります。システム設定で正確なアラームを許可してください。',
      'remindersScheduleFailed': '一部のリマインダーを設定できませんでした。',
      'iosReminderLimit': 'iOSでは保留中のリマインダーを64件まで設定できます。Sometimeを開いて追加してください。',
    },
  };

  static const _reminders = <String, List<String>>{
    'en': [
      'None',
      'At time',
      '10 min before',
      '30 min before',
      '1 hour before',
      '1 day before',
      'Morning of',
      '2 days before',
      '1 week before',
    ],
    'de': [
      'Keine',
      'Zur Uhrzeit',
      '10 Min. vorher',
      '30 Min. vorher',
      '1 Std. vorher',
      '1 Tag vorher',
      'Am Morgen',
      '2 Tage vorher',
      '1 Woche vorher',
    ],
    'es': [
      'Ninguno',
      'A la hora',
      '10 min antes',
      '30 min antes',
      '1 hora antes',
      '1 día antes',
      'Por la mañana',
      '2 días antes',
      '1 semana antes',
    ],
    'pt-BR': [
      'Nenhum',
      'No horário',
      '10 min antes',
      '30 min antes',
      '1 hora antes',
      '1 dia antes',
      'Na manhã do dia',
      '2 dias antes',
      '1 semana antes',
    ],
    'fr': [
      'Aucun',
      'À l’heure',
      '10 min avant',
      '30 min avant',
      '1 h avant',
      '1 jour avant',
      'Le matin même',
      '2 jours avant',
      '1 semaine avant',
    ],
    'ja': ['なし', '時刻どおり', '10分前', '30分前', '1時間前', '1日前', '当日の朝', '2日前', '1週間前'],
  };

  static const _weekdays = <String, List<String>>{
    'en': ['M', 'T', 'W', 'T', 'F', 'S', 'S'],
    'de': ['M', 'D', 'M', 'D', 'F', 'S', 'S'],
    'es': ['L', 'M', 'X', 'J', 'V', 'S', 'D'],
    'pt-BR': ['S', 'T', 'Q', 'Q', 'S', 'S', 'D'],
    'fr': ['L', 'M', 'M', 'J', 'V', 'S', 'D'],
    'ja': ['月', '火', '水', '木', '金', '土', '日'],
  };
}

extension AppStringsContext on BuildContext {
  AppStrings get strings => AppStrings.of(this);
}
