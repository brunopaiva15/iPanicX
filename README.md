# iPaniX

Application de bureau **macOS et Windows** (Flutter, avec du natif Swift sur
macOS) qui lit les rapports de diagnostic d'un iPhone branché en USB, analyse automatiquement les **kernel panics**
(`panic-full*.ips`, `panic-base*.ips`) et affiche un diagnostic lisible.

> **100 % local.** Aucun analytics, aucune télémétrie, aucune API externe,
> aucun serveur. Les rapports sont copiés dans un dossier temporaire de
> l'ordinateur et analysés sur place.

Chaîne V0 : **iPhone USB → copie des crash reports → parsing → analyse par la
base de connaissances → diagnostic → export `.txt`.**

---

## Prérequis

| Outil | macOS | Windows |
|---|---|---|
| OS | 12 Monterey ou plus récent | Windows 10/11 x64 |
| Toolchain | Xcode 15+ | Visual Studio 2022, charge « Développement Desktop en C++ » |
| Flutter | stable (développé avec 3.47.6 / Dart 3.13) | idem |
| Pilote iPhone | intégré à macOS (usbmuxd) | app **Apple Devices** (Microsoft Store) ou **iTunes** : pilote USB + *Apple Mobile Device Service* |
| libimobiledevice | Homebrew ou embarqué | MSYS2 ou embarqué |

Outils utilisés : `idevice_id`, `ideviceinfo`, `idevicecrashreport`, `idevicepair` (libimobiledevice 1.3+).

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

iPaniX cherche les outils dans cet ordre :

1. `$IPANIX_TOOLS_DIR` ;
2. les outils embarqués dans l'app : `iPaniX.app/Contents/Resources/libimobiledevice/bin` ;
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
2. Installer [MSYS2](https://www.msys2.org/), puis dans le shell **UCRT64** :

   ```bash
   pacman -S --needed mingw-w64-ucrt-x86_64-libimobiledevice
   idevice_id.exe -l
   ```

iPaniX cherche les outils (`*.exe`) dans cet ordre : `%IPANIX_TOOLS_DIR%`,
`<dossier de iPaniX.exe>\libimobiledevice[\bin]`, `C:\msys64\{ucrt64,mingw64,clang64}\bin`,
`%ProgramFiles%\libimobiledevice`, `%LOCALAPPDATA%\Programs\libimobiledevice`, puis le `Path`.

**Outils embarqués (distribution)** — depuis le shell MSYS2 UCRT64 :

```bash
./scripts/bundle_libimobiledevice_windows.sh
```

Le script copie les 4 `.exe` et leurs DLL MSYS2 (via `ldd`) dans
`windows/libimobiledevice/` (ignoré par git). `flutter build windows` les
installe ensuite à côté de `iPaniX.exe` (fin de `windows/CMakeLists.txt`) ;
Windows charge les DLL depuis le dossier de l'exécutable.

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
flutter build macos --release      # build/macos/Build/Products/Release/iPaniX.app
flutter build windows --release    # build\windows\x64\runner\Release\iPaniX.exe (+ DLL, data\, libimobiledevice\)
```

Sous Windows, distribuer **tout le dossier** `Release\` (l'exe seul ne suffit
pas) ou l'emballer dans un installeur (MSIX, Inno Setup…).

### Mode mock (`USE_MOCK_DEVICE=true`)

Activé par `--dart-define=USE_MOCK_DEVICE=true` (ou la variable d'environnement
`USE_MOCK_DEVICE=true`). `MockIPhoneService` simule un iPhone 14 Pro et génère
au scan : 12 panics SMC connus (masque `0x140000`), 2 panics inconnus,
2 redémarrages forcés, des JetsamEvent et un ResetCounter (dont certains dans
`Retired/`). Un badge **Mock device** dans la barre d'outils permet de basculer
entre les états : connecté, deux iPhones, aucun panic, aucun iPhone, Trust
requis, verrouillé, erreur de communication, libimobiledevice absent, échec de
la copie.

---

## Fonctionnement

1. **Détection** — `idevice_id -l` toutes les 2 s ; sur macOS aussi
   immédiatement à chaque branchement/débranchement USB Apple (notification
   IOKit de `DeviceWatcher.swift` via l'EventChannel `ipanix/usb_events`).
2. **Infos appareil** — `ideviceinfo -u <UDID>` (DeviceName, ProductType,
   ProductVersion, BuildVersion). Si l'appareil n'est pas appairé,
   `ideviceinfo -s` fournit au moins le modèle ; l'UDID est toujours masqué.
3. **Erreurs** — les codes lockdown sont traduits : `-19`/`-21`/pair record →
   *Trust required*, `-17`/`-35` → *Device locked*, `-18` → appairage refusé
   (pas de relance en boucle), timeout → *Unable to communicate*, outils
   absents → *libimobiledevice unavailable*. La sortie brute n'apparaît que dans
   la section repliable *Technical details*.
4. **Copie** — `idevicecrashreport -u <UDID> -k <dossier>` : `-k` **conserve**
   les rapports sur l'iPhone. Dossier : `<temp>/iPaniX/CrashReports/<appareil>/<date>`
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
  app/        app.dart, router.dart, theme.dart (clair/sombre), app_controller.dart (état),
              host_platform.dart (textes et chemins selon l'OS)
  models/     iphone_device, device_status, diagnostic_file, panic_report,
              diagnostic_result, scan_result
  services/   iphone_service.dart (interface + erreurs)
              libimobiledevice_service.dart (réel, via CommandRunner)
              mock_iphone_service.dart, command_runner.dart, tool_locator.dart
              diagnostic_service.dart (scan → parse → analyse → synthèse)
              platform_bridge.dart (interface), macos_bridge.dart (canaux Swift),
              windows_bridge.dart (file_selector + explorer.exe)
  diagnostics/ panic_parser, panic_analyzer, diagnostic_rule, knowledge_base,
              knowledge_base_loader, report_formatter
  ui/         screens/ (home, device, panic_detail, raw_panic) · widgets/ · format.dart
assets/diagnostics/knowledge_base.json   règles de diagnostic
assets/samples/                          rapports utilisés par le mock
macos/Runner/IPhoneBridge.swift          NSSavePanel, NSOpenPanel, Finder
macos/Runner/DeviceWatcher.swift         notifications USB IOKit
macos/Runner/MainFlutterWindow.swift     fenêtre (min 900×600), branchement des bridges
windows/runner/                          runner Win32 (titre, taille, min 900×600 via WM_GETMINMAXINFO)
windows/CMakeLists.txt                   installe windows/libimobiledevice/ à côté de iPaniX.exe
scripts/                                 bundle/embed libimobiledevice (macOS, Windows), corpus réel
tool/analyze_corpus.dart                 analyse en ligne de commande d'un dossier
```

Tous les appels aux outils passent par `CommandRunner` : remplacer
`ProcessCommandRunner` par une implémentation Dart FFI ou un wrapper
C/Swift ne touche ni l'UI ni le moteur de diagnostic. `lib/diagnostics/` et
`lib/models/` sont en Dart pur (aucune dépendance Flutter).

**Distribution Windows** : pas de signature dans la V0 ; pour distribuer,
signer `iPaniX.exe` et les outils embarqués (Authenticode, `signtool`) et
fournir un installeur. Le pilote Apple (Apple Devices / iTunes) doit être
installé par l'utilisateur.

**Distribution hors Mac App Store** : la sandbox est désactivée
(`DebugProfile/Release.entitlements`) car l'app doit lancer les outils et parler
à usbmuxd ; aucun entitlement réseau en release. Pour la notarisation : signer
avec un certificat Developer ID, activer le Hardened Runtime sur la cible
Runner, puis `xcrun notarytool submit` / `xcrun stapler staple`.

---

## Design

L'interface s'inspire fortement de [Codenotch](https://github.com/vinzdg/codenotch)
(licence MIT) : surfaces noir pur, encre blanche et gris `#808080`, **jauges
circulaires** (piste translucide, arc depuis midi dans le sens horaire,
pourcentage en semi-gras dessous), barres fines de type « infobulle »,
couleurs de signal `#00FF88` / `#F2FF00` / `#FF3F00`, et une barre latérale
inspirée de sa fenêtre de réglages. Thème sombre par défaut, avec un sélecteur
Sombre / Système / Clair dans la barre latérale.

- Tokens : `lib/app/theme.dart` (`AppColors`) ;
- composants : `lib/ui/widgets/ring.dart` (`UsageRing`, `RingStat`, `BarRow`),
  `common.dart` (`SectionCard`, `Group`, `InfoRow`…), `lib/ui/shell.dart`
  (barre latérale + navigateur imbriqué) ;
- les jauges de la vue d'ensemble sont des **proportions factuelles** des
  panics trouvés (signature connue, liée au matériel, même signature), pas un
  score de santé ;
- logo : police [Orbitron](https://fonts.google.com/specimen/Orbitron)
  (SIL Open Font License, `assets/fonts/Orbitron-OFL.txt`).

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
  "recommendedActions": ["…"]
}
```

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
nombre de termes…). L'écran de diagnostic affiche les preuves (*Matched on*).
Sans correspondance : **Unknown Hardware Panic**, avec panic string, codes,
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
  (parsing, erreurs lockdown, timeouts, outils absents, copie `-k`), scan complet
  en mock ;
- `test/ui/` : parcours complet en mock (scan → analyse → diagnostic → brut) et
  états d'erreur.

Corpus réel complet (optionnel, ~45 Mo, ignoré par git) :

```bash
./scripts/fetch_real_samples.sh            # → test/fixtures/real_full/
flutter test test/diagnostics/real_corpus_test.dart
```

Tu peux aussi déposer tes propres rapports dans `test/fixtures/real_full/`.

---

## Limitations actuelles (V0)

- **Windows : non compilé ni testé dans l'environnement de développement de la
  V0** (conteneur Linux) ; le code Dart et les textes Windows sont couverts par
  les tests, mais le runner C++ et le parcours réel avec un iPhone sont à
  valider sur un PC. Pas de notification USB native sous Windows : la
  détection repose sur le polling (2 s).
- Un seul appareil analysé à la fois (le premier si
  plusieurs, avec avertissement).
- Dépend des exécutables libimobiledevice (pas encore de FFI).
- `idevicecrashreport` copie **tous** les rapports (peut prendre du temps sur un
  appareil qui en a beaucoup) ; pas d'annulation en cours de copie.
- Base de connaissances minimale ; un seul mapping précis capteur → composant.
- Seuls les kernel panics et redémarrages forcés sont analysés ; Jetsam,
  ResetCounter, stackshots sont listés mais pas interprétés.
- L'app n'a pas encore été compilée/signée pour la distribution : le Hardened
  Runtime et la notarisation restent à configurer avec votre identité.
- Interface en anglais uniquement.
- Linux, iOS et Android ne sont pas supportés.

## Pistes V1

- Remplacer les exécutables par Dart FFI (libimobiledevice) ou un framework
  Swift dédié ; annulation et progression précises de la copie.
- Enrichir la base : mappings sensor mask / missing sensors par modèle,
  signatures validées en atelier, versionnage et mise à jour signée de la base.
- Interpréter ResetCounter, JetsamEvent, panic-base/socd, watchdogs.
- Historique local des appareils et comparaison entre scans.
- Export PDF, localisation FR/EN, fenêtre plus native (NSVisualEffectView,
  barre de titre unifiée).
- Signature Developer ID, Hardened Runtime, notarisation automatisée en CI ;
  signature Authenticode et installeur MSIX sous Windows.
- Watcher USB natif sous Windows (`RegisterDeviceNotification`, VID 0x05AC).
