# One More Try — Designspec

**Status:** Komplett designspec. Ersätter Del 1-utkastet 2026-09-12.
**Reviderad efter tre oberoende granskningar** (speldesign, Swift/iOS/Metal-arkitektur,
adversariell risk/YAGNI). Fynd som ändrade designen är noterade i marginalen som
`[G-design]`, `[G-teknik]`, `[G-risk]`.

**Plattform:** iOS. Xcode 26.6, Swift 6.3.3.

---

## 0. Vad spelet är

Ett one-tap skill game. Figuren springer automatiskt åt höger i en kanal med golv och
tak. Ett tap vänder gravitationen. Hinder växer ur golvet och taket. Du dör vid
kontakt och startar om omedelbart.

Känslan vi designar mot: *"jag ska bara försöka en gång till."*

### Låsta beslut (valda av ägaren)

| Beslut | Val |
|---|---|
| Kärnmekanik | Gravitationsvänd, ett tap, flipp tillåten i luften |
| Struktur | 6 svårighetstiers, var och en oändlig, klarad genom att överleva 60 s |
| Teknik | SwiftUI + egen Metal-renderare, ingen spelmotor |
| Estetik | Pixel art med animerad figur |
| Konstkälla | Blender-renderade sprites från CC0-riggade modeller (Kenney) |
| Repo | Publikt: `github.com/jesperhardyson/OneMoreTry.app` |

---

## 1. Flippen i luften — och vad den inte är

`[G-design]` `[M2-fynd]` Gravitationsvändningsrunner var en av de mest klonade
mobilgenrerna 2011–2015 (Gravity Guy, Run, Wave Wave). Mekaniken i sig är inte ny.

**Tidigare version av det här avsnittet påstod att svävandet — att hålla en linje mitt
i kanalen med snabb alternerande tapping — var spelets identitet. Det påståendet är
falsifierat genom spel på enhet 2026-09-13 och är struket.**

### Varför det inte bär

Att hålla en korridor på en fjärdedel av kanalen vid referens-tuningen kräver
**6,4 tap i sekunden, uthålligt.** Det är inte en trimningsfråga:

| `flipDuration` | 15 % korridor | 25 % | 40 % |
|---|---|---|---|
| 0,18 | 10,1/s | 7,9/s | 6,2/s |
| **0,22** | 8,3/s | 6,4/s | 5,1/s |
| 0,30 | 6,1/s | 4,7/s | 3,7/s |
| 0,35 | 5,2/s | 4,0/s | 3,2/s |

Amplituden följer `A = h·T²/(2·t_f²)`, verifierad både analytiskt och numeriskt och
låst av ett test i `OMTCoreTests`.

**Den strukturella orsaken:** en gravitationsvändning sätter accelerationens *tecken*,
så position är dubbelintegralen av spelarens input. Kostnaden att hålla en korridor
skalar därför som `1/T²`. Flappy Birds tap sätter hastigheten direkt — en integration
istället för två — vilket är varför 2–3 tap i sekunden räcker där.

**Och varför ingen trimning löser det:** att sväva vid `r` tap i sekunden samplar exakt
de första `1/r` sekunderna av accelerationen efter varje flipp. Vid 5 tap/s är det
0,20 s. En full kanalkorsning tar 0,22 s. Det är samma tidsfönster. Snärtig flipp
betyder mycket hastighet vunnen i det fönstret; billigt svävande betyder lite. Samma
fysiska storhet, motsatt önskat tecken.

Det utesluter hela klassen av åtgärder, inte bara en av dem. Ett hastighetstak testades
numeriskt och gav 41 % korridor vid 5 tap/s både med och utan tak, till priset av en
1,45× långsammare korsning — det binder helt enkelt inte vid de taptakter som spelar
roll. Dämpning, svagare gravitation och en avklingande burst faller på samma argument.

### Vad flippen i luften fortfarande är

**Ett korrigeringsverktyg, inte en uthållig teknik.** En eller två vältajmade flippar
för att justera en bana mitt i luften är billigt, skickligt och roligt. Det är bara det
ihållande som är armhävningar. Mekaniken behålls oförändrad; det är anspråket som
skrivs ned.

### Impulsläget

`ControlMode.impulse` finns implementerat bakom en växlare: tap sätter vertikal
hastighet direkt istället för att vända accelerationens tecken. Det ger **exakt √2 ≈
1,41 gånger billigare svävande** — 6,4/s ner till 4,5/s för en fjärdedels korridor, och
3,3/s i kombination med `flipDuration` 0,30.

Reell förbättring, men det är ett annat spel: gravitationen pekar alltid mot golvet, och
taket nås genom upprepad tapping snarare än genom en vändning. Utvärderas under M2.
Standardläget är fortfarande `gravityFlip`.

## 2. Lagermodellen

Endast **lager 1** är i scope. Lager 2–4 designas förberedande, implementeras inte.

| Lager | Innehåll | Grind |
|---|---|---|
| **1. Kärnan** | Mekanik, tiers, mönsterbibliotek, Practice Mode, personbästa | Se nedan |
| 2. Poängjakt | Bredare eskalering, delbara replays | 5 testspelare når frivilligt 20+ försök/session |
| 3. Meta | Unlocks, skins, valuta, monetisering | Retention dag 1 mätbar — kräver analytics från lager 1 |
| 4. Socialt | Daglig seed, leaderboard, streaks | Kräver publik |

### Grinden för lager 1

`[G-design]` Den ursprungliga grinden — "ägaren spelar 50 försök utan att bli uttråkad" —
**kan strukturellt inte producera ett nej**. Ägaren trimmar, spelar inte; trimning är
inneboende intressant oavsett om spelet är det.

**Ersättning:** tre icke-byggare når frivilligt 30 försök, **och minst en återvänder
nästa dag utan att bli tillfrågad.** Den andra halvan är den bindande.

### Arkitektonisk konsekvens

Kärnan känner aldrig till metalagren. Gameplay-koden vet inte att skins eller valuta
finns och anropar ingen leaderboard. Metasystem hängs på som observatörer via
`RunEventSink`.

`[G-risk]` Samma disciplin gäller **infrastruktur**: för varje sak som byggs, fråga *vad
skulle kastas om mekaniken visar sig tråkig på dag 3?* Kastas den — bygg den efter dag 3.

---

## 3. Körningens struktur

### Fast öppning, shufflad svans

`[G-design]` Ursprungsdesignen tog pelaren "precision och memorering" från Geometry Dash
och strukturen "shufflade pooler + 60 s" från Super Hexagon. De är oförenliga — man kan
inte memorera ett shufflat flöde.

**Lösning:** varje försök på en tier börjar med en **identisk, handkomponerad öppning på
~20 sekunder**. Därefter tar shufflern över. Öppningen är den del spelaren ser 200 gånger
och därmed där memorering faktiskt bor; svansen ger klockpressens oförutsägbarhet.
Kostar strukturellt ingenting — shufflern startar vid `step = 4800`.

### Klarandevillkor och rampen

Klarad tier = överlev 60 s (`step >= 14_400`).

`[G-design]` **Matematiken styr innehållsdesignen.** 60 s vid ~2,5 s per mönster är ~24
mönster. Med överlevnad `q` per mönster blir `P(klara) = q²⁴`:

| Mål | Krävd `q` |
|---|---|
| Klaras inom ~40 försök | 0,86 |
| Klaras inom ~10 försök | 0,91 |

Alltså: **när en tier klaras måste dess enskilda mönster kännas nästan lätta.** Och ett
enda mönster med `q = 0,5` sänker hela tierns klarandefrekvens mot noll oavsett de andra
23. **Tier-tuning gäller poolens maximum, inte dess medelvärde.**

**Rampen är obligatorisk.** Konstant svårighet i 60 s är attrition utan dramatisk form.
Scrollhastigheten ökar 25–35 % linjärt över de 60 sekunderna, med hörbara och synliga
milstolpar vid 15/30/45 s. Utan ramp: sänk klarandevillkoret till 40 s.

### Tier-ordningen är mekanisk

`[G-design]` Svävandet gör svårigheten bimodal — ythoppstajming och rytmisk höjdhållning
är olika motoriska färdigheter. Med fel ordningsvariabel blir det en klippa sent i
stegen. Ordningsvariabeln är därför **maximalt antal på varandra följande flippar i
luften** som ett mönster kräver:

| Tier | Max luftflippar i följd | Roll |
|---|---|---|
| 1 | 0 | Ren ytväxling. Lär ut grundflippen. |
| 2 | 1 | En vältajmad luftflipp. **Lär ut svävandet utan text.** |
| 3 | 2 | Dubbelkorrektion |
| 4 | 3 | |
| 5 | 4 | |
| 6 | 4, med snävare marginaler och högre tempo | Taket är 4 — inte "ihållande". Se §1. |

Detta gör ordningen monoton och mekaniskt beräkningsbar istället för intuitiv. Luftflippen
lärs ut av geometri i tier 2, aldrig av en textruta.

`[M2-fynd]` Stegen toppar vid fyra flippar i följd. Bortom det blir det uthållighet snarare
än skicklighet (§1), och de sista tiersen måste därför bli svårare genom **snävare
marginaler och högre tempo** istället för genom fler flippar. Det gör tier 6 till en
tuningfråga, inte en ny färdighet — vilket är sämre för progressionskänslan och är en
verklig kostnad för fyndet.

`[G-design]` 6 tiers, inte 8. Åtta med disjunkta pooler är en innehållsfälla.

### Practice Mode

`[G-design]` En spelare som fastnar på 38 s måste annars spela om 38 sekunder löst
innehåll för ett försök på sekund 39. Det är designens största tidsskatt och den
troligaste orsaken att sluta.

Eftersom en körning är `(tierID, seed, [tapSteps])` går det att **deterministiskt spola
fram**: spela upp en lagrad tap-sekvens i hög hastighet till `step = N`, lämna sedan över
kontrollen. "Starta mig tio sekunder före mitt rekord." Ingen ny simuleringskod, inget
checkpointsystem, inget nytt sparformat. Determinismen hade redan betalat för funktionen.

### Vad spelaren ser under körningen

`[G-design]` "Närmast hittills"-markören låg ursprungligen i lager 2. Den är **lager 1:s
hela progressionssystem** — utan den är 40 misslyckade försök inte en berättelse utan 40
identiska misslyckanden, och lager 1:s grind faller av fel skäl.

I lager 1, synligt under spel: förfluten tid, och en markör vid personbästa för tiern som
du passerar. Vid död: tiden, deltat mot bästa, och inget annat. Ingen meny, ingen
bekräftelse.

**Near-miss-återkoppling** är genrens mest motiverande händelse och saknades helt: när ett
hinder klaras inom N pixlar, en 60–100 ms effekt (kort tick, haptisk transient, kort
visuell puls). Det är ögonblicket spelaren lär sig toleranserna och känner sig skicklig.

### Onboarding

Ingen tutorial, aldrig ett tutorial-läge. Tier 1 öppnar med ett golvhinder som inte kan
passeras utan flipp, föregånget av ett enda ord (`TAP`) som visas en gång och aldrig mer.

**Tier 1:s svårighetsmål:** en förstagångsspelare överlever 20–30 s på sitt allra första
försök och klarar tier 1 på under 5 försök. Super Hexagons berömda brist är att dess
lättaste läge dödar en nykomling på fem sekunder; det överlevde på Cavanaghs rykte.

---

## 4. Simuleringen

```swift
public struct SimState: Sendable {
    public var step: UInt32        // sanningen. t härleds för visning.
    public var y, vy: Double
    public var gravity: Sign
    public var alive: Bool
}
```

### Beslut

**Fast tidssteg 1/240 s.** `[G-teknik]` Skälet är **inputkvantisering**, inte tunnling:
digitizern samplar ~120 Hz (±8,3 ms, oundvikligt). Vid 120 Hz sim blir stegkvantiseringen
lika stor och fördubblar det totala inputfelet (√(8,33²+8,33²) ≈ 11,8 ms); vid 240 Hz
(√(8,33²+4,17²) ≈ 9,3 ms) slutar simuleringen vara en meddominant felkälla. Över 240 Hz
vinner man inget — digitizern är golvet.

**Svept AABB-kollision** (~30 rader). `[G-teknik]` Med diskret punkttest tunnlar ett 4 px
hinder vid 120 Hz. Att köpa 2× simuleringstakt för att kompensera för ett saknat test är
fel byte; med svept test är stegtakten ett fidelitetsval, inte ett korrekthetsval.

**`step: UInt32` är sanningen.** `1.0/240.0` är inte exakt representerbart, så
`t += dt` driver. Klarandevillkor är `step >= 14_400`, aldrig `t >= 60.0`.

**Ingen fysikmotor.** `[G-teknik]` Korrigerad motivering: Box2D (bakom SKPhysicsBody) *är*
deterministisk vid fast tidssteg på samma bygge. Den riktiga invändningen är att man inte
*kontrollerar* tidssteget — det är kopplat till renderloopen — och inte kan köra headless
i 1000× realtid.

**Interpolation mellan states** behålls som försäkring, inte som driftmaskineri: 240 är
exakt multipel av både 60 och 120, så `alpha` är 0 i stabilt tillstånd. Den tjänar in sig
vid tappad frame, termisk nedklockning och display-link-jitter. **Interpolera aldrig över
en döds- eller omstartsgräns.**

**Ackumulatorklamp (obligatorisk):** `elapsed = min(now - lastFrameTime, 0.25)`. Utan den
simuleras tiotusentals steg i en frame vid återkomst från bakgrunden — garanterad hängning
följd av död.

### Determinism: de verkliga riskerna

`[G-teknik]` `Double` är **inte** problemet. IEEE 754 `+ - * /` och `sqrt` är korrekt
avrundade och bitidentiska mellan arkitekturer. Swift gör ingen fast-math, ingen
FMA-kontraktion, och debug/release kan inte divergera för ren aritmetik.

De faktiska riskerna:

| Risk | Varför det bryter replays | Regel |
|---|---|---|
| Swifts per-process slumpade hash-seed | `Set`/`Dictionary`-iteration ger olika ordning per körning → olika ackumuleringsordning | **Ingen `Set`/`Dictionary`-iteration i OMTCore.** Arrayer endast. |
| `Array.sort()` är inte stabil | Lika `x` sorteras olika mellan bygg/storlekar | Total ordning i komparatorn: `(x, surface, id)` |
| `shuffled(using:)`, `Double.random(in:using:)` | Stdlib-implementationsdetaljer; en Swift-version kan ändra algoritmen och ogiltigförklara varje lagrad replay | **Egen Fisher–Yates, egen `UInt64 → Double`** (`Double(x >> 11) * 0x1p-53`). Anropa bara `next() -> UInt64`. |
| Transcendentaler (`sin`, `cos`, `pow`, `exp`) | libm är inte korrekt avrundad, skiljer sig i sista ulp mellan plattformar | **Förbjudna i stegloopen.** `sqrt` är OK. |
| Ackumulerad `t: Double` | Drift | `step` är sanningen |
| `*` istället för `&*` i SplitMix64 | Overflow-trap i release | `&*`, `&+` genomgående |

**Determinismgrind i CI** (ersätter fixed-point som öppen fråga): hasha hela
`SimState`-trajektorian via `Double.bitPattern` var N:e steg till en FNV-1a-checksumma,
lagra som fixtur, kör i debug, release, på arm64-simulator och på fysisk enhet. En
eftermiddags arbete som ger **svaret** istället för en gissning. Fixed-point revideras
bara om grinden någonsin fyrar.

### Körningens post

```
(simVersion: UInt16, contentHash: UInt64, tierID, seed: UInt64, tapSteps: [UInt32])
```

`[G-teknik]` `contentHash` hashar packad mönsterdata + trimkonstanter, bakas in av
`Tools/`. En replay vars `simVersion`/`contentHash` inte matchar bygget **avvisas högljutt,
spelas inte upp**. Utan detta testar golden-replay-sviten fel sak medan den fortfarande
passerar.

**Formuleringen "fuskresistent" stryks.** Tupeln bevisar att en körning är *fysiskt
giltig*, inte att en människa producerade den — och vi bygger själva en solver som
emitterar optimala tap-sekvenser. Rätt formulering: **manipulationssäker, botsårbar.**
Botförsvar är inputstatistik (mänsklig tap-jitter har karakteristisk fördelning), en
lager-4-fråga.

### Inputkvantiseringsregeln

`[G-teknik]` Denna saknades helt och bryter replay-troheten före första kodraden.

- `UITouch.timestamp` är hårdvarusampeltid i sekunder sedan uppstart — samma klockbas som
  `CADisplayLink.timestamp`. **Enda användbara tidsstämpeln.**
- **SwiftUI `DragGesture.Value.time` är en `Date`** — väggklocka, fel bas. Får inte
  användas för spel-tappet.
- En touch som anländer under frame *N* har en tidsstämpel *tidigare* än steg som redan
  simulerats. Regel: **klampa framåt.**

```
appliedStep = max(stepOf(touch.timestamp), nextUnsimulatedStep)
stepOf(t)   = UInt32(((t - runStartUptime) * 240.0).rounded(.down))
```

**Replayen lagrar det klampade stegindexet, aldrig den råa tidsstämpeln.** Härleds steget
vid uppspelning beror det på originalkörningens frame-gränser, som inte är reproducerbara.

Latens: ~35–50 ms golv, 50–80 ms typiskt. Spelare anpassar sig till konstant latens men
inte till jitter — så låst bildfrekvens prioriteras över låg medellatens. Inputlatens
påverkar **inte** replay-troheten, eftersom tappet tidsstämplas av digitizern.

---

## 5. Innehållsmodellen

### Ett delat bibliotek, inte en mapp per tier

`[G-design]` Naiv räkning: ~24 mönster per klarandekörning, och entry/exit-partitionen
halverar effektiv pool (du behöver ~24 tillgängliga från *varje* tillstånd) → ~48 per
tier → 240–290 totalt. Det är inte en innehållsplan, det är ett innehållsproblem.

**Lösning, vilket är vad Super Hexagon faktiskt gör:** ett delat, svårighetstaggat
bibliotek. Varje tier är en **query** över biblioteket med en hastighets- och
tempo-skalär, inte en mapp. Samma mönster i tier 2 och tier 5 är olika mönster i handen.
**Mål: ~55–70 mönster totalt** för 6 tiers, med 20–30 admissibla per tier och tillstånd.

Upprepning **mellan försök är feature** (det är så memorering fungerar). Upprepning
**inom ett försök är bugg** (den exponerar generatorn). Fast öppning + shufflad svans
tjänar båda.

### Mönsterformat

`[G-risk]` Under prototypfasen: **mönster som Swift-arrayer i kod** — kompilatorkontrollerat,
noll avkodning, refaktoreras med simuleringen. JSON-formatet införs vid M4 när
författandet börjar och hot reload faktiskt betalar sig.

```swift
struct Pattern {
    let id: PatternID
    let bars: Int                  // 1, 1.5 eller 2 takter — se §7
    let obstacles: [Obstacle]      // surface: .floor|.ceiling, x, w, h i världsenheter
    // Härledda av validatorn, aldrig handskrivna:
    let minTaps: Int
    let peakTapRate: Double
    let robustnessMs: Double
    let maxConsecutiveAirFlips: Int
    let reachableExits: [PhaseBox] // (y, vy, gravity) bland överlevande
    let survivableEntries: [PhaseBox]
}
```

### Skarvar: uppmätta, inte deklarerade

`[G-design]` `[G-risk]` Båda granskarna fann oberoende samma fel: **`entryState`/`exitState`
som tvåvärdad enum är en falsk modell.** Flipp i luften gör gränstillståndet
`(y, vy, gravity)` — kontinuerligt. Påståendet att orättvisa övergångar "försvinner
strukturellt" var tomt för exakt den avancerade spelstil de sista tiersen bygger på.

**Lösning:** shufflern kedjar bara mönster där `reachableExits ⊆ survivableEntries`, och
båda mängderna **mäts av proben** (§6) snarare än deklareras av en författare.

### Balansgrindar

`[G-design]` Hård deadlock (ett tillstånd utan utgående mönster) fångas trivialt av en
konnektivitetskontroll. Det verkliga felet är **tyst poolobalans**: författare har stark
omedveten bias mot "springa på golvet". Följden är att körningen tillbringar 80 % av tiden
på golvet och att takmönster dras så sällan att spelaren aldrig lär sig dem och dör mot
obekant geometri vid sekund 45 — vilket känns som att spelet fuskade.

CI-grindar per tier: varje tillstånds utgrad ≥ 12, och shufflerns stationära fördelning
över tillstånd inom 60/40.

---

## 6. Validering: beam search över den riktiga simuleringen

`[G-risk]` `[G-teknik]` Den ursprungliga BFS-solvern över `(x, gravitation, vy-bucket)` var
fel på tre sätt:

1. **Tillståndet saknade `y`**, som är storheten som kolliderar.
2. **Bucketing gör sökningen osund i den farliga riktningen.** Att slå ihop två distinkta
   tillstånd i en bucket kan ge **falska positiva** — CI godkänner ett mönster ingen kan
   klara. Det är precis felet grinden finns för att förhindra. Det finns heller ingen
   användbar dominansrelation att luta sig mot: högre `y` är strikt bättre mot ett
   golvhinder och strikt sämre mot ett takhinder.
3. **Genomförbarhet är inte rättvisa.** Ett mönster med ett 4 ms inputfönster är
   genomförbart och ospelbart.

**Ersättning:** beam search över tap-sekvenser genom **den riktiga OMTCore-simuleringen**
(bredd ~2000, poängsatt på överlevnadstid), följt av en robusthetspass som stör de
vinnande tap-stegen med ±N och mäter överlevnadsgrad.

Fördelarna är inte arbetsbesparing utan korrekthet: **noll modelldrift** (den anropar den
faktiska integratorn och kollisionskoden), **noll falska positiva** (en överlevande
körning *är* en konkret replay du kan titta på), och den producerar ett **automatiskt
svårighetsmått** — vilket är exakt vad som behövs för att sortera ~65 mönster i 6 tiers.

**CI grindar på `robustnessMs`, inte på en boolean.** Det fångar klassen "tekniskt
möjligt, mänskligt omöjligt" som en boolean är blind för. `peakTapRate > 8/s` failar
också, och **valideringen körs om när en tiers `flipDuration` ändras** (§1).

Det enda som förloras är bevis om *omöjlighet*. I praktiken oviktigt: ett olösligt mönster
dyker upp som "ingen lösning funnen" och failar CI lika högljutt.

**Kostnad:** ~150 rader, en dag är realistiskt eftersom fysiken redan är skriven. 2,5 s
mönster = 600 steg; beam 2000 × ~8 kandidattap ≈ 10⁷ steg ≈ 0,1 s per mönster. 65 mönster
≈ 7 s, eller ~1 s med `concurrentPerform`.

---

## 7. Ljud, haptik och takt

`[G-design]` `[G-teknik]` Ordet "ljud" förekom inte en enda gång i den ursprungliga specen.
För ett precisionstimingspel är det halva känslan.

### Takt-kvantisering

Mönsterlängder kvantiseras till **musikaliska takter** vid en tier-specifik BPM. Vid
140 BPM i 4/4 är en takt 1,714 s, så mönster är 1, 1,5 eller 2 takter. Varje mönsterskarv
landar då på ett nedslag, hela körningen blir rytmisk gratis, tier-hastighetsskalären blir
en **tempo**-skalär som ger varje tier hörbar identitet, och rampen i §3 blir ett hörbart
accelerando. Högsta känsla-per-timme i hela designen.

### Arkitektur

`AVAudioEngine` med förladdade `AVAudioPCMBuffer` via
`AVAudioPlayerNode.scheduleBuffer(_:at:options:)`. Inte `AVAudioPlayer` (per-fil, hög
latens, allokering vid uppspelning).

```swift
try session.setCategory(.ambient, options: [.mixWithOthers])
try session.setPreferredIOBufferDuration(0.005)
try session.setPreferredSampleRate(48000)
```

Uppnåelig latens ~10–20 ms till inbyggd högtalare; **+40–70 ms för Bluetooth/AirPods**,
oundvikligt. Därför: **ljud är aldrig en timingreferens för spelmekaniken**, bara
återkoppling.

**Haptik:** `CHHapticEngine` med transienter på flipp, near-miss och död. Kritisk fallgrop:
motorn stoppar vid avbrott — `resetHandler` och `stoppedHandler` måste implementeras,
annars dör haptiken tyst efter första telefonsamtalet.

Ljud och haptik drivs från **`RunEventSink`**, aldrig från simuleringen. Events som behövs
dag ett: `.flipped(step:)`, `.died(step:cause:)`, `.nearMiss(step:)`,
`.patternEntered(id:)`, `.tierCleared`.

---

## 8. Döden

`[G-design]` Den ursprungliga motiveringen — charmig figur gör döden underhållande och
sänker retry-kostnaden — håller inte. I Super Meat Boy är döden *omedelbar*; det
underhållande är de ackumulerade blodspåren och alla-försök-uppspelningen, alltså
persistens och aggregering. Getting Over It kräver långformig progress att förlora; här är
körningarna 15 sekunder. Och authored charm *förfaller*: en animation sedd 200 gånger är
en skatt, inte underhållning.

Vad som faktiskt sänker retry-kostnaden, i ordning: **(1) omstartslatens,
(2) attributionsklarhet** — "jag vet exakt vad jag gjorde fel" — **(3) progressionens
läsbarhet** (§3). Charm är en avlägsen fjärde.

**Men tre dödsreaktioner efter orsak behålls**, med rätt motivering: de är **diagnostik**.
"Du missade flippen", "du slog i taket" och "du sprang in i en spik" är olika lärdomar, och
att kommunicera vilken på 100 ms är punkt (2) ovan. De ska vara **läsbara** först, charmiga
sedan.

### Budget

`[G-design]` 400 ms var fel håll — specen band animationsbudgeten och sköt upp
friktionsbudgeten. Det totala ska begränsa animationen, inte tvärtom.

**Död till spelbar ≤ 250 ms, varav ≤ 120 ms icke-avbrytbart.** Anslagsframen — diagnostiken
— landar inom 60–80 ms. Resten spelas över omstarten eller avbryts av tappet som startar om.
Vid 200 försök är 400 ms per död 80 sekunders ren väntan per tier.

**Omstart rör ingen GPU-resurs.** `[G-teknik]` Pipeline states, atlas, offscreen-target och
buffertringen skapas **en gång vid start**. Omstart är `state = SimState.initial(tier:seed:)`
och inget annat. Annars får du en 200 ms hitch på spelets mest upprepade handling.

---

## 9. Moduler och paketering

```
OneMoreTry.xcodeproj              ← app-target: OMTApp-källor, Info.plist, entitlements
Packages/OMTKit/
  Package.swift                   ← platforms: [.iOS(.v26), .macOS(.v26)]
  Sources/OMTCore/                ← importerar INGENTING. Inte ens Foundation.
  Sources/OMTRender/              ← import Metal (byggs även på macOS)
  Sources/omt-validate/           ← executableTarget, beam search
  Sources/omt-atlas/              ← executableTarget, atlaspackare
  Tests/OMTCoreTests/
Content/patterns/
Art/
docs/
```

`[G-teknik]` **Tre moduler, inte fyra.** `OMTMeta` innehöll noll kod i lager 1. `RunEvent`
och `RunEventSink` definieras i OMTCore (de behövs för ljud och haptik ändå);
`OMTMeta` blir en modul först vid lager 2. Regeln "Core anropar aldrig Meta" upprätthålls
av protokollets riktning, inte av modulantalet.

**Lokalt SwiftPM-paket, inte framework-targets.** `swift test --package-path Packages/OMTKit`
kör på Mac-värden utan destination, utan simulator, på ~2 s. `xcodebuild test` mot ett
framework-target kräver `-destination` och är 30–60× långsammare. **Bara SwiftPM-formen
levererar egenskapen hela arkitekturen vilar på.**

`[G-teknik]` **Motiveringen för den Apple-fria kärnan var fel i originalet.** Metal och
Foundation finns på macOS — att utesluta dem köper ingenting för Mac-testbarhet. De tre
riktiga skälen:

1. `swift test` från terminalen på ~2 s utan Xcode.
2. **Den kompilerar på Linux**, vilket är förutsättningen för en framtida serversidig
   replay-verifierare. Det här skälet **utvidgar regeln till att förbjuda Foundation** —
   `Date`, `UUID`, `JSONDecoder` (dictionary-ordning!) och lokalkänslig formatering är alla
   determinismrisker som "inga Apple-ramverk" släpper igenom.
3. Kompilatorn upprätthåller lagerregeln mekaniskt.

Mönster och atlasindex kompileras därför till genererad Swift eller en binär blob av
`Tools/` — Core parsar ingenting vid körning.

### Swift 6 strict concurrency

```swift
.target(name: "OMTCore",   swiftSettings: [.defaultIsolation(nil)])         // nonisolated
.target(name: "OMTRender", swiftSettings: [.defaultIsolation(MainActor.self)])
```

| Fälla | Regel |
|---|---|
| `public` typer får **inte** implicit `Sendable` | Skriv `public struct SimState: Sendable` explicit |
| Simuleringen på en actor omöjliggör synkron åtkomst i renderloopen | OMTCore helt `nonisolated`, simuleringen en ren värdetyp |
| `CADisplayLink` `@objc`-selektorer är nonisolated | `MainActor.assumeIsolated { … }` |
| Metal-objekt är inte `Sendable` | Renderaren är `final class` isolerad till `@MainActor` |
| `addCompletedHandler` fyrar på Metals interna tråd | Endast `semaphore.signal()`. Rör aldrig speltillstånd. |
| **`AsyncStream` för RunEvent** | **Nej.** Hopp genom cooperative pool → obunden latens, ordning ej deterministisk mot frames, allokering per event. Använd synkron `RunEventSink`; fan-out till AsyncStream först i app-lagret. |
| Egen rendertråd | Nej. Main-actor-rendering är rätt här och eliminerar en hel kategori Swift 6-strider. |

Tester: **swift-testing** (`Testing`-modulen), inte XCTest. `@Test(arguments:)` för golden
replays.

---

## 10. Rendering

`[G-teknik]` Realistisk omfattning: **~1 100–1 500 rader Swift + ~150 rader MSL.**
Kalendertid 1–2 veckor med tidigare Metal-erfarenhet, **3–6 veckor utan**. Radantalet är
inte det svåra — frame pacing, färghantering och bildförhållandet är det.

### CAMetalLayer, inte MTKView

`UIView`-subklass med `layerClass = CAMetalLayer.self`, egen `CADisplayLink`, inlindad i
`UIViewRepresentable`. Skälet är specifikt: vi **behöver** `CADisplayLink.timestamp` och
`.targetTimestamp` både för ackumulatorn och för att mappa `UITouch.timestamp` till
stegindex (§4). MTKView äger sin display link och exponerar den inte.

Gör inte: SwiftUI `Shader`/`.colorEffect` är för att applicera shaders **på SwiftUI-innehåll**,
inte en renderarvärd. Och om iOS 26 erbjuder Metal 4:s `MTL4CommandQueue`-väg — **avstå**;
den är byggd för GPU-drivna storskaliga renderare. Klassisk `MTLRenderCommandEncoder` är
enklare och har mer referensmaterial.

### Frame pacing

- **`CADisableMinimumFrameDurationClamp = true` i Info.plist.** Utan den klampar iOS
  tredjepartsappar till 60 Hz oavsett vad display linken begär. Mest missade inställningen
  på iOS, och den halverar responsiviteten i ett spel med 150 ms reaktionskrav.
- `link.preferredFrameRateRange = CAFrameRateRange(minimum: 120, maximum: 120, preferred: 120)`.
  Ett **intervall** är sämre än värdelöst: systemet ger variabel takt, ackumulatorn emitterar
  2,3,2,3 steg per frame, och det läses som stutter.
- `maximumDrawableCount = 3` + matchande `DispatchSemaphore(value: 3)`.
- **`nextDrawable()` så sent som möjligt**, efter allt CPU-arbete. Att hämta den först
  kostar en hel frame latens — vanligaste nybörjarfelet.
- `presentsWithTransaction = false`.
- Termik: `ProcessInfo.thermalState == .serious` → sänk till 60 Hz. **Säkert just för att
  tidssteget är fast** — spelmekaniken ändras inte. Det är en konkret utdelning på §4.
- `drawableSize` i **pixlar** (`bounds.size × contentScaleFactor`). Glöms lätt och ger
  3× oskarp uppskalning — katastrofalt för pixel art.

### Bildförhållande och rättvisa

`[G-teknik]` Heltalsskalning kräver `virtualH × k == devicePixelH`, vilket nästan aldrig
stämmer (iPhone 16 Pro: 2622×1206, 1206/180 = 6,7). Och horisontell framförhållning **är**
reaktionstid — en 19.5:9-telefon ser 22 % längre fram än 16:9.

Lösning som löser båda samtidigt:

1. **Spelmekaniken är i världsenheter.** Den virtuella upplösningen är bara ett
   rastreringsrutnät. Simuleringen ser aldrig en pixel.
2. Välj heltalsfaktorn `k` per enhet utifrån spelfältshöjden (5 eller 6 på moderna iPhones).
3. Offscreen-texturen täcker hela skärmen vid det `k`:
   `virtualW = floor(devPxW / k)`, `virtualH = floor(devPxH / k)`.
4. **Inuti texturen är spelfältsrektangeln en fast storlek på varje enhet** (t.ex. 320×180
   centrerat). Ett hinder är samma antal texlar överallt.
5. Omgivningen är dekor, inte spelmekanik.
6. **Extra bredd läggs bakom spelaren, aldrig framför:**
   `playerX = playfieldRight - fixedLookaheadPx`. Varje enhet visar exakt lika många
   sekunder av kommande bana. Rättvisan blir exakt, och det är en rad kamerakod.

### Färgrymd — där pixel art dör

Genomsläppskonfiguration, eftersom vi inte har ljussättning: atlas `.rgba8Unorm`
(icke-sRGB), drawable `.bgra8Unorm` (icke-sRGB),
`CAMetalLayer.colorspace = CGColorSpace(name: .sRGB)`,
`wantsExtendedDynamicRangeContent = false`. Texelbytes når skärmen orörda — det ser ut som
i verktyget.

- **Sätt `colorspace` explicit.** iPhones är wide-gamut; taggas något P3 medan konsten är
  sRGB blir färgerna översättade, omedelbart synligt med 16–32 färger.
- **Alpha-test (`discard_fragment()` vid `a < 0.5`) istället för blending** för sprites.
  Pixel art har binär alpha, så hela premultiplied-frågan försvinner. Blending bara i
  posteffekterna.
- **Använd inte `MTKTextureLoader`** — den applicerar sRGB efter PNG-profil, kan
  premultiplicera och kan vända origo. Avkoda med `CGImageSourceCreateWithURL` till rå
  icke-premultiplicerad RGBA8 och ladda upp med `replaceRegion`. ~60 rader, noll
  överraskningar.
- **Xcodes "Compress PNG Files" premultiplicerar och kan ändra RGB där alpha = 0**, vilket
  förstör paddningen runt atlas-sprites. **Skeppa atlasen som folder reference, aldrig genom
  asset catalog.**

### Pixel-perfekthet

Offscreen-targeten är **bärande**: att sampla atlasen direkt till skärmen vid 6,7× låter
källtexlar täcka 7 skärmpixlar på vissa ställen och 6 på andra, och mönstret *skiftar när
kameran scrollar*. Det är shimret. Med virtuell target blir kameran kvantiserad till hela
virtuella pixlar och blitten ren heltalsreplikering.

Men `.nearest` räcker inte ensamt:

- Sampler: `minFilter/magFilter = .nearest`, `mipFilter = .notMipmapped`,
  `sAddressMode/tAddressMode = .clampToEdge`, `maxAnisotropy = 1`.
- **Snappa kamera och spritepositioner till hela virtuella pixlar vid rendering**, *efter*
  interpolationen. Annars jitrar sprites 1 px mot varandra.
- **Sampla i texelcentrum:** `uv = (texelX + 0.5) / atlasWidth`. Kanoniska orsaken till
  atlasblödning.
- **Atlaspackaren måste padda varje sprite med 1 px ram.** Saknades i originalspecen och
  upptäcks annars som "det är en rosa linje till vänster om figuren" efter tre veckor.

### HUD:en ligger i Metal, inte i SwiftUI

`[G-teknik]` Originalspecens "all text och alla menyer är SwiftUI" är fel för HUD:en under
spel, av två oberoende skäl. **Prestanda:** `@State` som ändras varje frame ger full
SwiftUI body-evaluering plus en Core Animation-transaktion **på samma main thread som
renderloopen**, varje frame. **Estetik:** mjuk antialiasad vektortext ovanpå 6× uppskalade
klumpiga pixlar ser fel ut.

**Metal ritar allt synligt under en körning**, inklusive timer och rekordmarkör, med en
bitmapfont i atlasen (~40 extra rader i batchern). **SwiftUI äger menyer, tier-lista,
inställningar och resultatskärmar.**

Tap-igenkännaren sitter på Metal-vyn (det är också där `UITouch.timestamp` finns). Icke-
interaktiva SwiftUI-lager får `.allowsHitTesting(false)`.

---

## 11. Konstpipeline: Blender + Kenney

**Vald väg.** Konsten produceras som **3D-renderade sprites**, inte handritade frames.

Det är en beprövad pipeline, inte en genväg: Donkey Kong Country, Diablo och Dead Cells är
alla förrenderad 3D. Den löser problemet som gjorde den ursprungliga konstplanen till
projektets största risk: **temporal konsistens blir perfekt per konstruktion.** Samma
modell, samma material, olika poser — frame 4 kan inte ha en annan tröjfärg än frame 3.

**Ingen modellering och ingen riggning krävs.** Kenney publicerar **riggade, animerade
3D-karaktärer under CC0** — samma källa som redan var konstvalet för 2D. Tre skäl att det
passar:

1. CC0 löser licensfrågan för ett publikt repo utan asterisk.
2. Den blockiga, platt-shadade låg-poly-stilen **nedsamplar till pixel art bra**, eftersom
   den redan är detaljfattig. En realistisk humanoid gör det inte.
3. Du får en figur med karaktär utan att rita eller rigga något.

**Arbetet blir ett Python-skript i Blender:** importera, ortografisk kamera, toon/platt
shading, låg renderupplösning, ingen antialiasing, rendera bildruteintervall, kvantisera
till fast palett, exportera ark. `ahujasid/blender-mcp` kan driva det.

**Haken:** 3D bara nedskalat blir grötigt. Dead Cells hemlighet är att en pixelkonstnär
städar varje renderad frame. Motmedlet är att gå platt från början — det är därför
Kenney-stilen fungerar och en realistisk modell inte gör det.

**Gravitationsvändningen** renderas som en egen animation snarare än som en vertikalt vänd
sprite, eftersom en figur som springer upp och ner har en egen tyngdkänsla.

**Nödvändiga animationer:** spring (golv), spring (tak), flipp-övergång, sväv-tillstånd
(§1 — svävandet måste ha ett eget visuellt tillstånd), och tre dödsreaktioner efter orsak
(§8).

### Ordningen

`[G-risk]` **Konstpipelinen byggs efter fun-grinden, inte före.** Prototypen som svarar på
"känns gravitationsvändningen bra?" behöver en färgad rektangel med rätt hitbox. Beslutet
blir dessutom bättre efteråt, när den virtuella upplösningen, figurens pixelstorlek och
antalet dödsreaktioner är kända.

### Asset-pipeline

Atlaspackaren körs **aldrig som en Xcode build phase** (bryter inkrementella bygg).
Kör via `make` eller manuellt; **committa genererad atlas + index** som byggindata. CI
verifierar färskhet med `swift run omt-atlas --check`, vilket kräver att packaren är
**deterministisk** — sortera indata på filnamn, lita aldrig på katalogordning.

### Licensledger

`[G-risk]` Ett publikt repo **distribuerar** varje committad asset. `Art/CREDITS.md` för
varje asset: källa-URL, licens, hämtdatum. CC0 är kravet; allt annat hålls utanför repot.

---

## 12. Persistens, tillgänglighet, CI

### Persistens

En `Codable`-struct → `Data.write(to:options:.atomic)` i Application Support, med
`schemaVersion: Int` från första commit. Inte SwiftData/Core Data (migreringssmärta,
`@Model` drar in MainActor överallt). Inte `UserDefaults` för progress (inte
transaktionellt) — men fint för inställningar. Nycklad på tier-**ID-sträng**, inte index.

**Golden replays sparas här också** — några hundra byte styck. De är samtidigt en funktion
("se din bästa körning"), Practice Modes indata, och en växande regressionskorpus.

### Tillgänglighet — och en verklig säkerhetsfråga

`[G-teknik]` Kärnloopen är snabb död → helskärmsblixt → omedelbar omstart, potentiellt
många gånger per minut, med posteffekter, vid 120 Hz. **Det är en anfallsriskprofil.**

- **Begränsa blixtfrekvens och luminansdelta, och erbjud "reducera blinkningar".** Både en
  App Review-fråga och en verklig.
- `UIAccessibility.isReduceMotionEnabled` måste grinda screen shake, chromatic aberration
  och blixtar. Behöver kopplas in dag ett, inte eftermonteras i shaderkod.
- Högkontrastpalett: en LUT-växling i shadern, nästan gratis.
- **Koda aldrig golv-mot-tak-fara med enbart färg.** Form och silhuett måste bära den.
- `PrivacyInfo.xcprivacy` krävs för inlämning; `UserDefaults` är ett required-reason API, så
  den behövs även utan spårning. Garanterat avslag om den saknas.
- Basspråk: engelska, String Catalogs (`.xcstrings`) från start.

### Analytics

Ingen analytics-SDK länkas någonsin in i OMTCore eller OMTRender. **Spela in lokalt i en
ringbuffert från dag ett** — när grinden i §2 körs vill du ha tap-takt, dödsorsaks- och
mönsterfördelning från just de körningarna, retroaktivt.

### CI (GitHub Actions, `macos-26`)

| Jobb | Kommando |
|---|---|
| Core-tester | `swift test --package-path Packages/OMTKit` |
| **Determinismgrind** | samma, i **både** `-c debug` och `-c release` |
| Mönstervalidering | `swift run -c release omt-validate Content/patterns` |
| Atlasfärskhet | `swift run omt-atlas --check` |
| App-bygge | `xcodebuild build -scheme OneMoreTry -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO` |

App-jobbet **bygger bara** — ingen simulatorstart, inga signeringscertifikat i ett publikt
repo. `-warnings-as-errors` på OMTCore.

---

## 13. Roadmap

`[G-risk]` **Enskilt viktigaste ändringen mot originalet: fun-grinden flyttas från slutet av
lager 1 till dag 3**, före OMTCore, Metal och alla verktyg.

| Milstolpe | Innehåll | Utfall |
|---|---|---|
| **M0** (dag 1) | Repo, README, LICENSE, CLAUDE.md, tom app på **fysisk telefon** | Simulatorkänsla är värdelös; känsla mäts på enhet från början |
| **M1** (dag 2–3) | Ett target, SwiftUI `Canvas`, färgade rektanglar. Flipp, procedurella hinder med en svårighetsratt, omedelbar omstart, CC0-ljud på flipp och död, debug-reglage för **flipp-avtryck**, kanalhöjd, hastighet, hitbox-inset | Spelbar prototyp |
| **M2** (vecka 1–2) | Spela. Flytta reglage. Skriv ner trimkonstanter och en beslutslogg | **Grinden avgörs här.** Döda eller fortsätt |
| — | **GRIND** | Tre icke-byggare, 30 försök frivilligt, en återvänder nästa dag |
| **M3** | Extrahera OMTCore (tre moduler). SplitMix64, fast 240 Hz, svept AABB, determinismgrind i CI, körningsposter | Nu vet vi vad simuleringen är |
| **M4** | Författarloopen **före** innehållet: beam search-validator + hot reload. Författa tier 1 och bevisa att 20 mönster går att göra på en kväll | Om inte: 6-tier-strukturen är död, procedurell generering krävs |
| **M5** | Metal-renderaren. Mät först om `Canvas` faktiskt fallerar. Restart-friktionen instrumenteras här, i millisekunder, på enhet | |
| **M6** | Blender+Kenney-pipeline, animationer, tiers 2–6, Practice Mode, ramp, near-miss, ljud och takt-kvantisering | |
| **M7** | Skeppsklar: privacy manifest, tillgänglighet, åldersgräns, ikon, skärmbilder, asset-ledger | |

---

## 14. Icke-mål i lager 1

Ingen fysikmotor. Inga unlocks, valuta, uppdrag eller butik. Ingen backend, inget konto,
ingen leaderboard. Inga annonser, ingen "Continue?"-prompt. Ingen cross-platform-port.
Ingen analytics-SDK (lokal ringbuffert endast).

Noterbart: inga annonser och ingen backend betyder **ingen ATT-prompt och en trivial
integritetsberättelse.** Det är en verklig fördel — behåll den.

---

## 15. Öppna frågor

1. **`flipDuration` och flipp-avtryck.** Startintervall 0,18–0,28 s och 1,2–1,8 kanalhöjder
   horisontellt per korsning. Exakt värde går bara att hitta genom att spela (M2). Notera
   kopplingen till tap-takstaket (§1).
2. **Scrollhastighet** specificerades aldrig i originalet och är meningslös utan
   flipp-avtrycket. Avtrycket är reglaget; hastigheten härleds.
3. **Tier-BPM-uppsättning** (§7) — sex tempi som ger hörbar identitet och stödjer rampen.
4. **Går 6 tiers att ordna** när svävkrav gör svårigheten bimodal? Ordningsmåttet i §3
   (max luftflippar i följd) är hypotesen. Prövas vid M4.
5. **Vad är hooken?** `[M2-fynd]` Svävandet var designens enda mekaniskt nya del och bär
   inte. Genren är enligt granskningen helt mättad, så spelet konkurrerar nu på känsla och
   presentation snarare än på mekanik. Det är ett legitimt läge — Downwell gjorde precis
   det — men det ska stå skrivet istället för antas bort, och det ändrar vad som är värt
   att lägga tid på: tre sekunders video måste bära på utseende och game feel.
6. **Overkill-risk i M4:** om 20 rimliga mönster inte går att författa på en kväll är
   handförfattande dött och procedurell generering med en svårighetsratt är planen.

---

## 16. Granskningsanteckning

Tre oberoende granskningar kördes mot Del 1-utkastet 2026-09-13. Fynd som ändrade designen
väsentligt:

- **Pelaren mot strukturen** (memorering vs shufflad endless) — löstes med fast öppning
  (§3)
- **`entryState`/`exitState` var en falsk modell** givet flipp i luften — funnet oberoende
  av två granskare, löstes med uppmätta fasrymdsmängder (§5)
- **BFS-solvern var osund i den farliga riktningen** och mätte fel storhet — ersattes med
  beam search + robusthet (§6)
- **Grinden kunde inte producera ett nej** (§2)
- **Inputkvantiseringsregeln saknades helt** och bröt replay-troheten (§4)
- **Determinismrisken var feldiagnostiserad** — `Double` var aldrig problemet; hash-ordning
  och stdlib-churn var det (§4)
- **Ljud saknades helt** i ett timingspel; takt-kvantisering är högsta känsla-per-timme (§7)
- **Charm-argumentet för döden höll inte**; diagnostik är den riktiga motiveringen (§8)
- **Fotokänslighet** var en verklig oadresserad säkerhetsfråga (§12)
- **Fun-grinden låg i fel ände av projektet** (§13)

Och ett fynd som kom ur att faktiskt spela, inte ur granskning:

- **Svävandet bär inte.** Förutsagt av granskningens matematik, bekräftat på enhet, och
  spårat till en tidsskale-konflikt som ingen trimning kan lösa (§1). Roadmapens M2 finns
  precis för att fånga sånt före innehållsproduktion; kostnaden blev en eftermiddag
  istället för en månad.
