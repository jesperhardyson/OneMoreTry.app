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

# Läge just nu (2026-09-13, sessionsslut)

## Klart och pushat

- `OMTCore`: kinematik, svept AABB, händelser, near-miss, dödsorsak, impulsläge,
  variabel hopphöjd (Mario-kapning), portaler. **19 tester gröna**, körs headless på mac.
- App: M1-prototyp med Canvas, procedurella hinder, trim-panel med reglage, syntetiserat
  ljud och haptik, press/release. Kör på iPhone 17 Pro.
- Spec och beslutslogg uppdaterade till och med variabel hopphöjd.

## Nästa steg, i ordning

1. **Koppla portaler till appen** — de finns i kärnan men inget genererar, ritar eller
   ljudsätter dem än. Behövs: generering i `GameModel.generateAhead()`, ritning i
   `ContentView.draw`, och `.modeChanged` i `Feedback` (eget ljud, egen palett, egen
   figurfärg — se lägesförvirringsrisken ovan).
2. **Uppdatera spec §0 och §1** — "gravitationsvänd" är inte längre ett låst beslut utan
   halva spelet. Portaler behöver ett eget avsnitt.
3. **Trimma `impulseCutFraction`** — står på 0,35 som gissning. Fönstret för ett "kort"
   tryck är ~70 ms, vilket kan vara snävare än hur länge en människa faktiskt håller.
4. **Kör den riktiga grinden** — tre icke-byggare, 30 försök frivilligt, en återvänder
   nästa dag. Den är fortfarande inte körd.

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

Telefonen måste vara upplåst för `process launch`.
