# One More Try — arbetsregler

Ett one-tap skill game för iOS. Designspecen är
`docs/superpowers/specs/2026-09-13-one-more-try-design.md` och är auktoritativ — läs den
innan du ändrar arkitektur.

Reglerna nedan är de som är **osynliga i koden och lätta att bryta**. De flesta kom ur tre
designgranskningar och varje rad har kostat något att lära sig.

## Determinism är projektets ryggrad

Hela arkitekturen vilar på att en körning är exakt reproducerbar ur
`(simVersion, contentHash, tierID, seed, tapSteps)`. Replays, golden-tester, Practice Mode
och mönstervalideringen förutsätter alla det. Bryter du determinismen går fyra saker
sönder tyst.

**I `OMTCore` gäller undantagslöst:**

- **Importera ingenting.** Inte UIKit, inte Metal, **inte Foundation.** `Date`, `UUID`,
  `JSONDecoder` och lokalkänslig formatering är determinismrisker. Core ska kompilera på
  Linux.
- **Ingen `Set`- eller `Dictionary`-iteration.** Swifts hash-seed slumpas per process, så
  ordningen skiljer sig mellan körningar → olika flyttalsackumulering → divergens. Arrayer
  endast.
- **Inga transcendentaler** i stegloopen: `sin`, `cos`, `pow`, `exp`, `atan2`. libm är inte
  korrekt avrundad och skiljer sig i sista ulp mellan plattformar. `sqrt` är OK (korrekt
  avrundad, hårdvara).
- **`sort()` kräver total ordning** i komparatorn — `(x, surface, id)`, aldrig bara `x`.
  `Array.sort()` är inte stabil.
- **Använd inte `shuffled(using:)` eller `Double.random(in:using:)`.** De är
  stdlib-implementationsdetaljer; en Swift-version kan ändra algoritmen och ogiltigförklara
  varje lagrad replay. Egen Fisher–Yates, och `Double(x >> 11) * 0x1p-53` för
  `UInt64 → Double`. Anropa bara `next() -> UInt64` på SplitMix64.
- **`&*` och `&+`** i SplitMix64. `*` trappar vid overflow i release.
- **`step: UInt32` är sanningen, inte `t: Double`.** `1.0/240.0` är inte exakt
  representerbart, så `t += dt` driver. Klarandevillkor är `step >= 14_400`.
- **Tap lagras som klampat heltalssteg**, aldrig som rå tidsstämpel:
  `appliedStep = max(stepOf(touch.timestamp), nextUnsimulatedStep)`.
- **Både nedtryck och släpp är speldata.** Variabel hopphöjd gör tryckets längd till
  en analog axel, så en input är ett *par* av stegindex. Samma klampningsregel gäller
  båda. En replay som bara lagrar nedtryck kan inte reproduceras.

Determinismgrinden kör samma test i `-c debug` och `-c release`. Fyrar den: sluta och
hitta orsaken, höj inte toleransen.

```bash
swift test --package-path Packages/OMTKit
swift test --package-path Packages/OMTKit -c release -Xswiftc -enable-testing
```

`-enable-testing` behövs för `@testable import` och slår **inte** av optimeringarna — den
emitterar bara internal-symboler, så release-körningen testar fortfarande optimerad kod.
Det är hela poängen med grinden.

## Input

- **Endast `UITouch.timestamp`.** Den är uptime-baserad, samma klockbas som
  `CADisplayLink.timestamp`.
- **Aldrig SwiftUI `DragGesture.Value.time`** — det är en `Date`, alltså väggklocka, och
  fel bas.
- Tap-igenkännaren sitter på Metal-vyn. Icke-interaktiva SwiftUI-lager får
  `.allowsHitTesting(false)`.

## Lagerregler

Beroenden pekar bara inåt: `OMTApp → OMTRender → OMTCore`.

- **Core känner aldrig till metalagren.** Ingen valuta, inga skins, ingen leaderboard.
  Allt sådant lyssnar via `RunEventSink`.
- **`RunEventSink` är synkron.** Använd inte `AsyncStream` — hopp genom cooperative pool
  ger obunden latens och ordning som inte är deterministisk mot frames. Fan-out till
  `AsyncStream` får ske först i app-lagret.
- **Ingen analytics-SDK i Core eller Render.** Någonsin.
- **Simuleringen ligger inte på en actor.** Core är `nonisolated`, simuleringen en ren
  värdetyp. Renderaren behöver den synkront vid frame-tid.
- `public` typer får inte implicit `Sendable` — skriv det explicit på `SimState` och
  `RunEvent`.

## Rendering

- **`CAMetalLayer`, inte `MTKView`** — vi behöver `CADisplayLink.timestamp` och
  `.targetTimestamp` själva.
- **`CADisableMinimumFrameDurationClamp = true`** i Info.plist, annars klampar iOS till
  60 Hz.
- Lås bildfrekvensen med ett `CAFrameRateRange` där min = max. Ett intervall ger variabel
  takt och därmed 2,3,2,3 steg per frame, vilket läses som stutter.
- **`nextDrawable()` sist**, efter allt CPU-arbete.
- **Ackumulatorklamp:** `elapsed = min(now - lastFrameTime, 0.25)`.
- **Omstart rör ingen GPU-resurs.** Pipelines, atlas, offscreen-target och buffertringen
  skapas en gång vid start. Omstart är `state = SimState.initial(...)` och inget annat.
- **HUD under körning ritas i Metal** med bitmapfont, inte i SwiftUI. SwiftUI äger menyer.
- Pixel art: `.nearest` överallt, sampla i texelcentrum `(texelX + 0.5) / atlasWidth`,
  snappa kamera och sprites till hela virtuella pixlar **efter** interpolation, och padda
  varje atlas-sprite med 1 px ram.
- **Skeppa atlasen som folder reference**, aldrig genom asset catalog — Xcodes
  PNG-komprimering premultiplicerar och förstör paddningen.

## Innehåll

- Mönsterlängder kvantiseras till **takter**, inte sekunder.
- `minTaps`, `peakTapRate`, `robustnessMs`, `maxConsecutiveAirFlips`, `reachableExits` och
  `survivableEntries` **härleds av validatorn**. Handskriv dem aldrig.
- Validatorn är **beam search genom den riktiga simuleringen**, inte en separat solver. Två
  fysikmodeller divergerar garanterat.
- CI grindar på `robustnessMs`, inte på en genomförbarhets-boolean. "Möjligt" och
  "rättvist" är olika saker.
- **Kör om valideringen när en tiers `flipDuration` ändras.** Krävd tap-takt är
  proportionell mot `1/flipDuration`; de är inte oberoende rattar.
- Atlaspackaren är deterministisk (sortera på filnamn) och körs **aldrig som Xcode build
  phase**. Genererad atlas och index committas.

## Konst

- Assets är **CC0**. Allt annat hålls utanför repot — ett publikt repo distribuerar varje
  committad fil.
- Varje asset förs in i `Art/CREDITS.md` med källa, licens och datum.

## Tillgänglighet — inte valfritt

Kärnloopen är snabb död → blixt → omstart vid 120 Hz. Det är en anfallsriskprofil.

- Begränsa blixtfrekvens och luminansdelta. "Reducera blinkningar" ska finnas.
- `UIAccessibility.isReduceMotionEnabled` grindar shake, chromatic aberration och blixtar.
- **Koda aldrig fara med enbart färg.** Form och silhuett måste bära den.

## Ordningen

Fun-grinden ligger på dag 3, inte i slutet. Innan den är passerad: bygg inget som skulle
kastas om mekaniken visar sig tråkig. Testet för varje sak du överväger att bygga är
exakt det.

## Repo och release

- **`OneMoreTry.xcodeproj` genereras och committas aldrig.** Kör `Scripts/bootstrap.sh`
  efter klon och efter att du lagt till filer i `App/`. `project.pbxproj` ger en
  merge-konflikt i varje PR som rör en fil, vilket ett PR-baserat flöde inte tål.
- **Arbete går via pull request.** `main` är skyddad. PR:ar squash-mergas, så **PR-titeln
  blir commit-meddelandet** — det är den som måste följa konventionen, inte varje
  grencommit.
- **Commits följer Conventional Commits.** `feat:`, `fix:`, `docs:`, `chore:`, `style:`,
  `ci:`. Versionen och `CHANGELOG.md` härleds ur dem av release-please; ett slarvigt
  prefix ger fel version.
- **Releaser går via release-PR.** release-please håller en `chore(main): release X.Y.Z`
  öppen; merge av den taggar och levererar. Versionen bumpas aldrig för hand —
  `version.txt` är sanningen och skrivs av release-please.
- **Dokumentation på svenska, kod och commits på engelska.**
- `swiftformat --lint .` och `swiftlint --strict` ska gå rena innan PR. Configen ligger i
  `.swiftformat` och `.swiftlint.yml`; höj inte en tröskel utan att skriva varför i
  configen.

Detaljerna, inklusive Apple-leveransen, står i
`docs/superpowers/specs/2026-09-13-release-pipeline-design.md`.
