# One More Try — releasepipeline

**Status:** Godkänd design, klar för implementationsplan.
**Ursprung:** Porterar releaseflödet från Tågradar (`sebdanielsson/tagradar`) till det här repot.

Repot har idag ingen CI alls: allt committas direkt på `main`, `OneMoreTry.xcodeproj` är
incheckat trots att det genereras av XcodeGen, och `CLAUDE.md` lovar en determinismgrind i CI
som inte finns. Den här specen beskriver måltillståndet: PR-baserat arbete, en workflow som
grindar allt, versioner ur Conventional Commits, och en Apple-leverans som ligger på plats
färdig att slås på.

---

## 1. Mål och avgränsning

**Mål**

- Varje push och PR grindas av ett `verify`-jobb: format, lint, determinismtester, app-bygge.
- `main` är skyddad; arbete går via pull requests.
- Versioner och `CHANGELOG.md` härleds ur commit-meddelanden av release-please.
- Varje push till `main` kan producera ett TestFlight-bygge; en mergad release-PR kan
  arkivera, ladda upp och skicka in till App Store Review.
- Ingenting byggs eller signeras på någons Mac.

**Utanför scope**

Skapa app-posten i App Store Connect, generera certifikat, lägga in secrets, och ta
skärmbilder. Allt fyra kräver ägarens credentials och görs för hand när appen ska släppas.

**Nuläge som specen tar hänsyn till**

| Förutsättning | Värde |
|---|---|
| Repo | `jesperhardyson/OneMoreTry.app`, publikt, default-branch `main` |
| Bundle-ID | `se.hardyson.OneMoreTry` |
| Apple-team | `4WZU5V58ZG` — **samma som Tågradar** |
| App-post i ASC | Finns inte än |
| Testytor | SwiftPM-paketet `Packages/OMTKit`. Inget test-target i app-projektet |
| Testramverk | swift-testing, med `@testable import OMTCore` |
| Dokumentationsspråk | Svenska. Kod, kommentarer och commits: engelska |

---

## 2. Filer som tillkommer

```
.github/workflows/ci.yml                    verify → testflight / release-please → appstore
.github/workflows/codeql.yml                swift (manuellt bygge) + actions
.github/CODEOWNERS
.github/PULL_REQUEST_TEMPLATE.md
.github/ISSUE_TEMPLATE/bug_report.yml
.github/ISSUE_TEMPLATE/feature_request.yml
.github/renovate.json
.swiftformat
.swiftlint.yml
release-please-config.json
.release-please-manifest.json
version.txt
CHANGELOG.md                                skapas av första release-PR:en
ExportOptions.plist                         destination=upload (TestFlight)
ExportOptions-export.plist                  destination=export (App Store via fastlane)
fastlane/Appfile
fastlane/Fastfile
fastlane/metadata/en-US/*.txt
fastlane/metadata/review_information/notes.txt
Scripts/bootstrap.sh
Scripts/ci/write-asc-key.sh
Scripts/ci/import-signing-certificate.sh
Scripts/ci/simulator-destination.sh
Scripts/ci/release-notes.sh
docs/release.md
```

Filer som ändras: `.gitignore`, `project.yml`, `CLAUDE.md`.
Filer som tas bort ur git: `OneMoreTry.xcodeproj/**`.

---

## 3. `ci.yml`

En workflow, fyra jobb. `verify` grindar de andra tre.

```text
push / PR ──▶ verify (format, lint, determinism, app-bygge)
                 │
   push till main┼──▶ testflight     archive → upload (build = run number)
                 │
                 └──▶ release-please  håller "chore(main): release X.Y.Z"-PR:en aktuell
                          │
        merge av PR ──────┴──▶ tagg vX.Y.Z + GitHub release
                                  └──▶ appstore  archive → upload → metadata → submit
```

Triggers, `concurrency` och `permissions` kopieras oförändrade från Tågradar: PR-körningar
avbryts av nya pushar, main-körningar nycklas på commit så ingen commit i en snabb serie
tappas, och `testflight`/`appstore` har egna grupper så uppladdningar sker en i taget.

### 3.1 `verify`

`runs-on: macos-26`, timeout 45 min.

1. Parallellt på samma runner: `swiftformat --lint .`, `brew install swiftlint` +
   `swiftlint --strict --reporter github-actions-logging`, `brew install xcodegen`.
2. **Determinismgrind** — samma testsvit i två konfigurationer:
   - `swift test --package-path Packages/OMTKit`
   - `swift test --package-path Packages/OMTKit -c release -Xswiftc -enable-testing`

   Flaggan behövs för att testerna använder `@testable import`; SwiftPM vägrar annars köra
   release-konfigurationen. Den slår inte av optimeringarna — den emitterar bara
   internal-symboler — så release-körningen testar fortfarande optimerad kod, vilket är hela
   poängen med grinden.
3. `xcodegen generate --quiet`.
4. `xcodebuild build` mot en simulator som `Scripts/ci/simulator-destination.sh` löser ut vid
   körtid, med `CODE_SIGNING_ALLOWED=NO`, piped genom `xcbeautify`.

Inget `test` i `xcodebuild`-anropet: app-målet har inget test-target. När ett tillkommer läggs
`test` till i samma kommando.

### 3.2 `testflight` och `appstore`

Kopieras från Tågradar med tre ändringar:

- **Ingen xcconfig alls.** Tågradar behöver `Config/Secrets.xcconfig` för att baka in
  Trafikverkets API-nyckel och för att Sebastian bygger under ett annat Apple-team. Här finns
  varken hemligheter i bygget eller en andra utvecklare, och `project.yml` har redan rätt team
  hårdkodat — så `Scripts/bootstrap.sh` kontrollerar bara att XcodeGen finns och genererar
  projektet, och CI-jobben behöver inget förberedande steg alls. Behöver någon bygga under ett
  annat team räcker `xcodebuild … DEVELOPMENT_TEAM=XXXXXXXXXX`, vilket dokumenteras i
  `docs/release.md`.
- Projekt- och schemanamn `OneMoreTry`, arkiv `OneMoreTry.xcarchive`, ipa `OneMoreTry.ipa`.
- **Grinden** (se 3.3).

`testflight` versionsstämplar med `MARKETING_VERSION=$(cat version.txt)` och
`CURRENT_PROJECT_VERSION=${{ github.run_number }}`. `appstore` tar versionen ur
release-please-outputen istället, checkar ut taggen, och kör `fastlane release`.

### 3.3 Grinden mot Apple

Båda Apple-jobben villkoras på en repo-variabel utöver sina vanliga villkor:

```yaml
if: >-
  github.repository == 'jesperhardyson/OneMoreTry.app' &&
  vars.APPLE_DELIVERY == 'true' &&
  <jobbets vanliga villkor>
```

Fram tills app-posten finns är `vars.APPLE_DELIVERY` osatt och jobben hoppas över utan att
misslyckas. Aktivering är två handgrepp i GitHub-inställningarna — lägg in secrets, sätt
variabeln till `true` — och kräver ingen kodändring. Repository-villkoret hindrar forkar från
att försöka ladda upp.

### 3.4 Signering

Samma Apple-team som Tågradar betyder att **de pinnade certifikaten och ASC-nyckeln
återanvänds rakt av**. Samma `.p12`-filer, samma `.p8`, bara inklistrade som secrets i det här
repot. Inga nya certifikat skapas och inget av kontots certifikatslots förbrukas.

`Scripts/ci/import-signing-certificate.sh` kopieras oförändrat. Resonemanget bakom pinningen
gäller identiskt här: `-allowProvisioningUpdates` synkar varje signeringsstil som projektet
refererar, inklusive Development-stilen Debug-konfigurationen använder, så både
distributions- och utvecklingscertifikatet måste pinnas.

---

## 4. Versionering

`release-please-config.json` kopieras från Tågradar oförändrad så när som på `extra-files`,
som pekar på det här repots `project.yml`. `release-type: simple`, taggar `vX.Y.Z`,
`bump-minor-pre-major` och `bump-patch-for-minor-pre-major` — en `feat:` ger alltså patch-bump
så länge versionen är `0.x`.

| Fil | Roll |
|---|---|
| `version.txt` | Sanningen. Läses av `testflight`-jobbet. Startvärde `0.1.0` |
| `.release-please-manifest.json` | `{".": "0.1.0"}` |
| `project.yml` | `MARKETING_VERSION: 0.1.0 # x-release-please-version` |
| `CHANGELOG.md` | Genereras av release-please |

`CURRENT_PROJECT_VERSION` sätts av CI till `github.run_number` och committas aldrig — det gör
att TestFlight-bygget och App Store-bygget aldrig kan tvista om vem som äger build-numret.

**Följd för arbetssättet:** commits på `main` måste följa Conventional Commits från och med nu.
PR:ar squash-mergas och PR-titeln blir commit-meddelandet. Befintlig historik lämnas orörd;
release-please läser bara framåt från senaste taggen, och det finns ingen än.

`style:` läggs till i `changelog-sections` som dold sektion, eftersom formatsvepet i avsnitt 7
använder den typen.

---

## 5. fastlane och App Store-metadata

`Appfile` och `Fastfile` porteras med `app_identifier("se.hardyson.OneMoreTry")` och två
medvetna avvikelser från Tågradars Fastfile:

- **Ingen `screenshots_path`, och `overwrite_screenshots: false`.** Tågradars inställning
  raderar skärmbilderna i App Store Connect när den körs mot en tom mapp. Skärmbilder laddas
  upp för hand första gången; när `fastlane/screenshots/` har innehåll kan avvikelsen tas bort.
- **Bara `en-US`.** Spelet har nästan ingen text. `sv` är en mappkopia bort om det behövs.
  `Scripts/ci/release-notes.sh` skriver `release_notes.txt` i varje locale-mapp som har en
  `description.txt`, så den fungerar oförändrad oavsett antal språk.

`content_rights_contains_third_party_content: true`, eftersom grafiken är CC0 från andra
upphovspersoner. Värdet måste matcha Content Rights-svaret i App Store Connect.

`fastlane/metadata/en-US/privacy_url.txt` skrivs som en platshållare och **måste** peka på en
riktig integritetspolicy innan första inskickningen. Åldersgräns och App Privacy-formuläret går
inte att sätta via API-nyckeln och besvaras för hand i App Store Connect en gång.

---

## 6. Repo-hygien

**`codeql.yml`** porteras med matrisen `swift` (manuellt bygge: XcodeGen + `xcodebuild`) och
`actions` (buildless). Ingen `python`-matris — det finns ingen Python i repot. Motiveringen
till avancerad setup är densamma: `autobuild` hittar ingen incheckad `.xcodeproj` och skulle
falla tillbaka på `swift build` i `Packages/OMTKit`, vilket lämnar hela app- och renderlagret
oanalyserat.

**`renovate.json`** kopieras oförändrad — automerge för minor/patch på beroenden som inte är
`0.x`, semantiska commits påslagna.

**`CODEOWNERS`:** `* @jesperhardyson`.

**PR-mallens checklista** skrivs om mot `CLAUDE.md` istället för Tågradars:

- Determinismgrinden grön i både debug och release
- Inga nya `import` i `OMTCore`
- Blixtar, shake och chromatic aberration bakom `isReduceMotionEnabled`
- Nya assets införda i `Art/CREDITS.md` med källa, licens och datum
- `swiftformat` och `swiftlint` rena

**Issue-mallar** porteras med spelspecifika fält (enhet + iOS-version, tier och seed istället
för tågnummer).

**`.swiftformat`** kopieras oförändrad så när som på `--exclude`. **`.swiftlint.yml`** får
`included: [App, Packages/OMTKit/Sources, Packages/OMTKit/Tests]`.

### Inställningar i GitHub (inte filer)

1. Settings → Actions → General → **Allow GitHub Actions to create and approve pull requests**.
   Utan den kan release-please inte öppna release-PR:en.
2. Branch protection på `main`: kräv pull request, kräv statuskontrollen `Verify`, kräv linjär
   historik.
3. Miljöerna `testflight` och `app-store` skapas automatiskt vid första körningen. Ägaren kan
   lägga sig själv som required reviewer på `app-store`.

Punkt 1 och 2 ändrar repots inställningar och görs efter uttryckligt godkännande.

---

## 7. Engångsarbete

Tre commits, i den här ordningen:

1. **`chore: generate the Xcode project instead of committing it`** —
   `git rm -r --cached OneMoreTry.xcodeproj`, lägg `*.xcodeproj` i `.gitignore`, lägg till
   `Scripts/bootstrap.sh`. Motivet: `project.pbxproj` genererar merge-konflikter i varje PR som
   rör filer, vilket är precis vad ett PR-baserat flöde inte tål.
2. **`style: apply swiftformat and swiftlint`** — formatsvepet över befintlig kod, i en egen
   commit så att den inte döljer riktiga ändringar i historiken. `swiftformat --lint` och
   `swiftlint --strict` kommer att fyra på oformaterad kod, så svepet måste ske innan `verify`
   kan bli grön.
3. **`ci: add the release pipeline`** — allt övrigt, plus `CLAUDE.md`-avsnittet.

`CLAUDE.md` får ett kort nytt avsnitt: projektet genereras av XcodeGen och committas aldrig,
commits följer Conventional Commits, releaser går via release-PR, och determinismgrinden ligger
i `verify` (vilket gör det befintliga påståendet sant).

`docs/release.md` skrivs på svenska efter Tågradars struktur: flödesdiagram,
commit-konventionen, engångssetup (Apple, secrets, GitHub-inställningar), vardagsbruk, och hur
man slår på `APPLE_DELIVERY`.

---

## 8. Verifiering

Pipelinen kan inte testas fullt ut utan att köras, men följande går att kontrollera:

| Vad | Hur |
|---|---|
| Workflow-syntax | `actionlint` lokalt, och att `verify` blir grön i den första PR:en |
| Determinismgrind | Båda `swift test`-kommandona körs lokalt innan PR:en öppnas |
| App-bygget | `Scripts/bootstrap.sh` + `xcodebuild build` lokalt |
| Formatsvepet | `swiftformat --lint .` och `swiftlint --strict` går rena |
| release-please | Konfigurationen validerar mot sitt `$schema`; första release-PR:en öppnas efter första conventional commit på `main` |
| Apple-jobben | Hoppas över så länge `vars.APPLE_DELIVERY` är osatt — kontrolleras i körningens sammanfattning |

Apple-jobben kan i praktiken inte verifieras förrän app-posten finns. Det är en accepterad
risk: de är portade från en pipeline som är i produktion, mot samma team och samma certifikat,
och den enda otestade delen är appens egen identitet.
