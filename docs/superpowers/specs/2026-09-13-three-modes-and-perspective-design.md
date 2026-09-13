# Tre lägen och perspektiv — Designspec

**Status:** godkänd i brainstorm 2026-09-13. Inte byggd.
**Kompletterar:** `2026-09-13-one-more-try-design.md`, som är auktoritativ för allt detta
dokument inte uttryckligen ändrar.
**Härrör ur:** `docs/decision-log.md`, fjärde passet, och huvudspecens §15.5.

Det här dokumentet finns för att huvudspecens §0 låste *"kärnmekanik: gravitationsvänd"*,
och det är inte längre sant. Gravitationsvändningen är ett av tre lägen. Det kräver mer än
en ändrad paragraf, därav en egen spec.

---

## 0. Vad detta ändrar

| Huvudspecen | Blir |
|---|---|
| §0 Kärnmekanik: gravitationsvänd, ett tap, flipp tillåten i luften | Tre lägen — gravitationsvänd, impuls, tub — som blandas inom en körning via portaler. Ett tap, flipp tillåten i luften, i alla tre. |
| §0 Estetik: pixel art med animerad figur | Pixel art i perspektiv. Ankarpunkt: F-Zero och Star Fox — en 16-bitarskonsol som gör pseudo-3D, med modern ljussättning ovanpå. |
| §10 Snappa kamera och spritepositioner till hela virtuella pixlar | Gäller HUD och skärmrymd. **Undantag för geometri i perspektiv** — se §6. |
| §15.5 Vad är hooken? | Besvarad: presentationen, uttalad istället för antagen. Se §1. |

**Oförändrat och fortfarande låst:** one-tap. Determinismen ur
`(simVersion, contentHash, tierID, seed, tapSteps)`. Sex tiers, var och en oändlig, klarad
genom att överleva 60 s. `step: UInt32` som sanning. `OMTCore` utan imports. `RunEventSink`
synkron. Beam search genom den riktiga simuleringen. Ingen spelmotor.

---

## 1. Varför: vad portalerna kostade

Beslutsloggens fjärde pass införde portaler som byter mekanik mitt i körningen. De löste ett
verkligt problem — tier-stegen toppade vid fyra luftflippar, så tier 5–6 kunde bara bli
svårare genom snävare marginaler och högre tempo, alltså samma färdighet under mer press.

Men de betalade med genrens mest igenkännbara idé. Det som läser som Geometry Dash är inte
*vilka* lägen som finns, det är **arkitekturen**: en bana som byter styrmekanik vid portaler.
Två lägen gav den formen; tre ger den tydligare.

Slutsatsen är därför inte att lägena ska bort, utan att **differentieringen måste ligga
någon annanstans än i mekanikens arkitektur.** Huvudspecens §15.5 hade redan tagit den
positionen — genren är mättad, spelet konkurrerar på känsla och presentation, med Downwell
som precedens — men skrev den som en öppen fråga snarare än som en plan.

Det här dokumentet gör den till en plan, och lägger till det tredje läget som ger
tier 5–6 en ny färdighet istället för mer press.

**Vad som faktiskt är ovanligt i designen**, och som inte ändras av något här:

1. Blandaren efter den fasta öppningen. En Geometry Dash-bana är ändlig och helt handbyggd,
   alltså ett memoreringsobjekt. Den shufflade svansen är ett färdighetstest.
2. Det maskinverifierade rättvisegolvet. `robustnessMs` härleds av beam search genom den
   riktiga simuleringen. Genren har inga rättvisegarantier.
3. Klarande genom att överleva 60 s av oändlighet, inte genom att nå ett slut.

Alla tre är osynliga för en spelare under de första 30 sekunderna — exakt när hen avgör om
spelet är en kopia. Det är därför presentationen måste bära, och varför §6 är den
dyraste delen av det här dokumentet.

---

## 2. De tre lägena

| | Gravitationsvänd | Impuls | Tub |
|---|---|---|---|
| Geometri | Kanal, golv och tak | Kanal, golv och tak | Fyrkantig tub, fyra väggar |
| Vad ett tap gör | Vänder accelerationens tecken | Sätter vertikal hastighet | Roterar `downWall` ett kvartsvarv medsols |
| Analog axel | ingen | variabel hopphöjd (Mario-kapning) | ingen |
| Färdighet | Precision i ytväxling, luftkorrigering | Uthållig höjdkontroll | Rumslig orientering, kedjade vridningar |
| Kameraram | Sidovy med djup | Sidovy med djup | Bakifrån, ner genom tuben |
| Innehållspool | delad med impuls | delad med gravitationsvänd | egen |

De två kanallägena ser identiska ut och skiljer sig bara i tappets betydelse. Tuben kan
inte förväxlas med någondera — geometrin annonserar sig själv. **Det tredje läget är
därför det säkraste av de tre**, och ökar inte lägesförvirringsrisken.

`Tuning.mode` är fortfarande bara *startläget*. Det aktiva läget bor i `SimState`.

---

## 3. Tubens simuleringsmodell

Tuben är inte en ny fysikmodell. **Det är kanalen böjd till en cirkel**, och det är ett
falsifierbart påstående — §11 låser det med ett test.

### Avbildningen

| Kanalen | Tuben |
|---|---|
| `y` — position mellan golv och tak | `theta` — vinkelposition i **kvartsvarv** |
| `vy` — vertikal hastighet | `vTheta` — kvartsvarv per sekund |
| `gravity: Sign` — golv eller tak | `downWall: UInt8` — vilken av fyra väggar som drar |
| Tap vänder `gravity` | Tap ökar `downWall` med 1 (mod 4) |
| `y` klampar vid `floorY` / `ceilingY` | `theta` klampar vid `downWall` |

### Vinkelrymd, inte kartesisk rymd

`theta` är tillståndet. Tubens radie förekommer **aldrig** i simuleringen — den är en
renderarkonstant. Följden är att inga transcendentaler behövs i stegloopen och att
determinismreglerna i CLAUDE.md gäller oförändrat.

Vinkelaccelerationen är därför direkt härledd:

```
alphaMagnitude = 2 / flipDuration²        [kvartsvarv/s²]
```

Ett kvartsvarv från vila (`Δtheta = 1`) tar då exakt `flipDuration`. Det är samma
`g = 2h/t²` som kanalen, med `h = 1 kvartsvarv`. `flipDuration` och `flipFootprint`
behåller alltså sin betydelse, och `flipFootprint` är fortfarande den enda konstant
spelaren faktiskt känner.

**Följd för svävandet:** hållamplituden i tuben är

```
A = T² / (2 · flipDuration²)              [kvartsvarv]
```

vilket är huvudspecens `A = h·T²/(2·t_f²)` med `h = 1`. Att hålla en vinkel mellan två
väggar med alternerande tapping är alltså exakt lika dyrt som svävandet i kanalen var, och
det säljs därför **inte** in som identitet. Det är djup för den som hittar det, aldrig ett
krav — samma position som variabel hopphöjd fick i tredje passet.

### Rotationsriktning: alltid medsols

Väggindex växer medsols sett från kameran i tubramen, alltså `0 → 1 → 2 → 3 → 0`. Ett tap
ökar `downWall` med 1 modulo 4. Det är samma sak sagt två gånger, avsiktligt: teckenfel i
den här riktningen är osynliga i ett test som bara mäter varaktighet.

Valt bland tre alternativ. Alltid samma riktning är entydig utan att förklaras, gör alla
fyra väggar meningsfulla, och gör kostnaden för ett misstag — tre vridningar istället för
en — till något validatorn kan mäta i `robustnessMs` istället för en godtycklig straffavgift.

Förkastat: *alternerande riktning* (i en cirkel är "vänd" inte entydigt, spelaren måste
hålla riktningen i huvudet) och *alltid 180°* (förlorar två av fyra väggar som meningsfulla
positioner, och då är tuben bara en kanal med kosmetik).

### Wrappen är exakt

`theta` hålls i `[0, 4)` genom att addera eller subtrahera `4.0`. Fyra är en tvåpotens, så
operationen är exakt i binär flyttal och introducerar ingen drift. Låst av
`thetaWrapIsExact`.

Ett svep kan aldrig korsa wrappen, eftersom ett svep är ett steg och ett steg är 1/240 s.

### Kollision

En vägg `w` har sitt centrum vid `theta = w` och spänner `[w − 0.5, w + 0.5)`. Ett hinder
ockuperar en vägg över ett `x`-intervall. Figuren har en vinkelhalvbredd härledd ur
`characterHeight` och tubens sidlängd (som är `channelHeight`, så trimningen överförs).

```
träff  ⟺  x-intervallen överlappar  ∧  figurens vinkelintervall överlappar väggens
```

Jämförelser mellan `Double` och heltal. Det svepta AABB-testet i `Collision.swift` fungerar
oförändrat på `(x, theta)`.

**Emergent egenskap, inte en designad regel:** vid ett hörn (`theta = w + 0.5`) överlappar
figuren båda angränsande väggarna och är exponerad för hinder på bägge. Det gör hörn
riskabla och ger tuben djup gratis. Validatorn mäter konsekvensen; vi designar inte mot den.

---

## 4. Övergångar

**Princip: en portal flyttar aldrig figuren till en position spelaren inte kunde förutse.
Övergångar är geometriska projektioner, inte teleporteringar.**

| Övergång | Regel |
|---|---|
| Kanal → tub | `y` avbildas linjärt på `theta ∈ [0, 2]`: golv → vägg 0, tak → vägg 2. Rörelsemängden behålls med tecken. `downWall := 0`. |
| Tub → kanal | `theta` projiceras på den vertikala axeln: vägg 0 → golv, vägg 2 → tak, vägg 1 och 3 → mitten, vilket är exakt var de *ser* ut att vara. `vTheta` avbildas på `vy` med samma skala. `gravity := .down`. |
| Kanal → impuls | Oförändrat: `gravity := .down`. Se beslutsloggen, fjärde passet. |

`downWall := 0` respektive `gravity := .down` vid inträde är samma regel som redan gäller
impulsläget: ett tap får inte göra motsatsen till vad spelaren förväntar sig direkt efter
bytet.

**Följd som måste vara avsiktlig:** en spelare som passerar portalen hängande i taket
hamnar i ett läge där gravitationen drar bort från hen, och faller. I tuben är fallet två
kvartsvarv, alltså `flipDuration · √2 ≈ 0,31 s`. Det är inte ett undantag — det är exakt
vad regeln `gravity := .down` redan gör i kanal → impuls idag. Säkerhetszonens `after` (§7)
måste därför rymma det längsta fallet någon övergång kan orsaka, inte bara svepet.
Spelarens position på skärmen är kontinuerlig genom bytet. Låst av
`portalTransitionsPreserveScreenPosition`, i båda riktningarna.

---

## 5. Kameraramar och svepet

### Två ramar, av läsbarhetsskäl

| | Kanalen | Tuben |
|---|---|---|
| Ram | Sidovy med djup. Spelplanet frontoparallellt; golv, tak och bakgrund har verklig geometri. | Kameran bakom figuren, blicken ner genom tuben. |
| Varför | `nearMissClearance` är 10 % av kanalhöjden. I perspektiv är det ett par pixlar, och spelet blir oläsligt. Ett frontoparallellt spelplan bevarar dagens läsbarhet exakt. | En tub sedd från sidan projicerar vägg 1 och vägg 3 till samma vertikala position. Oläsbart utan ocklusion. |
| Framförhållning | `playerX = playfieldRight − fixedLookaheadPx`, oförändrat från §10 | Fast **tidshorisont** av synlig korridor — samma rättviseregel uttryckt i djup istället för bredd |

### Svepet

Portalen mellan två ramar spelas som en snabb kamerarörelse, inte ett hårt snitt. Fem
villkor gör det säkert:

1. **Fast, känd varaktighet.** Säkerhetszonen måste kunna budgetera den.
2. **Zonen växer med svepet:** `after ≥ svepvaraktighet + återanskaffningstid`.
3. **Simuleringen pausar aldrig.** Figuren rör sig under svepet, och svepet konsumerar
   bana. Zonen mäter det i världsenheter.
4. **Svepet sväljer aldrig input.** Ett tap under svepet är speldata och ligger i replayen.
   Kameran är presentationslager och får inte ha en åsikt om tappet.
5. **Kameran hamnar aldrig i `SimState`.** Svepet drivs av `state.step − modeChangedStep`,
   inte av väggklocka. Följd: en replay ser exakt likadan ut som körningen, och tappade
   frames flyttar aldrig kameran ur fas med simuleringen.

**Varaktighet:** ett taktslag vid tierns BPM, klampat till `[0,15 s – 0,30 s]`. §7 i
huvudspecen kvantiserar mönsterlängder till takter, så portalen ligger redan på ett slag
och svepet löser ut på nästa. Det gör rörelsen avsiktlig istället för reaktiv och kostar
ingenting, eftersom takt-maskineriet redan finns. `flipDuration` är 0,22 s, så svepet ska
ligga i samma storleksordning för att inte dominera. Exakt värde är en grindfråga.

### Tillgänglighet

`isReduceMotionEnabled` på → hårt snitt. Av → svep.

**De två varianterna är exakt lika rättvisa**, eftersom säkerhetszonen dimensioneras för
den långsammare av dem. Ingen tillgänglighetsinställning ändrar svårigheten.

Det är skälet en tidigare ansats — att rulla kameran 90° runt färdriktningen i kanalen —
lades ner: där bar rotationen **information**, så en grind hade gjort spelet ospelbart, och
att grinda den hade gett två olika svårighetsgrader. Svepet bär ingen information, eftersom
zonen garanterar att det inte finns något att läsa under det.

**Kameran rullar aldrig i tuben.** Figuren orbiterar; tuben står still. En tub som roterar
runt en stillastående figur är en vestibulär trigger, och rotationen *är* speltillstånd —
den kan inte grindas bort. En figur som orbiterar runt en stillastående tub bär samma
information utan att vrida spelarens referensram, och behöver därför ingen grind alls.

---

## 6. Perspektiv och pixel art

### Pixelrutnätet tillhör offscreen-targeten, inte sprites

Huvudspecens §10 gör offscreen-targeten bärande, väljer heltalsfaktorn `k` per enhet och
håller spelfältsrektangeln på en fast texelstorlek inuti texturen. Det är precis den
arkitektur som gör perspektiv-3D med pixel art möjlig:

När 3D:n rastreras **in i** den lågupplösta targeten kvantiseras perspektivet automatiskt
till det virtuella rutnätet. Ett hinder på avstånd blir klumpiga texlar av sig självt.
Färgrymdsreglerna är oförändrade; heltalsblitten till skärmen är oförändrad.

### Undantaget i snappningsregeln

CLAUDE.md och §10 säger: snappa kamera och spritepositioner till hela virtuella pixlar
efter interpolation. **Det kan inte gälla geometri i perspektiv** — en sprite på djup har en
icke-heltalig skalfaktor, och att snappa den bryter perspektivet.

- Regeln **gäller** HUD:en och allt i skärmrymd.
- För 3D-geometri gör targetens rastrering kvantiseringen istället.
- **Priset:** avlägsen geometri kan poppa när vertexar rör sig mindre än en virtuell pixel
  per frame. Det är Mode 7-artefakten, alltså i stil snarare än utanför den. Skrivet här
  för att det ska vara ett val och inte en upptäckt.

**Följdändring:** CLAUDE.md:s renderingsavsnitt behöver den här nyanseringen inskriven.

### Moderna effekter

| Effekt | Beslut |
|---|---|
| Bloom / glöd | **I den lågupplösta bufferten, före uppskalning.** Full upplösning ovanpå klumpiga pixlar läser som fake retro. §10 tillåter redan blending i posteffekterna. |
| Palettbyte per läge | **Ja, och gratis.** Palettswap är den autentiska 16-bitarstekniken, och §9 kräver ändå en palett per läge. |
| Chromatic aberration, shake, blixtar | Tillåtna, grindade av `isReduceMotionEnabled`. Oförändrat. |
| Scanlines | Valfria. Läser som emulator snarare än som konsol; svag rekommendation mot. |
| CRT-kurvatur | **Nej.** Distorderar spelfältet och därmed rättvisan, och slåss med perspektivet. |

### Silhuettaket

CLAUDE.md: fara får aldrig kodas med enbart färg — form och silhuett måste bära den. I
perspektiv krymper avlägsna silhuetter. Det sätter ett **tak** på framförhållningen: bortom
en viss punkt är ett hinder synligt men inte läsbart, vilket är värre än att inte se det.
Taket mäts på grinden, per kameraram.

---

## 7. Säkerhetszonen

Prototypens `guardZone(for:)` i `App/GameModel.swift` står som TODO med en gissad
symmetrisk halvsekund. Det här dokumentet ger den sin betydelse:

**Zonens `after` är budgeten för visuell återanskaffning.**

Validatorn mäter `robustnessMs` genom simuleringen, men kan inte mäta hur lång tid en
människa behöver för att läsa om en ny kameraram. Det måste därför vara en innehållsregel.

Följder:

- **Zonen är asymmetrisk.** Att läsa en portal i förväg är billigt; att omorientera efter
  den är inte det.
- **Zonen är per lägesövergång, inte en konstant.** Ett ramskifte (kanal ↔ tub) kräver mer
  än ett kontrollbyte (gravitationsvänd ↔ impuls).
- **Zonen inkluderar svepvaraktigheten** enligt §5.
- Värdet mäts på grinden. Det står medvetet kvar som TODO till dess.

**Känd fälla, dokumenterad:** om portalperioden är kort i förhållande till zonen slukar
zonerna all bana och inga hinder genereras alls. Observerat i prototypen vid period 0,7 s
med en zon på 2 × 341 världsenheter. Trimpanelen måste visa antalet genererade hinder, eller
grinden kommer att köras på en tom bana utan att någon märker det.

---

## 8. Innehåll och validator

### Mönsterformat

`Surface` (golv/tak) generaliseras till `wall: UInt8`. Kanalen använder 0 och 2; tuben
använder 0–3. Ett `Pattern` får en `geometry`-tagg — `channel` eller `tube`. Biblioteket
förblir **ett delat bibliotek** enligt §5 i huvudspecen, inte en mapp per läge.

Noterat men inte planerat för: ett kanalmönster är formellt giltig tubgeometri med väggarna
1 och 3 tomma. Med medsols rotation kräver vägg 0 → vägg 2 två vridningar, så det är en
*annan* utmaning. Om validatorn råkar döma något sådant rättvist är det gratis innehåll.
Ingenting byggs för det.

### Validatorn

Tredje passet. Samma beam search genom den riktiga simuleringen.

- **Förgreningsfaktorn är fortfarande 2.** Tap eller inte, per steg.
- **Tillståndsrymden växer 2×.** Kanalens diskreta dimension är `gravity` med två värden;
  tubens är `downWall` med fyra. Beamens bredd kan behöva höjas — en prestandafråga, inte en
  korrekthetsfråga.
- `reachableExits` och `survivableEntries` mäts i `(wall, theta, vTheta)` istället för
  `(y, vy)`. Skarvmaskineriet generaliseras utan omskrivning; det mätte redan tillstånd,
  inte koordinater.

### Tier-ordningen

Ordningsvariabeln i huvudspecens §3 — max antal flippar i följd i luften — blir i tuben
max antal **kedjade vridningar**. Samma skala, samma monotonitet, och stegen behöver inte
göras om. Tuben ger tier 5–6 en ny färdighet istället för snävare marginaler, vilket var
den kostnad §3 uttryckligen noterade.

### CI

`robustnessMs` grindas per läge, nu tre istället för två. **Omvalidering krävs när en tiers
`flipDuration` ändras** — oförändrad regel, en dimension mer.

---

## 9. Ljud, haptik, palett

Regeln från fjärde passet står oförändrad: bytet bärs av figurens utseende, paletten **och**
ljudets tonhöjd samtidigt.

- Tredje portalröst för tuben. De två befintliga är kvintstaplade svep — 330→990 Hz för
  impuls, 990→330 Hz för gravitation — så tubens röst måste skilja sig i klangfärg, inte
  bara i tonhöjd.
- Egen palett och egen figurfärg per läge. Implementerat för två lägen; utökas till tre.
- Dubbeltransient vid lägesbyte. Oförändrad.

---

## 10. Konstpipelinens kostnad

Detta är designens största enskilda kostnad, och den ska stå tydligt.

Huvudspecens §11 förrenderar sprites från Kenney CC0-modeller med **ortografisk** kamera.
Två kameraramar betyder **en renderuppsättning per ram**: sidovy för kanallägena, bakifrån
för tuben.

- Bakifrån behöver färre frames — ingen ansikts- eller profildetalj — men det är ändå en
  andra uppsättning animationer.
- Miljögeometrin (väggar, tub) är riktig 3D och kommer inte ur sprite-pipelinen.
- Figuren förblir en förrenderad billboard. Det fungerar eftersom kameraramen är **fast per
  läge**; en fri kamera hade krävt riktig 3D-figur och hade brutit hela §11.

Regeln i §11 att konstpipelinen byggs **efter** fun-grinden gäller oförändrat, och blir
viktigare: det är nu dubbelt så mycket arbete att kasta.

---

## 11. Teststrategi

### Kärnan

Tubens tester speglar kanalens. Om påståendet i §3 är sant ska samma formler gälla.

| Test | Vad det låser |
|---|---|
| `aQuarterTurnFromRestTakesFlipDuration` | Avbildningen av `g = 2h/t²` till vinkelrymd |
| `orbitalHoldAmplitudeMatchesTheAnalyticFormula` | **Samma formel som `hoverAmplitudeMatchesTheAnalyticFormula`, med `h = 1`.** Om den inte gäller är det inte samma integration, och §3 är fel. |
| `thetaWrapIsExact` | Att `± 4.0` inte introducerar drift |
| `enteringTubeModeSetsDownWallToZero` | Spegling av `enteringImpulseModeForcesGravityDown` |
| `portalTransitionsPreserveScreenPosition` | Projektionsregeln i §4, båda riktningarna |
| `fastRotationCannotTunnelThroughAWallObstacle` | Att det svepta testet gäller i `(x, theta)` |
| `cornerOverlapsBothAdjacentWalls` | Den emergenta hörnegenskapen i §3 — så att den inte tystnar av en refaktorering |

Determinismgrinden kör allt detta i `-c debug` **och** `-c release`. Fyrar den: hitta
orsaken, höj inte toleransen.

### Golden-test

En inspelad körning som passerar **båda** portaltyperna reproduceras ur
`(simVersion, contentHash, tierID, seed, tapSteps)`. Det är här tryck/släpp-**paret** i
inputformatet bevisar sitt värde: en replay som bara lagrat nedtryck kan inte återskapa en
kedjad vridning.

### Renderaren

Utseendet går inte att enhetstesta. Två invarianter går:

- **Blitten är exakt heltalsreplikering.** Rendera ett känt mönster till targeten, läs
  tillbaka, verifiera att ingen interpolation skett.
- **Svepet är en funktion av stegdelta.** Samma steg in ger samma kameramatris ut,
  oberoende av frametid.

### Vad som inte testas

Om det är roligt. Det är grinden.

---

## 12. Ordning, och grindberoendet

`CLAUDE.md`: *"Fun-grinden ligger på dag 3, inte i slutet. Innan den är passerad: bygg
inget som skulle kastas om mekaniken visar sig tråkig."*

Grinden är **inte körd.** Tre icke-byggare, 30 frivilliga försök, minst en som återvänder
nästa dag utan att bli tillfrågad. Den har stått som ogjord sedan första passet.

Ordningen är därför:

| Steg | Beroende |
|---|---|
| 1. Kör fun-grinden på det som redan finns | Portaler och variabel hopphöjd finns på enhet. Inget i det här dokumentet behövs för att grinda. |
| 2. Perspektivkorridoren (§5, §6) | Grinden passerad |
| 3. Tuben i `OMTCore` (§3, §4) + tester (§11) | Kan ske parallellt med 2 — den rör ingen renderare |
| 4. Tuben i renderaren | Steg 2 klart. Perspektivrenderaren *är* tubens renderare med fyra väggar istället för två. |
| 5. Innehåll och tredje validatorpasset (§8) | Steg 3 klart |
| 6. Konstpipeline per kameraram (§10) | Grinden passerad, virtuell upplösning vald |

Steg 2 gör steg 4 nästan gratis. Det är hela skälet att perspektivet ligger före tuben och
inte efter.

**Omfattning:** det här är en spec, men inte en implementationsplan. Stegen 2–6 är fyra
oberoende leveranser — perspektivrenderaren, tuben i kärnan, innehållet och
konstpipelinen — och ska bli **var sin plan**. Steg 3 delar ingen fil med steg 2 och kan
planeras utan att steg 2 är beslutat i detalj.

---

## 13. Icke-mål

- **Fri kamera.** Ramen är fast per läge. En fri kamera bryter §10:s förrenderade
  billboards och därmed hela konstpipelinen.
- **Två inputaxlar.** One-tap är låst. Tuben är 1-DOF, precis som kanalen.
- **Ett fjärde läge.** Tre är vad tier-stegen behöver. Fler pooler är innehållsfällan
  huvudspecens §3 avvisar.
- **Att tuben ska ha en impulsvariant.** Tre lägen, inte fyra.
- **CRT-kurvatur.** Se §6.
- **Att dimensionsbytet blir hela spelet** istället för ett läge bland tre. Det vore en
  fjärde ansats och en större omskrivning; den är inte utredd och inte förkastad.

---

## 14. Öppna frågor

1. **Säkerhetszonens värden per lägesövergång.** Mäts på grinden. `guardZone(for:)` står
   som TODO till dess. Se §7.
2. **Svepvaraktigheten** inom `[0,15 s – 0,30 s]`. Grindfråga. Se §5.
3. **Silhuettaket** — hur långt framförhållningen får sträcka sig innan hinder är synliga
   men oläsliga. Mäts per kameraram. Se §6.
4. **Virtuell upplösning.** Fortfarande öppen från huvudspecen, och nu mer bindande:
   perspektivet gör pixelstorleken till en läsbarhetsfråga och inte bara en stilfråga.
5. **Beamens bredd** för tuben, givet 2× tillståndsrymd. Prestandafråga.
6. **Hörnexponeringen i §3** — djup eller orättvist? Validatorn mäter det, men om
   `robustnessMs` faller brant nära hörn kan det behöva en designändring snarare än en
   innehållsregel.
7. **Är tre lägen för mycket för 60 sekunder?** Om varje läge behöver en säkerhetszon och
   en etablerande passage kan en 60-sekunderskörning sakna plats för alla tre. Kan bli en
   tier-ordningsfråga: tier 1–2 i ett läge, tuben introducerad i tier 3.

---

## 15. Vad detta dokument *inte* löser

Att tre lägen som blandas vid portaler fortfarande är Geometry Dash-arkitekturen. §6 gör
innehållet och utseendet distinkt; **formen är det inte.** Det är ett medvetet val med en
uttalad grund: §15.5 säger att konkurrensen ligger på känsla och presentation, och en
mättad genre besegras inte med en fjärde mekanikvariant.

Om det visar sig otillräckligt på grinden är nästa steg inte ett fjärde läge, utan
icke-målet i §13: att låta dimensionsbytet vara hela spelet.
