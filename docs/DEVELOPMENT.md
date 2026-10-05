<p align="center"><img src="../assets/logo/iPanicX.png" width="120" alt="iPanicX"></p>

# iPanicX

Application de bureau **macOS et Windows** (Flutter, avec du natif Swift sur
macOS) qui lit les rapports de diagnostic d'un iPhone branché en USB, analyse automatiquement les **kernel panics**
(`panic-full*.ips`, `panic-base*.ips`) et affiche un diagnostic lisible.

> **100 % local.** Aucun analytics, aucune télémétrie, aucune API externe,
> aucun serveur. Les rapports sont copiés dans un dossier temporaire de
> l'ordinateur et analysés sur place.

Chaîne : **iPhone USB → copie des crash reports → parsing → analyse par la
base de connaissances → corrélation → bilan de santé → export `.txt`.**

## V1 en bref

| Écran | Ce qu'il apporte |
|---|---|
| **Santé** | état général (OK / à surveiller / problème, **sans note sur 100**), problème principal, vérifications : batterie, stockage, kernel panics, crashs d'apps (7 j), Jetsam (7 j), température, NAND, baseband, Developer Mode, Wi-Fi |
| **Santé › Batterie** | charge, cycles, capacité d'origine / actuelle, santé estimée, température (`AppleSmartBattery`) |
| **Santé › Corrélation** | panics regroupés par indice matériel (capteur manquant comme `TG0B`, masque SMC, service du watchdog) avec occurrences, première / dernière apparition, pièce suspectée ; confiance relevée d'un cran à partir de 3 occurrences |
| **Console** | journal en direct (`idevicesyslog`), lignes importantes colorées et expliquées, filtre « Événements seulement », pause, export |
| **Historique** | résumé local de chaque scan, « depuis le dernier scan : +N kernel panics, batterie 78 → 76 % » |
| **Rapport complet** | santé + batterie + corrélation + liste des panics en `.txt` |

Une valeur qu'iOS n'expose pas s'affiche **« Non disponible »**, jamais
inventée. Les commandes utilisées sont toutes en lecture seule.

---

## Prérequis

| Outil | macOS | Windows |
|---|---|---|
| OS | 12 Monterey ou plus récent | Windows 10/11 x64 |
| Toolchain | Xcode 15+ | Visual Studio 2022, charge « Développement Desktop en C++ » |
| Flutter | stable (développé avec 3.47.6 / Dart 3.13) | idem |
| Pilote iPhone | intégré à macOS (usbmuxd) | app **Apple Devices** (Microsoft Store) ou **iTunes** : pilote USB + *Apple Mobile Device Service* |
| libimobiledevice | Homebrew ou embarqué | MSYS2 ou embarqué |

Outils utilisés : `idevice_id`, `ideviceinfo`, `idevicecrashreport`,
`idevicepair`, `idevicediagnostics`, `idevicesyslog` (libimobiledevice 1.3+).

| Donnée | Commande (lecture seule) |
|---|---|
| Batterie | `idevicediagnostics ioregentry AppleSmartBattery` (+ `ideviceinfo -q com.apple.mobile.battery`) |
| Stockage | `ideviceinfo -q com.apple.disk_usage` |
| Developer Mode | `ideviceinfo -q com.apple.security.mac.amfi` (`DeveloperModeStatus`) |
| Baseband, Wi-Fi | `ideviceinfo` (`BasebandVersion`, `WiFiAddress`) |
| Console | `idevicesyslog -u <udid>` |
| Crashs d'apps, Jetsam, ResetCounter | en-tête JSON des rapports copiés (`bug_type` 309/109, 298, 115) |

### Installer Flutter (macOS)

```bash
brew install --cask flutter        # ou https://docs.flutter.dev/get-started/install/macos
flutter config --enable-macos-desktop
flutter doctor                     # Xcode doit être ✓
```

### Installer Flutter (Windows)

```powershell
winget install --id=Flutter.Flutter -e      # ou https://docs.flutter.dev/get-started/install/windows
flutter config --enable-windows-desktop
flutter doctor                               # Visual Studio doit être ✓
```

### Installer libimobiledevice — macOS

**Option A — Homebrew (développement)**

```bash
brew install libimobiledevice
idevice_id -l                      # doit afficher l'UDID de l'iPhone branché
```

iPanicX cherche les outils dans cet ordre :

1. `$IPANICX_TOOLS_DIR` ;
2. les outils embarqués dans l'app : `iPanicX.app/Contents/Resources/libimobiledevice/bin` ;
3. `/opt/homebrew/bin`, `/usr/local/bin`, `/opt/local/bin` ;
4. le `PATH`.

**Option B — outils embarqués dans l'app (distribution)**

```bash
brew install libimobiledevice
./scripts/bundle_libimobiledevice.sh
```

Le script copie les 4 exécutables et toutes leurs dylibs non-système dans
`macos/libimobiledevice/{bin,lib}` (ignoré par git), réécrit les chemins
(`@executable_path/../lib`, `@loader_path`) et les signe en ad hoc. La phase
Xcode **« Embed libimobiledevice »** (`scripts/embed_libimobiledevice.sh`) les
copie ensuite dans `Contents/Resources/libimobiledevice` et les signe avec
l'identité de l'app (`--options runtime --timestamp` en Developer ID).
Sans ce dossier, la phase ne fait rien et l'app retombe sur Homebrew.

### Installer libimobiledevice — Windows

1. Installer **Apple Devices** (Microsoft Store) ou **iTunes** : ils fournissent
   le pilote USB et le service *Apple Mobile Device Service* auquel
   libimobiledevice se connecte. Brancher l'iPhone et accepter « Faire
   confiance ».
2. **Rien d'autre à installer** : `flutter run -d windows` / `flutter build
   windows` télécharge **une seule fois** (au configure CMake, ~9 Mo) les
   paquets officiels MSYS2 UCRT64 de libimobiledevice, vérifie leur SHA-256,
   et installe `idevice_id.exe`, `ideviceinfo.exe`, `idevicecrashreport.exe`,
   `idevicepair.exe` et leurs 6 DLL dans `libimobiledevice\` à côté de
   `iPanicX.exe` (`windows/libimobiledevice.cmake`). Le cache est dans
   `build\windows\x64\libimobiledevice\`. L'app elle-même reste hors ligne.

   Versions figées : libimobiledevice 1.3.0-17, libimobiledevice-glue 1.3.2,
   libplist 2.7.0, libusbmuxd 2.1.1, OpenSSL 3.6.5. Pour les mettre à jour,
   changer noms et SHA-256 dans `windows/libimobiledevice.cmake`. Pour
   désactiver le téléchargement : `-DIPANICX_FETCH_LIBIMOBILEDEVICE=OFF`.

Si le build ne voit pas les outils (build hors ligne, ancienne copie du dossier
`build`), lancer `flutter clean` puis `flutter run -d windows`, ou les
installer avec [MSYS2](https://www.msys2.org/) dans le shell **UCRT64** :

```bash
pacman -S --needed mingw-w64-ucrt-x86_64-libimobiledevice
```

iPanicX cherche les outils (`*.exe`) dans cet ordre : `%IPANICX_TOOLS_DIR%`,
`<dossier de iPanicX.exe>\libimobiledevice[\bin]`, `C:\msys64\{ucrt64,mingw64,clang64}\bin`,
`%ProgramFiles%\libimobiledevice`, `%LOCALAPPDATA%\Programs\libimobiledevice`, puis le `Path`.

**Outils d'une installation MSYS2 locale** (prioritaires sur le
téléchargement) — depuis le shell MSYS2 UCRT64 :

```bash
./scripts/bundle_libimobiledevice_windows.sh
```

Le script copie les 4 `.exe` et leurs DLL MSYS2 (via `ldd`) dans
`windows/libimobiledevice/` (ignoré par git), que le build installe à la place
des paquets téléchargés.

### iPhone branché mais non détecté

Quand `idevice_id -l` ne liste rien, iPanicX vérifie aussi côté ordinateur et
affiche le résultat dans **Détails techniques** :

- **le service USB d'Apple répond-il ?** `127.0.0.1:27015` (Apple Mobile
  Device Service) sous Windows, `/var/run/usbmuxd` sous macOS
  (`USBMUXD_SOCKET_ADDRESS` est respecté) ;
- **l'OS voit-il un iPhone ?** `Win32_PnPEntity` avec l'ID vendeur Apple
  (`USB\VID_05AC&PID_12xx`) via PowerShell sous Windows, `ioreg -p IOUSB` sous
  macOS.

| Écran | Cause probable | Que faire |
|---|---|---|
| **Aucun iPhone connecté** | l'OS ne voit aucun iPhone | câble de données (pas un câble de charge seule), iPhone déverrouillé, autre port |
| **iPhone non reconnu** | Windows voit l'iPhone mais le service Apple ne le liste pas, ou le pilote est en erreur (code ≠ 0 dans le Gestionnaire de périphériques) | installer/réparer **Apple Devices** ou iTunes, l'ouvrir une fois, rebrancher ; sinon redémarrer *Apple Mobile Device Service* (`services.msc`) |
| **Apple Devices n'est pas installé** | ni le service *Apple Mobile Device*, ni le paquet Store Apple Devices / iTunes (requête PowerShell `Get-Service` + `Get-AppxPackage`) | bouton **Installer Apple Devices** (ouvre sa fiche du Microsoft Store), l'ouvrir une fois iPhone branché |
| **Le service Apple Mobile Device est arrêté** | Apple Devices / iTunes installé mais rien n'écoute sur `127.0.0.1:27015` | bouton **Ouvrir les Services** (`services.msc`) → démarrer *Apple Mobile Device Service*, ou ouvrir Apple Devices, ou redémarrer le PC |
| **Service Apple Mobile Device absent** | service injoignable et installation indéterminée | idem ci-dessus |

Vérification manuelle (PowerShell) :

```powershell
& "C:\msys64\ucrt64\bin\idevice_id.exe" -l
Get-CimInstance Win32_PnPEntity -Filter "PNPDeviceID LIKE 'USB\\VID_05AC%'" | Select Name, ConfigManagerErrorCode
Get-Service "Apple Mobile Device Service"
```

Ce test du service est fait **avant** `idevice_id` : sans service, libusbmuxd
attend 5 s (`CONNECT_TIMEOUT`) à chaque essai avant d'échouer. Le runner
Windows désactive aussi les boîtes d'erreur système pour les outils lancés
(`SetErrorMode`) : une DLL manquante donne un code d'erreur
(`STATUS_DLL_NOT_FOUND`) affiché par iPanicX, au lieu d'une fenêtre qui bloque.

Une passe de détection est bornée à 45 s : l'écran « Recherche d'appareils… »
ne peut plus rester affiché indéfiniment.

### Build depuis les sources (macOS)

**Option C — build depuis les sources** (si besoin d'une version précise) :
compiler dans l'ordre `libplist`, `libimobiledevice-glue`, `libusbmuxd`,
`libtatsu`, `libimobiledevice` (`./autogen.sh && make && make install` avec un
`--prefix` dédié), puis lancer `bundle_libimobiledevice.sh` avec ce préfixe en
tête du `PATH`.

> libimobiledevice et ses dépendances sont sous licence LGPL-2.1 (et autres
> licences libres) : joindre leurs textes de licence à toute version distribuée.

---

## Lancer l'application

```bash
flutter pub get

# Avec un vrai iPhone (USB, déverrouillé, « Faire confiance » accepté)
flutter run -d macos               # ou : flutter run -d windows

# Sans iPhone : mode mock (iPhone 14 Pro simulé, iPhone15,2, iOS 26.0.1)
flutter run -d macos --dart-define=USE_MOCK_DEVICE=true
flutter run -d windows --dart-define=USE_MOCK_DEVICE=true
```

Build release :

```bash
flutter build macos --release      # build/macos/Build/Products/Release/iPanicX.app
flutter build windows --release    # build\windows\x64\runner\Release\iPanicX.exe (+ DLL, data\, libimobiledevice\)
```

Sous Windows, distribuer **tout le dossier** `Release\` (l'exe seul ne suffit
pas) ou l'emballer dans un installeur (MSIX, Inno Setup…).

### Mode mock (`USE_MOCK_DEVICE=true`)

Activé par `--dart-define=USE_MOCK_DEVICE=true` (ou la variable d'environnement
`USE_MOCK_DEVICE=true`). `MockIPhoneService` simule un iPhone 14 Pro et génère
au scan : 12 panics SMC connus (masque `0x140000`), 3 panics « capteur
manquant `TG0B` », 2 panics inconnus, 2 redémarrages forcés, 9 crashs d'apps
sur la semaine, des JetsamEvent et un ResetCounter (dont certains dans
`Retired/`). Il fournit aussi une batterie usée (78 %, 843 cycles), un
stockage plein à 94 % et un journal en direct simulé pour la Console. **Général › Appareil simulé** permet de basculer entre les
états : connecté, deux iPhones, aucun panic, aucun iPhone, iPhone non reconnu
(pilote), Trust requis, verrouillé, erreur de communication, libimobiledevice
absent, échec de la copie.

---

## Fonctionnement

1. **Détection** — `idevice_id -l` toutes les 2 s ; sur macOS aussi
   immédiatement à chaque branchement/débranchement USB Apple (notification
   IOKit de `DeviceWatcher.swift` via l'EventChannel `ipanicx/usb_events`).
2. **Infos appareil** — `ideviceinfo -u <UDID>` (DeviceName, ProductType,
   ProductVersion, BuildVersion). Si l'appareil n'est pas appairé,
   `ideviceinfo -s` fournit au moins le modèle ; l'UDID est toujours masqué.
3. **Erreurs** — les codes lockdown sont traduits : `-19`/`-21`/pair record →
   *Trust required*, `-17`/`-35` → *Device locked*, `-18` → appairage refusé
   (pas de relance en boucle), timeout → *Unable to communicate*, outils
   absents → *libimobiledevice unavailable*. La sortie brute n'apparaît que dans
   la section repliable *Technical details*.
4. **Copie** — `idevicecrashreport -u <UDID> -k <dossier>` : `-k` **conserve**
   les rapports sur l'iPhone. Dossier : `<temp>/iPanicX/CrashReports/<appareil>/<date>`
   (`$TMPDIR` sur macOS, `%TEMP%` sur Windows)
   (le scan précédent du même appareil est supprimé).
5. **Classement** — scan récursif, tri par date (nom de fichier puis date de
   modification), types : `panic-full`, `panic-base` (dont `+socd`),
   `forceReset`, `JetsamEvent`, `ResetCounter`, `stacks`, autres.
6. **Parsing** (`PanicParser`) puis **analyse** (`PanicAnalyzer`) de chaque
   rapport noyau dans un isolate ; dédoublonnage par `incident` (un même panic
   existe souvent en `panic-full` et `panic-base`).
7. **Affichage** — nombre de kernel panics, dernier rapport, synthèse *Device
   Health* (factuelle, sans score), liste des panics, écran de diagnostic,
   rapport brut, copie et export `.txt` (NSSavePanel sur macOS, boîte de
   dialogue Windows via `file_selector`).

Le bouton **Open .ips…** analyse un fichier présent sur l'ordinateur, sans
iPhone.

### Formats supportés par le parser

Validé sur un corpus de 30 rapports réels publics (iOS 11 → 27) en plus des
fixtures synthétiques :

- IPS moderne : ligne d'en-tête JSON + corps JSON (`bug_type` 210) ;
- JSON unique, JSON suivi de texte, JSON tronqué/invalide (extraction des clés
  au mieux, `panicString` tronquée récupérée) ;
- rapports texte « legacy » (`panic(cpu …`, `Hardware model:`, `OS version:`,
  `Panic flags:`, `Kernel version:`) ;
- `forceReset-*` (`bug_type` 151, texte dans la clé `string`, ex. `btn_rst`) ;
- préambules avant la ligne `panic(` (`Attempting to forcibly halt cpu…`) ;
- rapports non-panic reconnus et écartés : crash d'app 109/309, ExcUserFault
  308, stackshot 288, Jetsam 298.

Champs extraits : timestamp (avec fuseau), product, modelCode, osVersion,
build, bug_type, panicString, ligne de panic, panicInitiator (clé JSON ou
déduit), process paniqué, kexts de la backtrace, socId, incident, kernel,
panicFlags, sensor mask (`sensor array 1310720` → `0x140000`, hexa ou JSON),
`Missing sensor(s)`, clés SMC 4 caractères (`TAOP`, `TAOJ`…).

---

## Architecture

```
lib/
  main.dart                      choix mock / réel, chargement de la base
  app/        app.dart, theme.dart (tokens Codenotch), app_controller.dart (état,
              langue, infos appareil, historique), console_controller.dart,
              host_platform.dart (textes et chemins selon l'OS)
  l10n/       strings.dart (tous les textes EN/FR, Dart pur), lang_scope.dart
  models/     iphone_device, device_status, diagnostic_file, panic_report,
              diagnostic_result, scan_result
  services/   iphone_service.dart (interface + erreurs)
              libimobiledevice_service.dart (réel, via CommandRunner)
              mock_iphone_service.dart, command_runner.dart, tool_locator.dart
              usb_probe.dart (service USB Apple joignable ? iPhone vu par l'OS ?)
              device_facts_parser.dart + plist.dart (batterie, stockage, amfi)
              history_store.dart (résumés de scans, par UDID haché)
              diagnostic_service.dart (scan → parse → analyse → synthèse)
              platform_bridge.dart (interface), macos_bridge.dart (canaux Swift),
              windows_bridge.dart (file_selector + explorer.exe)
  diagnostics/ panic_parser, panic_analyzer, diagnostic_rule, knowledge_base,
              knowledge_base_loader, report_formatter (diagnostic + rapport
              complet), correlation, health_report, log_rules (console)
  ui/         shell.dart (barre latérale), kit.dart, ring.dart, format.dart,
              panes/ (overview, health, panics, files, console, general,
              panic + rapport brut)
assets/diagnostics/knowledge_base.json   règles de diagnostic
assets/samples/                          rapports utilisés par le mock
macos/Runner/IPhoneBridge.swift          NSSavePanel, NSOpenPanel, Finder
macos/Runner/DeviceWatcher.swift         notifications USB IOKit
macos/Runner/MainFlutterWindow.swift     fenêtre (min 900×600), branchement des bridges
windows/runner/                          runner Win32 (titre, taille, min 900×600 via WM_GETMINMAXINFO)
windows/CMakeLists.txt                   installe windows/libimobiledevice/ à côté de iPanicX.exe
scripts/                                 bundle/embed libimobiledevice (macOS, Windows), corpus réel
tool/analyze_corpus.dart                 analyse en ligne de commande d'un dossier
```

Tous les appels aux outils passent par `CommandRunner` : remplacer
`ProcessCommandRunner` par une implémentation Dart FFI ou un wrapper
C/Swift ne touche ni l'UI ni le moteur de diagnostic. `lib/diagnostics/` et
`lib/models/` sont en Dart pur (aucune dépendance Flutter).

**Distribution Windows** : pas de signature dans la V0 ; pour distribuer,
signer `iPanicX.exe` et les outils embarqués (Authenticode, `signtool`) et
fournir un installeur. Le pilote Apple (Apple Devices / iTunes) doit être
installé par l'utilisateur.

**Distribution hors Mac App Store** : la sandbox est désactivée
(`DebugProfile/Release.entitlements`) car l'app doit lancer les outils et parler
à usbmuxd ; aucun entitlement réseau en release. Pour la notarisation : signer
avec un certificat Developer ID, activer le Hardened Runtime sur la cible
Runner, puis `xcrun notarytool submit` / `xcrun stapler staple`.

---

## Design

L'interface reprend celle de [Codenotch](https://github.com/vinzdg/codenotch)
(licence MIT), avec ses valeurs exactes :

- **Fenêtre** : sa fenêtre de réglages (`windows/codenotch/ui/settings.html`,
  palette « solid ») :
  - barre latérale en carte (196 px, inset 4 px, rayon 14) ;
  - lignes de 32 px avec icône carrée en dégradé de 20 px, trait d'accent de
    3 px `#0a7aff` sur la sélection ;
  - titre de volet 22 px, légendes de section en 13,5 px semi-gras ;
  - groupes arrondis à 10 px, lignes de 40 px séparées par des filets ;
  - valeurs en gris à droite, boutons `.btn`, contrôle segmenté ;
  - texte en 13,5 px.
- **Anneaux** : le petit anneau des listes (confiance, couleur de gravité)
  reprend la jauge de Codenotch (piste 15,5 px, arc 8 px depuis midi).
- **Apparence** : suit le système par défaut, réglable dans General
  (Système / Clair / Sombre).

**Logo** : même famille que l'icône de Codenotch (carré arrondi rempli de
peinture fluide, encoche noire à droite avec l'anneau de jauge), en palette
« panic » (noir, violet, magenta, rouge `#FF3F00`, ambre) et en 3D : épaisseur,
biseau, reflet, encoche creusée, anneau et « ! » en relief. Il est généré
par `tool/logo/generate_logo.py` (Python, numpy/scipy/Pillow, graine fixe) ;
`--install` met à jour l'icône macOS, `app_icon.ico` (Windows) et
`assets/logo/iPanicX.png`.

Code : `lib/app/theme.dart` (tokens), `lib/ui/kit.dart` (volet, groupes,
lignes, boutons), `lib/ui/ring.dart` (anneau),
`lib/ui/shell.dart` (barre latérale), `lib/ui/panes/` (Overview, Panics,
Files, General, diagnostic, rapport brut).

## Langues

L'app est en **français** et en **anglais**. Par défaut elle suit la langue du
système (`fr_*` → français, sinon anglais) ; **Général › Langue** permet de
forcer *English* ou *Français*. Le changement est immédiat : l'interface, les
dates, les diagnostics d'un scan déjà fait (régénérés sans recopier les
rapports) et l'export `.txt` suivent.

- Textes de l'interface, des écrans d'erreur et des diagnostics génériques :
  `lib/l10n/strings.dart` (une méthode par texte, `_('English', 'Français')`).
- Textes des règles : bloc `"fr"` dans chaque règle de la base (voir
  ci-dessous). Un champ absent retombe sur l'anglais.
- L'analyse tourne dans un isolate : la langue lui est passée explicitement
  (`PanicAnalyzer(kb, lang: …)`).
- Les widgets Material (menus, sélection de texte) utilisent
  `flutter_localizations`.

Ajouter une langue : une valeur dans `AppLang`, un argument de plus dans
`Strings._`, et un bloc `"<code>"` par règle.

## Ajouter une règle de diagnostic

Éditer `assets/diagnostics/knowledge_base.json` :

```json
{
  "id": "smc_bsc_iphone15_2_140000",
  "device": "iPhone15,2",
  "panicContains": ["SMC BSC failure"],
  "sensorMask": "0x140000",
  "title": "SMC Sensor Failure",
  "category": "hardware",
  "severity": "high",
  "confidence": "high",
  "summary": "…",
  "suspectedComponents": ["Charging Port Flex", "Power Button Flex"],
  "possibleCauses": ["Liquid damage", "…"],
  "recommendedActions": ["…"],
  "fr": {
    "title": "Panne de capteur SMC",
    "summary": "…",
    "suspectedComponents": ["Nappe du connecteur de charge", "Nappe du bouton d’alimentation"],
    "possibleCauses": ["…"],
    "recommendedActions": ["…"]
  }
}
```

Le bloc `"fr"` traduit les champs affichés (`title`, `summary`,
`technicalReason`, `suspectedComponents`, `possibleCauses`,
`recommendedActions`, `note`) ; les critères ne se traduisent pas.

Critères (tous ceux présents doivent être vrais ; texte insensible à la casse
et aux espaces, la liste `loaded kexts:` est ignorée pour éviter les faux
positifs) :

| Clé | Effet |
|---|---|
| `device` / `devices` | ProductType exact ou préfixe `iPhone15,*` |
| `panicContains` | tous les termes présents |
| `panicContainsAny` + `minAny` | au moins `minAny` termes (défaut 1) |
| `panicNotContains` | aucun de ces termes |
| `headlineContainsAny` | un terme dans la ligne `panic(cpu …)` elle-même |
| `kextsAny` | un kext présent dans la backtrace |
| `sensorMask` | masque exact, hexa `"0x140000"` ou décimal |
| `missingSensorsAny` | un capteur listé dans `Missing sensor(s)` |

Si plusieurs règles correspondent, la plus spécifique gagne (appareil, masque,
nombre de termes…). L'écran de diagnostic affiche les preuves (*Reconnu sur* / *Matched on*).
Sans correspondance : **Panic matériel inconnu** (*Unknown Hardware Panic*), avec panic string, codes,
masque, modèle et iOS.

Pour valider une règle sur des rapports réels :

```bash
dart run tool/analyze_corpus.dart ~/Desktop/mes-panics
```

> La base V0 contient **une règle précise d'exemple** (iPhone15,2 + SMC BSC
> failure + masque `0x140000` → Charging Port Flex / Power Button Flex) et des
> signatures génériques à confiance faible ou moyenne (SMC, capteur thermique
> manquant, watchdog, AOP, NAND, GPU/AGX, baseband, ECC, SEP, DART, fautes
> mémoire noyau, redémarrage forcé). **Elle n'est pas exhaustive** et doit être
> enrichie et validée avec des données de réparation réelles.

---

## Tests

```bash
flutter analyze
flutter test
```

- `test/diagnostics/` : parser (JSON valide, panicString manquant, sensor array
  décimal, sensor mask hexa, JSON partiellement invalide, texte legacy…),
  analyzer (iPhone15,2 + SMC BSC failure + 0x140000 → Charging Port Flex /
  Power Button Flex, panic inconnu, moteur de règles), extraits de rapports
  réels (`test/fixtures/real/`, sources dans `SOURCES.md`) ;
- `test/services/` : service libimobiledevice avec un faux `CommandRunner`
  (parsing, erreurs lockdown, timeouts, outils absents, copie `-k`, iPhone vu
  par l'OS mais pas par usbmuxd, service USB injoignable), scan complet en mock ;
- `test/diagnostics/health_report_test.dart` : corrélation (masque SMC ×12,
  `TG0B` ×3 → confiance relevée), table capteurs, vérifications, valeurs
  « Non disponible » ;
- `test/services/device_facts_test.dart`, `command_runner_test.dart`,
  `history_store_test.dart` : plist `AppleSmartBattery`, stockage, Developer
  Mode, annulation et flux de processus réels, historique ;
- `test/l10n_test.dart` : langue système, traductions de toutes les règles,
  diagnostic, preuves, dates et export en français ;
- `test/ui/` : parcours complet en mock (scan → analyse → diagnostic → brut),
  états d'erreur, interface en français et changement de langue à chaud.

Corpus réel complet (optionnel, ~45 Mo, ignoré par git) :

```bash
./scripts/fetch_real_samples.sh            # → test/fixtures/real_full/
flutter test test/diagnostics/real_corpus_test.dart
```

Tu peux aussi déposer tes propres rapports dans `test/fixtures/real_full/`.

---

## Limitations actuelles

- **Windows : non compilé ni testé dans l'environnement de développement**
  (conteneur Linux) ; le code Dart et les textes Windows sont couverts par
  les tests, le runner C++ et le parcours réel sont à valider sur un PC. Pas
  de notification USB native sous Windows : détection par polling (2 s).
- **Données V1 à valider sur iPhone réel** : les formats d'`AppleSmartBattery`,
  `disk_usage` et `amfi` sont testés sur des sorties représentatives, pas
  encore sur ton appareil ; ce qu'iOS refuse s'affiche « Non disponible »
  (Détails techniques dans Santé).
- Un seul appareil analysé à la fois (le premier si plusieurs).
- Dépend des exécutables libimobiledevice (pas encore de FFI).
- Table capteur → pièce limitée (`TG0B`, `TG0V`, `mic1`, `prs0`) et un seul
  masque SMC précis (iPhone15,2 `0x140000`).
- Wi-Fi : iOS ne donne que l'adresse, pas l'état de la puce.
- App non signée : Developer ID / notarisation (macOS) et Authenticode / MSIX
  (Windows) restent à configurer avec ton identité.
- Linux, iOS et Android ne sont pas supportés.

## Feuille de route

**Fait en V1** : bilan de santé, batterie, stockage, corrélation et table
capteur → pièce, console en direct, crashs d'apps / Jetsam / ResetCounter,
annulation de la copie, historique local et comparaison, rapport complet,
interface FR/EN.

**V2** :
- Export PDF du rapport complet.
- Watcher USB natif sous Windows (`RegisterDeviceNotification`, VID 0x05AC).
- Dart FFI (libimobiledevice) ou framework Swift à la place des exécutables ;
  progression exacte de la copie.
- Base de connaissances : masques SMC et capteurs par modèle validés en
  atelier, versionnage et mise à jour signée.
- Interprétation détaillée de ResetCounter et des stackshots.
- Signature et notarisation automatisées en CI, installeur MSIX qui propose
  Apple Devices.
