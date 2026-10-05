// User-facing strings, English and French. Pure Dart (also used by models,
// services and the report formatter).

enum AppLang {
  en,
  fr;

  /// `fr`, `fr_FR`, `fr-CA`… → French; anything else → English.
  static AppLang fromLocale(String? locale) =>
      (locale ?? '').toLowerCase().startsWith('fr') ? fr : en;
}

/// Active language. Set by AppController; isolates receive it explicitly.
abstract final class L10n {
  static AppLang lang = AppLang.en;
  static Strings get s => Strings(lang);
}

/// Shorthand for the active strings.
Strings get tr => L10n.s;

class Strings {
  const Strings(this.lang);

  final AppLang lang;
  bool get _fr => lang == AppLang.fr;
  String _(String en, String fr) => _fr ? fr : en;

  // ---------------------------------------------------------------- general
  String plural(int n, String en, String fr, {String? enMany, String? frMany}) {
    final many = n > 1 || (n == 0 && !_fr);
    final word = _fr
        ? (many ? (frMany ?? '${fr}s') : fr)
        : (many ? (enMany ?? '${en}s') : en);
    return '$n $word';
  }

  String files(int n) => plural(n, 'file', 'fichier');
  String panics(int n) => plural(n, 'panic', 'panic');
  String kernelPanics(int n) =>
      plural(n, 'kernel panic', 'kernel panic', frMany: 'kernel panics');
  String diagnosticFiles(int n) => plural(
    n,
    'diagnostic file',
    'fichier de diagnostic',
    frMany: 'fichiers de diagnostic',
  );

  // ------------------------------------------------------------------ dates
  List<String> get months => _fr
      ? const [
          'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin',
          'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.', //
        ]
      : const [
          'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
          'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec', //
        ];
  String today(String time) => _('Today, $time', 'Aujourd’hui, $time');
  String yesterday(String time) => _('Yesterday, $time', 'Hier, $time');
  String todayShort(String time) => _('today $time', 'aujourd’hui $time');
  String get yesterdayShort => _('yesterday', 'hier');
  String get unknownDate => _('Unknown date', 'Date inconnue');

  // ---------------------------------------------------------------- sidebar
  String get overview => _('Overview', 'Vue d’ensemble');
  String get panicsSection => 'Panics';
  String get filesSection => _('Files', 'Fichiers');
  String get general => _('General', 'Général');
  String get openIps => _('Open .ips…', 'Ouvrir un .ips…');
  String get back => _('Back', 'Retour');

  // --------------------------------------------------------- device states
  String get lookingForDevices =>
      _('Looking for devices…', 'Recherche d’appareils…');
  String get noIPhone => _('No iPhone connected', 'Aucun iPhone connecté');
  String get noIPhoneHelp => _(
    'Connect an iPhone using USB, unlock it and tap “Trust” if asked. iPanicX checks again every few seconds.',
    'Branchez un iPhone en USB, déverrouillez-le et touchez « Se fier » si demandé. iPanicX revérifie automatiquement toutes les deux secondes.',
  );
  String get notDetectedSection => _(
    'iPhone plugged in but not detected?',
    'iPhone branché mais pas détecté ?',
  );
  String get cableTips => _(
    '• Use a data cable: some cables only charge.\n• Unlock the iPhone. A locked iPhone may refuse new USB connections.',
    '• Utilisez un câble de données : certains câbles ne font que charger.\n• Déverrouillez l’iPhone. Verrouillé, il peut refuser une nouvelle connexion USB.',
  );
  String get notRecognized => _('iPhone not recognized', 'iPhone non reconnu');
  String get timeoutHelp => _(
    'The iPhone did not answer in time. Keep it unlocked and try again.',
    'L’iPhone n’a pas répondu à temps. Gardez-le déverrouillé et réessayez.',
  );
  String get scanFailedGeneric => _(
    'Something went wrong while reading the crash reports.',
    'Une erreur est survenue pendant la lecture des rapports.',
  );
  String get trustRequired => _('Trust required', 'Autorisation requise');
  String trustHelp(String computer) => _(
    'Unlock your iPhone and tap “Trust” to allow this $computer to read diagnostics.',
    'Déverrouillez l’iPhone et touchez « Se fier » pour autoriser ce $computer à lire les diagnostics.',
  );
  String get pairingDenied => _(
    'Pairing was declined on the iPhone. Unplug and reconnect it, then tap “Trust”.',
    'L’association a été refusée sur l’iPhone. Débranchez-le, rebranchez-le, puis touchez « Se fier ».',
  );
  String get showTrustPrompt => _('Show Trust Prompt', 'Afficher la demande');
  String get retry => _('Retry', 'Réessayer');
  String get deviceLocked => _('Device locked', 'Appareil verrouillé');
  String get lockedHelp => _(
    'Unlock your iPhone with its passcode, then try again.',
    'Déverrouillez l’iPhone avec son code, puis réessayez.',
  );
  String get commError => _(
    'Unable to communicate with iPhone',
    'Impossible de communiquer avec l’iPhone',
  );
  String get commHelp => _(
    'The iPhone did not respond correctly.\nTry another cable or USB port, and make sure the iPhone is unlocked.',
    'L’iPhone n’a pas répondu correctement.\nEssayez un autre câble ou port USB, et vérifiez que l’iPhone est déverrouillé.',
  );
  String get toolsUnavailable =>
      _('libimobiledevice unavailable', 'libimobiledevice introuvable');
  String get checkAgain => _('Check Again', 'Vérifier à nouveau');
  String multipleDevices(int n) => _(
    '$n devices are connected. iPanicX is showing the first one. Disconnect the others to choose a device.',
    '$n appareils sont connectés. iPanicX affiche le premier. Débranchez les autres pour choisir un appareil.',
  );
  String get technicalDetails => _('Technical details', 'Détails techniques');
  String get copy => _('Copy', 'Copier');
  String get copied => _('Copied', 'Copié');

  // --------------------------------------------------------------- overview
  String get connectedViaUsb => _('Connected via USB', 'Connecté en USB');
  String get model => _('Model', 'Modèle');
  String get productType => _('Product type', 'Identifiant');
  String get build => 'Build';
  String get diagnostics => _('Diagnostics', 'Diagnostics');
  String get scanDiagnostics =>
      _('Scan diagnostics', 'Analyser les diagnostics');
  String scanHint(String computer) => _(
    'Copies the crash reports to this $computer. They stay on the iPhone.',
    'Copie les rapports sur ce $computer. Ils restent sur l’iPhone.',
  );
  String get scanButton => _('Scan Diagnostics', 'Analyser');
  String get scanAgain => _('Scan Again', 'Relancer');
  String get analyzing => _('Analyzing…', 'Analyse…');
  String get copying => _('Copying…', 'Copie…');
  String copyingFiles(int n) => _('Copying… ${files(n)}', 'Copie… ${files(n)}');
  String get kernelPanicsSection => _('Kernel Panics', 'Kernel panics');
  String get noPanicReports =>
      _('No panic reports found', 'Aucun rapport de panic trouvé');
  String noPanicReportsHint(int n) => _(
    '${diagnosticFiles(n)} copied, none of them is a kernel panic report.',
    '${diagnosticFiles(n)} copiés, aucun n’est un rapport de kernel panic.',
  );
  String get showFiles => _('Show Files', 'Voir les fichiers');
  String get deviceHealth => _('Device Health', 'État de l’appareil');
  String get kernelPanicsLabel => 'Kernel panics';
  String get mostCommon => _('Most common', 'Le plus fréquent');
  String get latest => _('Latest', 'Dernier');
  String get forcedRestarts => _('Forced restarts', 'Redémarrages forcés');
  String get latestReport => _('Latest report', 'Dernier rapport');
  String get analyze => _('Analyze', 'Analyser');
  String get recent => _('Recent', 'Récents');
  String showAll(int n) => _('Show all $n', 'Tout afficher ($n)');

  // ----------------------------------------------------------------- panics
  String get forcedRestartsSection =>
      _('Forced Restarts', 'Redémarrages forcés');
  String get noScanYet => _('No scan yet', 'Aucune analyse');
  String get noScanHint => _(
    'Scan the connected iPhone from Overview.',
    'Analysez l’iPhone connecté depuis la vue d’ensemble.',
  );

  // ------------------------------------------------------------------ files
  String copiedAt(String when) => _('Copied $when', 'Copiés $when');
  String andMore(int n) => _('…and $n more', '…et $n de plus');

  // ------------------------------------------------------------ panic pane
  String get severity => _('Severity', 'Gravité');
  String get confidence => _('Confidence', 'Confiance');
  String get suspectedComponents =>
      _('Suspected components', 'Composants suspectés');
  String get possibleCauses => _('Possible causes', 'Causes possibles');
  String get recommendedActions =>
      _('Recommended actions', 'Actions recommandées');
  String get nextSteps => _('Next steps', 'Étapes suivantes');
  String get device => _('Device', 'Appareil');
  String get sensorMask => _('Sensor mask', 'Masque capteur');
  String get smcKeys => _('SMC keys', 'Clés SMC');
  String get missingSensors => _('Missing sensors', 'Capteurs manquants');
  String get panic => 'Panic';
  String get initiator => _('Initiator', 'Origine');
  String get panickedTask => _('Panicked task', 'Tâche en panic');
  String get kexts => _('Kexts in backtrace', 'Kexts dans la backtrace');
  String get panicFlags => _('Panic flags', 'Flags de panic');
  String get bugType => _('Bug type', 'Type (bug_type)');
  String get kernel => _('Kernel', 'Noyau');
  String get date => 'Date';
  String get rule => _('Rule', 'Règle');
  String get matchedOn => _('Matched on', 'Reconnu sur');
  String get detectedCodes => _('Detected codes', 'Codes détectés');
  String get parserNotes => _('Parser notes', 'Notes du parser');
  String get panicString => _('Panic string', 'Message de panic');
  String get report => _('Report', 'Rapport');
  String get rawReport => _('Raw report', 'Rapport brut');
  String get viewRaw => _('View Raw Panic', 'Voir le rapport brut');
  String get diagnosis => _('Diagnosis', 'Diagnostic');
  String get diagnosisHint =>
      _('Plain text, as exported', 'Texte brut, comme à l’export');
  String get export => _('Export', 'Exporter');
  String get exportHint => _(
    'Save the diagnosis as a .txt file',
    'Enregistrer le diagnostic en .txt',
  );
  String get exportButton => _('Export Report…', 'Exporter…');
  String get diagnosisCopied => _('Diagnosis copied', 'Diagnostic copié');
  String get panicStringCopied =>
      _('Panic string copied', 'Message de panic copié');
  String get rawCopied => _('Raw panic copied', 'Rapport brut copié');
  String savedTo(String path) => _('Saved to $path', 'Enregistré : $path');
  String get copyAll => _('Copy All', 'Tout copier');
  String showingFirst(String shown, String total) => _(
    'Showing the first $shown of $total. Copy All copies everything.',
    'Affichage des premiers $shown sur $total. « Tout copier » copie tout.',
  );
  String get fileUnreadable =>
      _('This file could not be read.', 'Ce fichier n’a pas pu être lu.');

  // --------------------------------------------------------------- general
  String get appearance => _('Appearance', 'Apparence');
  String get system => _('System', 'Système');
  String get light => _('Light', 'Clair');
  String get dark => _('Dark', 'Sombre');
  String get language => _('Language', 'Langue');
  String get english => 'English';
  String get french => 'Français';
  String get simulatedDevice => _('Simulated device', 'Appareil simulé');
  String get scenario => _('Scenario', 'Scénario');
  String get mockOn => _('USE_MOCK_DEVICE is on', 'USE_MOCK_DEVICE est activé');
  String get privacy => _('Privacy', 'Confidentialité');
  String localOnly(String computer) => _(
    'All diagnostic processing is performed locally on your $computer.',
    'Tous les diagnostics sont traités localement sur votre $computer.',
  );
  String privacyDetail(String computer) => _(
    'No analytics, no telemetry, no network requests. Crash reports are copied to a temporary folder on this $computer and never uploaded.',
    'Aucune statistique, aucune télémétrie, aucune requête réseau. Les rapports sont copiés dans un dossier temporaire de ce $computer et ne sont jamais envoyés.',
  );
  String get about => _('About', 'À propos');
  String get version => 'Version 0.1.2';
  String get knowledgeBase => _('Knowledge base', 'Base de connaissances');
  String signatures(int n) => plural(n, 'signature', 'signature');
  String get kbDisclaimer => _(
    'The signatures are examples and do not cover every panic. A diagnosis should be confirmed by hardware inspection.',
    'Les signatures sont des exemples et ne couvrent pas tous les panics. Un diagnostic doit être confirmé par une inspection matérielle.',
  );
  String get deviceBackend => _('Device backend', 'Accès à l’appareil');
  String get notFound => _('not found', 'introuvable');

  // ------------------------------------------------------- model labels
  String severityLabel(String key) => switch (key) {
    'low' => _('Low', 'Faible'),
    'medium' => _('Medium', 'Moyenne'),
    'high' => _('High', 'Élevée'),
    _ => _('Unknown', 'Inconnue'),
  };
  String confidenceLabel(String key) => switch (key) {
    'low' => _('Low confidence', 'Confiance faible'),
    'medium' => _('Medium confidence', 'Confiance moyenne'),
    'high' => _('High confidence', 'Confiance élevée'),
    _ => _('No known signature', 'Signature inconnue'),
  };
  String verdictLabel(String key) => switch (key) {
    'noPanics' => _('No kernel panics found', 'Aucun kernel panic trouvé'),
    'hardwareIssueLikely' => _(
      'Hardware issue likely',
      'Problème matériel probable',
    ),
    _ => _('Cause not determined', 'Cause non déterminée'),
  };
  String fileTypeLabel(String key) => switch (key) {
    'panicFull' => _('Kernel panic (full)', 'Kernel panic (complet)'),
    'panicBase' => _('Kernel panic (base)', 'Kernel panic (base)'),
    'jetsamEvent' => _('Jetsam event', 'Événement Jetsam'),
    'forceReset' => _('Forced restart', 'Redémarrage forcé'),
    'resetCounter' => _('Reset counter', 'Compteur de réinitialisations'),
    'stacks' => 'Stackshot',
    _ => _('Other log', 'Autre journal'),
  };
  String errorTitle(String key) => switch (key) {
    'noDevice' => _('No iPhone detected', 'Aucun iPhone détecté'),
    'deviceLocked' => deviceLocked,
    'trustRequired' || 'pairingDenied' => trustRequired,
    'communication' => commError,
    'crashReportsUnavailable' => _(
      'Unable to retrieve crash reports',
      'Impossible de récupérer les rapports',
    ),
    'toolsUnavailable' => toolsUnavailable,
    'cancelled' => _('Scan cancelled', 'Analyse annulée'),
    _ => _(
      'The iPhone did not respond in time',
      'L’iPhone n’a pas répondu à temps',
    ),
  };
  String errorMessage(String key) => switch (key) {
    'noDevice' => _(
      'Connect an iPhone using USB.',
      'Branchez un iPhone en USB.',
    ),
    'deviceLocked' => lockedHelp,
    'trustRequired' => trustHelp(_('computer', 'ordinateur')),
    'pairingDenied' => pairingDenied,
    'crashReportsUnavailable' => _(
      'The iPhone refused to share its crash reports.',
      'L’iPhone a refusé de partager ses rapports.',
    ),
    'toolsUnavailable' => _(
      'The libimobiledevice tools are not installed.',
      'Les outils libimobiledevice ne sont pas installés.',
    ),
    'cancelled' => _(
      'The copy was stopped. Nothing was changed on the iPhone.',
      'La copie a été arrêtée. Rien n’a été modifié sur l’iPhone.',
    ),
    'timeout' => _(
      'Copying took too long. Keep the iPhone unlocked and try again.',
      'La copie a pris trop de temps. Gardez l’iPhone déverrouillé et réessayez.',
    ),
    _ => _(
      'The iPhone is connected but did not respond correctly.',
      'L’iPhone est connecté mais n’a pas répondu correctement.',
    ),
  };
  String bugTypeLabel(String? bugType) => switch (bugType) {
    null => _('Unknown report type', 'Type de rapport inconnu'),
    '210' => 'Kernel panic',
    '151' => _('Forced restart', 'Redémarrage forcé'),
    '109' => _('App crash (legacy format)', 'Crash d’app (ancien format)'),
    '309' => _('App crash', 'Crash d’app'),
    '308' => _(
      'User fault (ExcUserFault)',
      'Erreur utilisateur (ExcUserFault)',
    ),
    '288' => 'Stackshot',
    '298' => _('Jetsam (memory pressure) event', 'Événement Jetsam (mémoire)'),
    '115' => _('Reset counter', 'Compteur de réinitialisations'),
    _ => _(
      'Diagnostic report (bug_type $bugType)',
      'Rapport de diagnostic (bug_type $bugType)',
    ),
  };

  // ------------------------------------------------------------- platform
  String get computerMac => 'Mac';
  String get computerPc => 'PC';
  String get revealInExplorer =>
      _('Show in File Explorer', 'Afficher dans l’Explorateur');
  String get revealInFinder => _('Show in Finder', 'Afficher dans le Finder');
  String get driverHintWindows => _(
    '• Windows needs Apple’s USB driver and the Apple Mobile Device Service: install “Apple Devices” from the Microsoft Store (or iTunes), open it once, then unplug and reconnect the iPhone.',
    '• Windows a besoin du pilote USB d’Apple et du service Apple Mobile Device : installez « Appareils Apple » depuis le Microsoft Store (ou iTunes), ouvrez-le une fois, puis débranchez et rebranchez l’iPhone.',
  );
  String get driverHintMac => _(
    '• Try another USB port or adapter, then unplug and reconnect.',
    '• Essayez un autre port USB ou adaptateur, puis débranchez et rebranchez.',
  );
  String get notRecognizedWindows => _(
    'Windows sees an iPhone on USB, but the Apple Mobile Device Service does not list it. Unlock the iPhone, unplug and reconnect it. If it persists, open “Apple Devices” (or iTunes) once, or restart “Apple Mobile Device Service” in services.msc.',
    'Windows voit un iPhone en USB, mais le service Apple Mobile Device ne le liste pas. Déverrouillez l’iPhone, débranchez-le et rebranchez-le. Si cela persiste, ouvrez une fois « Appareils Apple » (ou iTunes), ou redémarrez « Apple Mobile Device Service » dans services.msc.',
  );
  String get notRecognizedMac => _(
    'macOS sees an iPhone on USB, but usbmuxd does not list it. Unlock the iPhone, then unplug and reconnect it.',
    'macOS voit un iPhone en USB, mais usbmuxd ne le liste pas. Déverrouillez l’iPhone, puis débranchez-le et rebranchez-le.',
  );
  String get driverProblem => _(
    'Windows sees the iPhone, but its Apple USB driver does not start, so neither Apple Devices nor iPanicX can see it. Usually fixed in this order:\n'
        '1. Restart the PC: the driver installed with Apple Devices is often only active after a restart.\n'
        '2. Unlock the iPhone, plug it directly into the PC (no hub) and tap “Trust”.\n'
        '3. Still failing: Device Manager → right-click “Apple Mobile Device USB Composite Device” (or “Apple iPhone”) → Uninstall device (tick “delete the driver” if offered) → unplug and reconnect the iPhone.\n'
        '4. Otherwise: Settings › Windows Update › Advanced options › Optional updates → install the “Apple, Inc.” drivers offered.',
    'Windows voit l’iPhone, mais son pilote USB Apple ne démarre pas : ni Apple Devices ni iPanicX ne peuvent donc le voir. Ça se règle en général dans cet ordre :\n'
        '1. Redémarrez le PC : le pilote installé avec Apple Devices n’est souvent actif qu’après un redémarrage.\n'
        '2. Déverrouillez l’iPhone, branchez-le directement sur le PC (sans hub) et touchez « Se fier ».\n'
        '3. Si ça persiste : Gestionnaire de périphériques → clic droit sur « Apple Mobile Device USB Composite Device » (ou « Apple iPhone ») → Désinstaller l’appareil (cochez « Supprimer le pilote » si proposé) → débranchez et rebranchez l’iPhone.\n'
        '4. Sinon : Paramètres › Windows Update › Options avancées › Mises à jour facultatives → installez les pilotes « Apple, Inc. » proposés.',
  );
  String get openDeviceManager =>
      _('Open Device Manager', 'Gestionnaire de périphériques');
  String get installHintWindows => _(
    'This build of iPanicX does not include the libimobiledevice tools. Rebuild it with “flutter build windows” (or “flutter run -d windows”) while online: the build downloads them once and puts them next to iPanicX.exe. Alternatively, install them with MSYS2:',
    'Cette version d’iPanicX n’inclut pas les outils libimobiledevice. Recompilez-la avec « flutter build windows » (ou « flutter run -d windows ») avec une connexion Internet : le build les télécharge une fois et les place à côté d’iPanicX.exe. Sinon, installez-les avec MSYS2 :',
  );
  String get installHintMac => _(
    'Install it with Homebrew, or build iPanicX with the bundled tools (see README).',
    'Installez-le avec Homebrew, ou compilez iPanicX avec les outils embarqués (voir README).',
  );
  String get usbServiceWindows => _(
    'Unable to list USB devices. Make sure “Apple Devices” or iTunes is installed and the Apple Mobile Device Service is running.',
    'Impossible de lister les appareils USB. Vérifiez que « Appareils Apple » ou iTunes est installé et que le service Apple Mobile Device est lancé.',
  );
  String get usbServiceTitleWindows => _(
    'Apple Mobile Device Service not running',
    'Service Apple Mobile Device absent',
  );
  String get usbServiceTitleMac =>
      _('usbmuxd not running', 'usbmuxd ne répond pas');
  String get usbServiceStepsWindows => _(
    '1. Install “Apple Devices” from the Microsoft Store (or iTunes).\n2. Open it once with the iPhone plugged in and unlocked.\n3. If it is already installed: in services.msc, start “Apple Mobile Device Service”.\niPanicX detects the iPhone as soon as the service answers.',
    '1. Installez « Appareils Apple » depuis le Microsoft Store (ou iTunes).\n2. Ouvrez-le une fois avec l’iPhone branché et déverrouillé.\n3. S’il est déjà installé : dans services.msc, démarrez « Apple Mobile Device Service ».\niPanicX détecte l’iPhone dès que le service répond.',
  );
  String get openStore =>
      _('Open Microsoft Store', 'Ouvrir le Microsoft Store');
  String get appleDevicesMissingTitle =>
      _('Apple Devices is not installed', 'Apple Devices n’est pas installé');
  String get appleDevicesMissingHelp => _(
    'iPanicX needs Apple’s “Apple Devices” app (or iTunes) to talk to an iPhone: it installs Apple’s USB driver and the Apple Mobile Device Service. Install it once from the Microsoft Store, open it with the iPhone plugged in, then come back: iPanicX detects the iPhone automatically.',
    'iPanicX a besoin de l’app « Apple Devices » d’Apple (ou d’iTunes) pour communiquer avec un iPhone : elle installe le pilote USB d’Apple et le service Apple Mobile Device. Installez-la une fois depuis le Microsoft Store, ouvrez-la avec l’iPhone branché, puis revenez ici : iPanicX détecte l’iPhone automatiquement.',
  );
  String get installAppleDevices =>
      _('Install Apple Devices', 'Installer Apple Devices');
  String get appleServiceStoppedTitle => _(
    'Apple Mobile Device Service is stopped',
    'Le service Apple Mobile Device est arrêté',
  );
  String get appleServiceStoppedHelp => _(
    'Apple Devices (or iTunes) is installed, but its service is not running. Open Apple Devices once with the iPhone plugged in, or start “Apple Mobile Device Service” in Windows Services. Restarting the PC also works.',
    'Apple Devices (ou iTunes) est installé, mais son service ne tourne pas. Ouvrez Apple Devices une fois avec l’iPhone branché, ou démarrez « Apple Mobile Device Service » dans les Services Windows. Redémarrer le PC fonctionne aussi.',
  );
  String get openServices => _('Open Services', 'Ouvrir les Services');
  String get lookupTimeoutHelp => _(
    'idevice_id did not answer in time. Unplug and reconnect the iPhone, or restart “Apple Mobile Device Service”.',
    'idevice_id n’a pas répondu à temps. Débranchez et rebranchez l’iPhone, ou redémarrez « Apple Mobile Device Service ».',
  );
  String get usbServiceMac => _(
    'Unable to list USB devices. Is usbmuxd running?',
    'Impossible de lister les appareils USB. usbmuxd est-il lancé ?',
  );

  // ------------------------------------------------------------- health
  String get healthSection => _('Health', 'Santé');
  String get consoleSection => 'Console';
  String get checkBattery => _('Battery', 'Batterie');
  String get checkStorage => _('Storage', 'Stockage');
  String get checkAppCrashes => _('App crashes', 'Crashs d’apps');
  String get checkJetsam => _('Jetsam / memory', 'Jetsam / mémoire');
  String get checkTemperature => _('Temperature', 'Température');
  String get checkNand => _('NAND / storage chip', 'NAND / puce de stockage');
  String get checkBaseband => _('Baseband (modem)', 'Baseband (modem)');
  String get checkDeveloperMode => 'Developer Mode';
  String get checkWifi => 'Wi-Fi';
  String get checkWifiDetail => _(
    'iOS only shares the Wi-Fi address, not the state of the Wi-Fi chip.',
    'iOS ne donne que l’adresse Wi-Fi, pas l’état de la puce Wi-Fi.',
  );
  String get unavailable => _('Not available', 'Non disponible');
  String chargeOnly(int n) => _('Charge $n %', 'Charge $n %');
  String get batteryUnavailableDetail => _(
    'This iPhone or iOS version does not expose the battery capacity.',
    'Cet iPhone ou cette version d’iOS n’expose pas la capacité de la batterie.',
  );
  String healthValue(int n) => _('Health $n %', 'Santé $n %');
  String cycles(int n) => _('$n cycles', '$n cycles');
  String get batteryWorn => _(
    'The battery holds noticeably less than when new. Below 80 %, Apple considers it worn.',
    'La batterie tient nettement moins qu’à neuf. Sous 80 %, Apple la considère comme usée.',
  );
  String storageUsed(int n) => _('$n % used', '$n % utilisé');
  String get storageFullDetail => _(
    'An almost full storage slows iOS down and can cause restarts.',
    'Un stockage presque plein ralentit iOS et peut provoquer des redémarrages.',
  );
  String get notScanned =>
      _('Scan the iPhone first', 'Analysez d’abord l’iPhone');
  String get noneFound => _('None', 'Aucun');
  String detected(int n) =>
      plural(n, 'detected', 'détecté', enMany: 'detected');
  String inLastDays(int n, int d) => _('$n in $d days', '$n sur $d jours');
  String eventsInLastDays(int n, int d) => _(
    '${plural(n, 'event', 'événement')} in $d days',
    '${plural(n, 'event', 'événement')} sur $d jours',
  );
  String get jetsamDetail => _(
    'iOS often had to close apps to free memory.',
    'iOS a souvent dû fermer des apps pour libérer de la mémoire.',
  );
  String degrees(double t) => _(
    '${t.toStringAsFixed(1)} °C',
    '${t.toStringAsFixed(1).replaceAll('.', ',')} °C',
  );
  String thermalPanics(int n) => plural(
    n,
    'thermal panic',
    'panic thermique',
    frMany: 'panics thermiques',
  );
  String get noIssueFound => _('No issue found', 'Aucun problème détecté');
  String relatedPanics(int n) =>
      plural(n, 'related panic', 'panic lié', frMany: 'panics liés');
  String get enabled => _('On', 'Activé');
  String get disabled => _('Off', 'Désactivé');
  String get statusOk => 'OK';
  String get statusWarning => _('Attention', 'Attention');
  String get statusProblem => _('Problem', 'Problème');
  String get overallState => _('Overall state', 'État général');
  String get overallOk => _('No issue found', 'Aucun problème détecté');
  String get overallWarning => _('Needs attention', 'À surveiller');
  String get overallProblem => _('Problem detected', 'Problème détecté');
  String get checklist => _('Checks', 'Vérifications');
  String get mainIssue => _('Main issue', 'Problème principal');
  String sameClue(int n, String what) => _(
    '$n kernel panics with the same $what',
    '$n kernel panics avec le même $what',
  );
  String clueKind(String kind) => switch (kind) {
    'missingSensor' => _('missing sensor', 'capteur manquant'),
    'sensorMask' => _('sensor mask', 'masque capteur'),
    'watchdogService' => _('unresponsive service', 'service bloqué'),
    _ => _('signature', 'signature'),
  };
  String get probableCause => _('Probable cause', 'Cause probable');
  String get componentUnknown => _(
    'Not mapped yet in the knowledge base',
    'Pas encore référencé dans la base',
  );
  String get occurrences => 'Occurrences';
  String get firstSeen => _('First seen', 'Première apparition');
  String get lastSeen => _('Last seen', 'Dernière apparition');
  String get correlation => _('Correlation', 'Corrélation');
  String get correlationHint => _(
    'Panics grouped by what they have in common. The same hardware clue seen 3 times or more raises the confidence.',
    'Panics regroupés par point commun. Le même indice matériel vu 3 fois ou plus augmente la confiance.',
  );
  String get noCorrelation =>
      _('No panic to correlate.', 'Aucun panic à corréler.');
  String get refresh => _('Refresh', 'Actualiser');
  String get readingDevice => _('Reading the iPhone…', 'Lecture de l’iPhone…');
  String get healthNeedsDevice => _(
    'Connect an iPhone to see its health.',
    'Branchez un iPhone pour voir son état.',
  );
  String get healthNeedsScan => _(
    'Battery and storage are read live. Scan the iPhone to add panics, crashes and correlation.',
    'La batterie et le stockage sont lus en direct. Analysez l’iPhone pour ajouter panics, crashs et corrélation.',
  );
  // Battery page
  String get battery => _('Battery', 'Batterie');
  String get charge => _('Charge', 'Charge');
  String get charging => _('charging', 'en charge');
  String get cycleCount => _('Cycle count', 'Cycles de charge');
  String get designCapacity => _('Design capacity', 'Capacité d’origine');
  String get currentCapacity => _('Current capacity', 'Capacité actuelle');
  String get estimatedHealth => _('Estimated health', 'Santé estimée');
  String get batteryTemperature => _('Temperature', 'Température');
  String mah(int n) => '$n mAh';
  String get batteryHealthHint => _(
    'Current capacity ÷ design capacity, from the battery’s own gauge. iOS Settings may show a slightly different figure.',
    'Capacité actuelle ÷ capacité d’origine, selon la jauge de la batterie. Les Réglages d’iOS peuvent afficher un chiffre un peu différent.',
  );
  String get batteryWornWarning =>
      _('Battery heavily worn', 'Batterie fortement usée');
  String get batteryAgingWarning =>
      _('Battery wearing out', 'Batterie en cours d’usure');
  String get storageSection => _('Storage', 'Stockage');
  String get capacity => _('Capacity', 'Capacité');
  String get available => _('Available', 'Disponible');
  String get used => _('Used', 'Utilisé');
  String get basebandVersion => _('Baseband version', 'Version baseband');
  String get wifiAddress => _('Wi-Fi address', 'Adresse Wi-Fi');
  // Console
  String get consoleStart => _('Start', 'Démarrer');
  String get consoleStop => _('Stop', 'Arrêter');
  String get consolePause => _('Pause', 'Pause');
  String get consoleResume => _('Resume', 'Reprendre');
  String get consoleClear => _('Clear', 'Effacer');
  String get consoleExport => _('Export…', 'Exporter…');
  String get consoleEventsOnly => _('Events only', 'Événements seulement');
  String get consoleAll => _('All', 'Tout');
  String get consoleIdle => _(
    'Shows the iPhone’s live log. Important lines are highlighted and explained.',
    'Affiche le journal en direct de l’iPhone. Les lignes importantes sont mises en évidence et expliquées.',
  );
  String get consoleNeedsDevice => _(
    'Connect an iPhone to read its live log.',
    'Branchez un iPhone pour lire son journal en direct.',
  );
  String consoleCount(int n, int events) =>
      _('$n lines · $events events', '$n lignes · $events événements');
  String get consoleWaiting =>
      _('Waiting for log lines…', 'En attente de lignes…');
  String consoleExplain(String key) => switch (key) {
    'panic' => _('Kernel panic in progress', 'Kernel panic en cours'),
    'watchdog' => _(
      'A system service stopped answering (watchdog)',
      'Un service système ne répond plus (watchdog)',
    ),
    'sensor' => _(
      'A hardware sensor is missing',
      'Un capteur matériel est manquant',
    ),
    'thermal' => _('Thermal event', 'Événement thermique'),
    'memory' => _(
      'Memory pressure: iOS is closing apps',
      'Pression mémoire : iOS ferme des apps',
    ),
    'smc' => _('Power / SMC controller', 'Contrôleur d’alimentation / SMC'),
    'battery' => _('Battery / charging', 'Batterie / charge'),
    'crash' => _('An app crashed', 'Une app a planté'),
    'usb' => _('USB / Lightning accessory', 'Accessoire USB / Lightning'),
    _ => '',
  };
  // Scan cancel + history
  String get cancel => _('Cancel', 'Annuler');
  String sinceLastScan(String when) =>
      _('Since the last scan ($when)', 'Depuis le dernier scan ($when)');
  String panicsDelta(int n) => n == 0
      ? _('no new kernel panic', 'aucun nouveau kernel panic')
      : _('+$n kernel panics', '+$n kernel panics');
  String batteryDelta(int from, int to) =>
      _('battery $from → $to %', 'batterie $from → $to %');
  String get history => _('History', 'Historique');
  String get historyHint => _(
    'A short summary of each scan is kept on this computer to compare scans of the same iPhone.',
    'Un court résumé de chaque scan est gardé sur cet ordinateur pour comparer les scans d’un même iPhone.',
  );
  String historyCount(int n) =>
      plural(n, 'saved scan', 'scan enregistré', frMany: 'scans enregistrés');
  String get clearHistory => _('Clear History', 'Effacer l’historique');
  String get historyCleared => _('History cleared', 'Historique effacé');
  String get fullReport => _('Full report', 'Rapport complet');
  String get fullReportHint => _(
    'Health, battery, correlation and every panic, as a .txt file',
    'Santé, batterie, corrélation et chaque panic, en .txt',
  );

  // --------------------------------------------------------- app crashes
  String get appCrashesTitle => _('App crashes', 'Crashs d’apps');
  String get period7 => _('7 days', '7 jours');
  String get period30 => _('30 days', '30 jours');
  String get periodAll => _('All', 'Tout');
  String crashCount(int n) => plural(n, 'crash', 'crash', enMany: 'crashes');
  String appCount(int n) => plural(n, 'app', 'app');
  String get byApp => _('By app', 'Par app');
  String get byCause => _('By cause', 'Par cause');
  String get perDay => _('Per day', 'Par jour');
  String get noCrashes =>
      _('No app crash in this period', 'Aucun crash d’app sur cette période');
  String get mainCauseLabel => _('Main cause', 'Cause principale');
  String get appleApp => 'Apple';
  String get crashesHint => _(
    'Tap an app to see each of its crashes.',
    'Touchez une app pour voir chacun de ses crashs.',
  );
  String get crashList => _('Crashes', 'Crashs');
  String get bundleId => 'Bundle ID';
  String get appVersion => _('Version', 'Version');
  String get exceptionLabel => 'Exception';
  String get terminationLabel => _('Termination', 'Arrêt');
  String get reasonLabel => _('Reason', 'Raison');
  String get crashedInLabel => _('Crashed in', 'Plantage dans');
  String get fileLabel => _('File', 'Fichier');
  String get viewRawReport => _('View Raw Report', 'Voir le rapport brut');
  String crashCauseLabel(String key) => switch (key) {
    'watchdog' => _('Froze (watchdog)', 'Figée (watchdog)'),
    'thermal' => _('Too hot', 'Trop chaud'),
    'fileLock' => _('File lock', 'Verrou de fichier'),
    'memoryAccess' => _('Memory error', 'Erreur mémoire'),
    'abort' => _('Aborted', 'Arrêt volontaire'),
    'swiftError' => _('Runtime error', 'Erreur d’exécution'),
    'cpuLimit' => _('Too much CPU', 'Trop de CPU'),
    'memoryLimit' => _('Too much memory', 'Trop de mémoire'),
    'guard' => _('Protected resource', 'Ressource protégée'),
    'killed' => _('Killed by iOS', 'Arrêtée par iOS'),
    _ => _('Other', 'Autre'),
  };
  String crashCauseExplain(String key) => switch (key) {
    'watchdog' => _(
      'iOS closed the app because it stopped responding (code 0x8badf00d). Usually an app bug; on many apps at once, an almost full or slow storage.',
      'iOS a fermé l’app car elle ne répondait plus (code 0x8badf00d). En général un bug de l’app ; sur beaucoup d’apps à la fois, un stockage presque plein ou lent.',
    ),
    'thermal' => _(
      'iOS closed the app because the iPhone was overheating (0xc00010ff). Check the battery, charging and thermal panics.',
      'iOS a fermé l’app car l’iPhone surchauffait (0xc00010ff). Vérifiez la batterie, la charge et les panics thermiques.',
    ),
    'fileLock' => _(
      'The app kept a file locked while in the background (0xdead10cc). An app bug.',
      'L’app a gardé un fichier verrouillé en arrière-plan (0xdead10cc). Un bug de l’app.',
    ),
    'memoryAccess' => _(
      'The app read or wrote invalid memory (EXC_BAD_ACCESS). An app bug when it is one app; on many apps, including Apple’s, it can point to iOS or the memory.',
      'L’app a lu ou écrit une mémoire invalide (EXC_BAD_ACCESS). Un bug de l’app si c’est une seule app ; sur beaucoup d’apps, y compris celles d’Apple, cela peut venir d’iOS ou de la mémoire.',
    ),
    'abort' => _(
      'The app stopped itself after an internal error (SIGABRT). An app bug.',
      'L’app s’est arrêtée elle-même après une erreur interne (SIGABRT). Un bug de l’app.',
    ),
    'swiftError' => _(
      'A safety check in the app’s code failed (EXC_BREAKPOINT). An app bug.',
      'Un contrôle de sécurité du code de l’app a échoué (EXC_BREAKPOINT). Un bug de l’app.',
    ),
    'cpuLimit' => _(
      'iOS stopped the app for using too much processor time (EXC_RESOURCE).',
      'iOS a arrêté l’app car elle utilisait trop le processeur (EXC_RESOURCE).',
    ),
    'memoryLimit' => _(
      'iOS stopped the app for using too much memory (EXC_RESOURCE).',
      'iOS a arrêté l’app car elle utilisait trop de mémoire (EXC_RESOURCE).',
    ),
    'guard' => _(
      'The app misused a protected system resource (EXC_GUARD). An app bug.',
      'L’app a mal utilisé une ressource système protégée (EXC_GUARD). Un bug de l’app.',
    ),
    'killed' => _(
      'iOS terminated the app (SIGKILL), often in the background or to free memory.',
      'iOS a arrêté l’app (SIGKILL), souvent en arrière-plan ou pour libérer de la mémoire.',
    ),
    _ => _(
      'Unusual exception: see the technical details.',
      'Exception inhabituelle : voir les détails techniques.',
    ),
  };

  /// `de Safari`, `d’Instagram`.
  static String _frDe(String name) =>
      RegExp(r'^[aeiouyhAEIOUYHÉÈÊÂÎÔÛéèêâîôû]').hasMatch(name)
      ? 'd’$name'
      : 'de $name';

  String crashPatternTitle(String key) => switch (key) {
    'oneApp' => _('Mostly one app', 'Surtout une seule app'),
    'systemWide' => _(
      'Many apps, memory errors',
      'Beaucoup d’apps, erreurs mémoire',
    ),
    'thermal' => _('Overheating', 'Surchauffe'),
    _ => _('No clear pattern', 'Pas de tendance nette'),
  };
  String crashPatternExplain(
    String key,
    String app,
    int percent,
  ) => switch (key) {
    'oneApp' => _(
      '$percent % of the crashes come from $app: a problem with this app (update or reinstall it), not with the iPhone.',
      '$percent % des crashs viennent ${_frDe(app)} : un problème de cette app (mettez-la à jour ou réinstallez-la), pas de l’iPhone.',
    ),
    'systemWide' => _(
      'Several apps, including Apple’s, crash on memory errors: possible iOS or hardware problem (memory, storage). Update or restore iOS, then check the hardware.',
      'Plusieurs apps, y compris celles d’Apple, plantent sur des erreurs mémoire : problème possible d’iOS ou du matériel (mémoire, stockage). Mettez à jour ou restaurez iOS, puis vérifiez le matériel.',
    ),
    'thermal' => _(
      'Some apps were closed because the iPhone was too hot.',
      'Des apps ont été fermées car l’iPhone était trop chaud.',
    ),
    _ => _(
      'The crashes are spread across several apps and causes.',
      'Les crashs sont répartis entre plusieurs apps et causes.',
    ),
  };

  // ------------------------------------------------------------- analyzer
  String get knownSignatureDisclaimer => _(
    'This diagnosis is based on a known panic signature and should be confirmed by hardware inspection.',
    'Ce diagnostic repose sur une signature de panic connue et doit être confirmé par une inspection matérielle.',
  );
  String get knownSignatureSummary => _(
    'This panic matches a known signature in the iPanicX knowledge base.',
    'Ce panic correspond à une signature connue de la base iPanicX.',
  );
  String get defaultAction => _(
    'Inspect the suspected components and their connectors before restoring the device.',
    'Inspectez les composants suspectés et leurs connecteurs avant de restaurer l’appareil.',
  );
  String get unknownTitle =>
      _('Unknown Hardware Panic', 'Panic matériel inconnu');
  String get unknownSummary => _(
    'The panic was successfully parsed, but this signature is not currently present in the iPanicX knowledge base.',
    'Le panic a bien été lu, mais cette signature n’est pas encore dans la base de connaissances iPanicX.',
  );
  List<String> get unknownActions => _fr
      ? const [
          'Examinez le message de panic et les codes détectés ci-dessous.',
          'Vérifiez si le même panic se répète sur plusieurs rapports.',
        ]
      : const [
          'Review the panic string and detected codes below.',
          'Check whether the same panic repeats across several reports.',
        ];
  String get incompleteTitle =>
      _('Incomplete Panic Report', 'Rapport de panic incomplet');
  String get incompleteSummary => _(
    'The file was read, but no panic description could be found in it. It may be truncated or use an unsupported format.',
    'Le fichier a été lu, mais aucune description de panic n’y a été trouvée. Il est peut-être tronqué ou dans un format non pris en charge.',
  );
  List<String> get incompleteActions => _fr
      ? const [
          'Ouvrez le rapport brut pour l’examiner.',
          'Relancez une analyse après le prochain redémarrage.',
        ]
      : const [
          'Open the raw panic to inspect it manually.',
          'Scan again after the next restart to get a fresh report.',
        ];
  String get notPanicTitle => _('Not a Kernel Panic', 'Pas un kernel panic');
  String notPanicSummary(String kind, String? bugType) => _(
    'This file is a ${kind.toLowerCase()} report (bug_type $bugType), not a kernel panic. iPanicX only diagnoses kernel panics in this version.',
    'Ce fichier est un rapport « $kind » (bug_type $bugType), pas un kernel panic. Cette version d’iPanicX ne diagnostique que les kernel panics.',
  );
  String get notPanicAction => _(
    'Open a panic-full or panic-base file to get a hardware diagnosis.',
    'Ouvrez un fichier panic-full ou panic-base pour obtenir un diagnostic matériel.',
  );
  String evidenceDevice(String? product) =>
      _('Device $product', 'Appareil $product');
  String evidencePanicLine(String term) =>
      _('Panic line “$term”', 'Ligne de panic « $term »');
  String evidenceTerm(String term) => _fr ? '« $term »' : '“$term”';
  String evidenceKext(String kext) => 'Kext $kext';
  String evidenceMask(String mask) =>
      _('Sensor mask $mask', 'Masque capteur $mask');
  String evidenceMissing(String sensor) =>
      _('Missing sensor $sensor', 'Capteur manquant $sensor');
  String evidenceMaskTable(String model) =>
      _('SMC mask table: $model', 'Table des masques SMC : $model');

  // SMC sensor mask decoding (per-model table).
  String smcDecodedSummary(String parts) => _(
    'The SMC lost contact with one or more sensors. On this model, the sensor mask points to: $parts.',
    'Le SMC a perdu le contact avec un ou plusieurs capteurs. Sur ce modèle, le masque capteur désigne : $parts.',
  );
  String smcDecodedReason(String mask, String model, String codes) => _(
    'The SMC reported a BSC (sensor bus) failure with sensor mask $mask. On $model: $codes.',
    'Le SMC a signalé une panne BSC (bus des capteurs) avec le masque $mask. Sur $model : $codes.',
  );
  String smcUnknownBits(String bits) => _(
    'Bits $bits are not referenced for this model: another part may also be involved.',
    'Les bits $bits ne sont pas référencés pour ce modèle : une autre pièce peut aussi être en cause.',
  );
  String smcAlternative(String mask, String codes) => _(
    '$mask can also be read as $codes: check those parts too.',
    '$mask peut aussi se lire $codes : vérifiez aussi ces pièces.',
  );
  String smcNotMapped(String mask, String model) => _(
    'Sensor mask $mask is not referenced for $model in the knowledge base.',
    'Le masque capteur $mask n’est pas référencé pour $model dans la base.',
  );
  String missingSensorsReason(String list) => _(
    'thermalmonitord stopped receiving data from: $list.',
    'thermalmonitord ne reçoit plus de données de : $list.',
  );
  String missingSensorsUnknown(String names) => _(
    'Not referenced in the knowledge base: $names.',
    'Non référencés dans la base : $names.',
  );
  String get sources => _('Sources', 'Sources');
  String i2cChips(String bus, String chips) =>
      _('Chips on $bus: $chips', 'Puces sur $bus : $chips');
  String i2cReason(String bus, String model, String chips) => _(
    'Bus $bus on $model: $chips (board reference designators, check them on the boardview).',
    'Bus $bus sur $model : $chips (repères de la carte, à vérifier sur le boardview).',
  );

  // --------------------------------------------------------- text report
  String get reportTitle =>
      _('iPanicX diagnostic report', 'Rapport de diagnostic iPanicX');
  String get reportLocal => _(
    'All diagnostic processing was performed locally on this computer.',
    'Tout le diagnostic a été effectué localement sur cet ordinateur.',
  );
  String get file => _('File', 'Fichier');
  String get codes => 'Codes';
}
