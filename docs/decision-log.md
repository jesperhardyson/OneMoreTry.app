# Beslutslogg

Trimkonstanter och designbeslut som bara gick att avgöra genom att spela.
Kompletterar specen, som säger *varför*; den här säger *vad vi landade på*.

---

## 2026-09-13 — Referens-tuning validerad (M2, första passet)

Testat på iPhone 17 Pro, 120 Hz, av ägaren. **Startvärdena kändes bra och behålls
oförändrade.**

| Konstant | Värde | Not |
|---|---|---|
| `flipFootprint` | 1,5 kanalhöjder | Den enda konstant spelaren faktiskt känner. Hastigheten härleds ur den. |
| `flipDuration` | 0,22 s | Ger `g = 2h/t_f²` ≈ 3306 världsenheter/s² vid `usableHeight` 80 |
| `channelHeight` | 100 | Världsenheter. Virtuell upplösning avgörs separat vid M5. |
| `characterHeight` | 20 | 20 % av kanalen — sätter golvet för svävkorridorer till ~28 % |
| `characterWidth` | 16 | |
| Härledd `scrollSpeed` | ~682 enheter/s | `flipFootprint · channelHeight / flipDuration` |
| Svårighet (prototyp) | 0,35 | Bara prototypens procedurella ratt, inte en tier |

Kodat som `Tuning.reference` i `OMTCore`.

**Styrkan i det här beviset:** en session, en spelare, och den spelaren är den som
byggde det. Specen §2 säger uttryckligen att ägaren inte kan falla på fun-grinden —
trimning är inneboende intressant oavsett om spelet är det. Det här är alltså ett
rimligt *startvärde*, inte ett godkänt grindpass.

**Grinden kvarstår:** tre icke-byggare når frivilligt 30 försök, och minst en
återvänder nästa dag utan att bli tillfrågad.

### Obesvarat

- **Är svävandet upptäckbart?** Hela §1-identiteten och tier-ordningen i §3 vilar på
  att snabb alternerande tapping känns bra och hittas utan att läras ut. Inte prövat.
- Ljud och haptik saknas fortfarande. Enligt granskningen är takt-kvantisering högsta
  känsla-per-timme i designen, så bedömningen ovan är gjord utan halva känslan.

---

## 2026-09-13 — Svävandet bär inte (M2, andra passet)

Ljud och haptik tillagda, sedan testat på enhet. Ljud och haptik fungerar.
**Svävandet är för dyrt:** "kräver väldigt många klick för att hålla den svävande."

### Vad mätningen säger

Att hålla en fjärdedels korridor vid referens-tuningen kräver **6,4 tap/s uthålligt**.
Amplituden följer `A = h·T²/(2·t_f²)`, verifierad analytiskt och numeriskt, låst av
`hoverAmplitudeMatchesTheAnalyticFormula`.

### Varför ingen trimning hjälper

Att sväva vid `r` tap/s samplar de första `1/r` sekunderna efter varje flipp. Vid
5 tap/s är det 0,20 s; en full korsning tar 0,22 s. **Samma tidsfönster.** Snärtig
flipp = mycket hastighet vunnen där; billigt svävande = lite. Samma storhet, motsatt
önskat tecken.

### Testade och förkastade

| Åtgärd | Resultat |
|---|---|
| Hastighetstak (terminalhastighet) | **Förkastad.** 41 % korridor vid 5 tap/s med *och* utan tak — det binder inte vid relevanta taptakter. Priset är 1,45× långsammare korsning. |
| Dämpning / svagare gravitation / avklingande burst | Förkastade på tidsskale-argumentet ovan, utan att implementeras. |
| Impulsläge (tap sätter hastighet) | **Implementerat bakom växlare.** Exakt √2 ≈ 1,41× billigare: 6,4 → 4,5 tap/s. Med `flipDuration` 0,30 → 3,3 tap/s. Men gravitationen pekar då alltid nedåt — ett annat spel. |

### Följdändringar i specen

- §1 påstår inte längre att svävandet är identiteten
- §3:s tier-stege toppar vid 4 luftflippar i följd, inte "ihållande"
- Ny öppen fråga §15.5: vad är hooken, när den enda mekaniskt nya delen inte bär

### Obesvarat

- Känns impulsläget bättre än att vända tecknet? Växlaren finns i trim-panelen.
- Om impulsläget vinner: är det fortfarande spelet vi vill bygga?

---

## 2026-09-13 — Impulsläget vinner, och får variabel hopphöjd (M2, tredje passet)

Testat på enhet: **impulsläget känns bättre än att vända tecknet.** Inte formellt
utvärderat mot grinden, men tydligt nog för att styra nästa steg.

Därav frågan som ledde till dagens bästa idé: *borde längre tryck ge högre hopp?*

### Mario-kapning, inte ladda-och-släpp

| Variant | Bedömning |
|---|---|
| Ladda-och-släpp (håll laddar, släpp agerar) | **Förkastad.** Lägger latens i exakt det ögonblick spelaren har 150 ms. Samma argument som mot alternativ D i det första mekanikvalet. |
| Mario-kapning (full impuls vid nedtryck, kapad fart vid tidigt släpp) | **Implementerad.** Noll extra latens, analog axel, och golvet är oförändrat. |

Hopphöjden är gravitationsbunden, inte timerbunden: när farten fallit under
kapningsnivån gör ett släpp ingenting. Låst av `holdingBeyondTheDecayPointAddsNothing`.

### Varför den här lyckas där svävandet misslyckades

Svävandet såldes in som "djup för den som hittar det" men var obligatoriska
armhävningar. Variabel hopphöjd har den egenskapen på riktigt — en nybörjare behöver
aldrig veta att tryckets längd betyder något, och nyansen kostar ingen uthållighet.

### Konsekvens för replay-formatet

Tryckets längd är nu speldata. En input är ett **par** av stegindex, inte ett. Spec §4
och CLAUDE.md uppdaterade. Hade formatet hunnit låsas som en lista av enskilda tap
hade varje lagrad replay blivit oåterkallelig i samma ögonblick mekaniken fick en
analog axel.

### Obesvarat

- `impulseCutFraction` står på 0,35 som gissning. Reglaget "hoppkapning" finns i
  trim-panelen. Fönstret där ett tryck räknas som kort är ~70 ms vid det värdet, vilket
  kan vara för snävt jämfört med hur länge en människa faktiskt håller ett tap.
- Om impulsläget blir standard: §0:s låsta beslut "gravitationsvänd" är inte längre
  sant, och specen behöver ett större omtag än en paragraf.

---

## 2026-09-13 — Båda mekanikerna behålls, som portaler mitt i banan (M2, fjärde passet)

Impulsläget kändes bättre på enhet, men i stället för att ersätta gravitationsvändningen
**behålls båda som två banläges-typer**, med Geometry Dash-modellen: portaler byter
mekanik mitt i körningen.

### Varför det är rätt

Det löser kostnaden som noterades när svävandet föll. Tier-stegen toppade vid fyra
luftflippar, så tier 5–6 kunde bara bli svårare genom snävare marginaler och högre
tempo — samma färdighet under mer press, inte en ny färdighet. Två mekaniker ger
tillbaka distinkta färdigheter att lära sig.

De är genuint komplementära, inte omskinnade versioner av varandra:

| | Gravitationsvänd | Impuls |
|---|---|---|
| Färdighet | Precision i ytväxling, luftkorrigering | Uthållig höjdkontroll |
| Analog axel | ingen | variabel hopphöjd |
| Taket | 4 luftflippar i följd | hoppkapningens nyans |

### Konsekvenser

- **Aktivt läge bor i `SimState`, inte i `Tuning`.** `Tuning.mode` är nu bara startläget.
- **Att gå in i impulsläget tvingar gravitationen nedåt.** Annars gör ett tap motsatsen
  till vad spelaren förväntar sig direkt efter bytet.
- **Innehållspartitionen är den verkliga kostnaden**, inte koden. Men beam
  search-validatorn kör mot den riktiga simuleringen, så att köra den en gång per läge
  och tagga varje mönster med vilka mekaniker det är rättvist under kostar inget extra i
  författande. Dubbelanvändbara mönster faller ut gratis.
- **Största risken är lägesförvirring.** En spelare som misslyckas för att hen trodde fel
  läge var aktivt skyller på spelet, och hela premissen är att döden alltid är ditt fel.
  Bytet måste bära på figurens utseende, paletten *och* ljudets tonhöjd samtidigt.

---

# Femte passet — identiteten (2026-09-13)

Portalerna är nu kopplade till appen: generering med säkerhetszon i `GameModel`, portalband
med lägesbärande sparrar i `ContentView`, kvintstaplad portalröst i `Audio`, dubbeltransient
i `Haptics`, palett och figurfärg per läge. Verifierat på enhet.

Och därmed kom frågan som passet egentligen handlar om: **spelet kändes som en kopia av
Geometry Dash.** Det gjorde det med rätta.

### Diagnosen

Det som läser som Geometry Dash är inte *vilka* lägen som finns, utan **arkitekturen**: en
bana som byter styrmekanik vid portaler. Gravitationsvändningen är dessutom Gravity Guy och
VVVVVV; impulsläget är Flappy Bird. Ingen av mekanikerna är vår.

Det som faktiskt är vårt — blandaren efter den fasta öppningen, det maskinverifierade
rättvisegolvet, klarande genom att överleva 60 s av oändlighet — är **osynligt under de
första 30 sekunderna**, alltså precis när en spelare avgör om spelet är en kopia.

### Beslutet

Differentieringen flyttas till presentationen, och ett tredje läge läggs till som ger
tier 5–6 en ny färdighet i stället för snävare marginaler:

1. **Perspektivkorridor för hela spelet.** Pixel art i pseudo-3D, ankrat i F-Zero och
   Star Fox. Offscreen-targeten i spec §10 gör det möjligt — 3D:n rastreras *in i* den
   lågupplösta bufferten, så perspektivet kvantiseras till pixelrutnätet av sig självt.
2. **Ett tredje läge: tuben.** Kanalen böjd till en cirkel. `y → theta` i kvartsvarv,
   `gravity: Sign → downWall: UInt8`. Radien finns aldrig i simuleringen, så inga
   transcendentaler och determinismen är orörd.

Två ansatser förkastades på vägen: att **rulla kameran 90°** i kanalen (rotationen bär
information, så en reduce-motion-grind hade gett två olika svårighetsgrader) och att göra
**dimensionsbytet till hela spelet** (en fjärde ansats, inte utredd — den står som
icke-mål, inte som förkastad).

### Rättat under passet

- Jag hävdade först att 3D bryter one-tap och determinismen. Fel. Med 1 frihetsgrad och
  kollision i väggindexrymd överlever bägge; kostnaden ligger i renderaren och
  innehållspoolen.
- Jag beslutade **hårt snitt** vid kameraramsbyte med ett latensargument lånat från
  förkastandet av charge-and-release. Det argumentet handlade om *input*, inte om kamera.
  Svepet är tillåtet: känd varaktighet, säkerhetszonen växer med det, simuleringen pausar
  aldrig, input sväljs aldrig, och kameran drivs av `state.step − modeChangedStep` så den
  aldrig hamnar i `SimState`.

### Konsekvens som redan syns i koden

`guardZone(for:)` har fått sin betydelse: **`after` är budgeten för visuell
återanskaffning.** Validatorn kan mäta `robustnessMs`, men inte hur lång tid en människa
behöver för att läsa om en ny kameraram. Zonen är därför asymmetrisk och per lägesövergång,
inte en konstant — och den står medvetet kvar som TODO till grinden har mätt den.

Observerat i prototypen: vid portalperiod 0,7 s slukade zonerna hela banan och **inga
hinder genererades alls**. Inte en bugg, men trimpanelen behöver visa antalet genererade
hinder, annars körs grinden på en tom bana utan att någon märker det.

Allt detta ligger i `docs/superpowers/specs/2026-09-13-three-modes-and-perspective-design.md`.

---

# Läge just nu (2026-09-13, sessionsslut)

## Klart och pushat

- `OMTCore`: kinematik, svept AABB, händelser, near-miss, dödsorsak, impulsläge,
  variabel hopphöjd (Mario-kapning), portaler. **19 tester gröna**, körs headless på mac.
- App: M1-prototyp med Canvas, procedurella hinder, trim-panel med reglage, syntetiserat
  ljud och haptik, press/release, **portaler helt kopplade** — generering med säkerhetszon,
  lägesbärande sparrar, portalröst, dubbeltransient, palett per läge. Kör på iPhone 17 Pro.
- Spec och beslutslogg uppdaterade till och med femte passet.
- Ny spec: `docs/superpowers/specs/2026-09-13-three-modes-and-perspective-design.md`.
  Godkänd i brainstorm, **inte byggd**, ingen implementationsplan skriven än.

## Nästa steg, i ordning

1. **Kör den riktiga grinden** — tre icke-byggare, 30 försök frivilligt, en återvänder
   nästa dag utan att bli tillfrågad. Fortfarande inte körd, och den **grindar allt i den
   nya specen**: `CLAUDE.md` säger att inget som skulle kastas byggs innan den är passerad,
   och den nya specen fördubblar konstpipelinen. Inget i specen behövs för att grinda —
   portaler och variabel hopphöjd finns redan på enhet.
2. **Visa antalet genererade hinder i trimpanelen** — annars kan grinden köras på en tom
   bana. Se femte passet.
3. **Trimma `impulseCutFraction`** — står på 0,35 som gissning. Fönstret för ett "kort"
   tryck är ~70 ms, vilket kan vara snävare än hur länge en människa faktiskt håller.
4. **Skriv implementationsplanerna** för den nya specen — fyra oberoende leveranser, var
   sin plan, i ordningen i specens §12. Först efter grinden.
5. **Skriv in undantaget i `CLAUDE.md`** — snappningsregeln för spritepositioner kan inte
   gälla geometri i perspektiv. Se specens §6. Inte gjort; kräver ett beslut om att ändra
   arbetsreglerna.

## Kommandon

```bash
swift test --package-path Packages/OMTKit          # 19 tester, ~1 ms
xcodegen generate                                  # efter nya filer i App/
xcodebuild build -project OneMoreTry.xcodeproj -scheme OneMoreTry \
  -destination 'platform=iOS,id=CBE41E7B-EEF5-5741-92FA-489E240C17C7' \
  -allowProvisioningUpdates -derivedDataPath .build/dd
xcrun devicectl device install app --device CBE41E7B-EEF5-5741-92FA-489E240C17C7 \
  "$(find .build/dd/Build/Products -name OneMoreTry.app -maxdepth 3 | head -1)"
```

Telefonen måste vara upplåst för `process launch`. `find ... -name OneMoreTry.app`
kan träffa `Debug-iphonesimulator` före `Debug-iphoneos` om båda finns i `.build/dd` —
peka på `Debug-iphoneos/OneMoreTry.app` direkt, annars misslyckas installationen med
en signaturverifieringsfel som inte nämner simulatorn.

---

## 2026-09-14 — Grinden avsiktligt hoppad över

Ägaren testade M1-prototypen (gravitationsvänd, impuls, portaler) på egen enhet igen och
tyckte den kändes bra, och bad därefter explicit att hoppa över de tre icke-byggarna:
"skit sedan i tre testarna för grinden, vi kör på ändå."

**Det här är inte grinden godkänd — det är grinden avstådd.** Samma person som byggde
spelet är inte ett giltigt urval, av samma skäl som noterades 2026-09-13 (första passet):
trimning är inneboende intressant för den som byggde den, oavsett om spelet är det för
någon annan. `CLAUDE.md`s regel ("bygg inget som skulle kastas om mekaniken visar sig
tråkig") är oförändrad som skriven arbetsregel; det här är ägaren som tar den risken
medvetet för det här projektet, inte en revidering av regeln för framtida arbete.

**Konsekvens:** väg 4 i föregående lista ("Skriv implementationsplanerna för den nya
specen") är nu olåst. Tredje läget (tuben) och perspektivrenderaren byggs utan att
mekaniken någonsin fun-testats på någon utom ägaren.

## 2026-09-14 — Tubens orbital-hold-amplitud är 4x formeln i spec §11.1, inte en testbugg

Under implementationen av `docs/superpowers/plans/2026-09-14-tube-mode-core.md` Task 2
fyrade `orbital hold amplitude matches the analytic formula` med ett mätvärde exakt 4x
det planerade `expectedAmplitude = halfPeriod² / (2 · flipDuration²)` — samma formel som
`hoverAmplitudeMatchesTheAnalyticFormula`, med `h = 1`, precis som spec §11.1 föreskriver.

**Orsaken är §3.5 självt, inte en integrationsbugg.** §3.5 medger redan att
"Enkelriktningen bryter modellen... `downWall += 1` vänder dragriktningen först när
väggen passerat figuren, alltså ungefär vartannat tap" — tapregeln är ett 4-lägesvarv
(`downWall = (downWall + 1) % 4`), inte ett 2-lägesväxel som `gravityFlip`s binära
tecken. Att komma tillbaka till samma relativa fas mot väggen tar därför 4 tap, inte 2:
den naturliga svängningsperioden är `4 · halfPeriod`, dubbelt den period en
2-lägesmodell skulle ge. Amplituden under bang-bang-acceleration skalar med periodens
kvadrat (`alpha · T² / 4` för en godtycklig halveringsperiod `T`), så den dubbla
perioden ger exakt 4x amplituden en 2-lägesmodell skulle förutsäga.

**Beslut:** tapregeln (`(downWall + 1) % 4`) är korrekt och en genuin spec-mekanik —
den ändras inte. Testformeln korrigerades till
`expectedAmplitude = alphaMagnitude · halfPeriod²` (algebraiskt samma som
`2 · halfPeriod² / flipDuration²`, den 4x-korrigerade slutna formen). Committat i
`b73c656`.

**Konsekvens:** spec §11.1s rad för detta test ("Samma formel som
`hoverAmplitudeMatchesTheAnalyticFormula`, med `h = 1`. Om den inte gäller är det inte
samma integration, och §3 är fel.") är föråldrad text och bör ändras till att namnge
4x-faktorn explicit, annars pekar spec och testkod åt olika håll för nästa läsare.
