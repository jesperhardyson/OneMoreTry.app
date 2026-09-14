# Tre lägen och perspektiv — Designspec

**Status:** godkänd i brainstorm 2026-09-13, reviderad efter granskning samma dag. Inte byggd.
**Kompletterar:** `2026-09-13-one-more-try-design.md`, som är auktoritativ för allt detta
dokument inte uttryckligen ändrar.
**Härrör ur:** `docs/decision-log.md`, fjärde och femte passet, och huvudspecens §15.5.

Det här dokumentet finns för att huvudspecens §0 låste *"kärnmekanik: gravitationsvänd"*,
och det är inte längre sant. Gravitationsvändningen är ett av tre lägen. Det kräver mer än
en ändrad paragraf, därav en egen spec.

---

## 0. Vad detta ändrar

| Huvudspecen | Blir |
|---|---|
| §0 Kärnmekanik: gravitationsvänd, ett tap, flipp tillåten i luften | Tre lägen — gravitationsvänd, impuls, tub — som blandas inom en körning via portaler. Ett tap, flipp tillåten i luften, i alla tre. |
| §0 Estetik: pixel art med animerad figur | Pixel art i perspektiv. Ankarpunkt: F-Zero och Star Fox — en 16-bitarskonsol som gör pseudo-3D, med modern ljussättning ovanpå. |
| §0 Konstkälla: Blender-renderade sprites ur CC0-modeller, "ingen modellering och ingen riggning krävs" | **Gäller fortfarande figuren.** Miljögeometrin (kanalväggar, tub) är författad 3D och kommer inte ur sprite-pipelinen. Se §10. |
| §10 Snappa kamera och spritepositioner till hela virtuella pixlar | **Kamerasnappningen är oförändrad.** Undantaget gäller bara vertexpositioner för icke-frontoparallell geometri — se §6.2. |
| §5 Balansgrindar: utgrad ≥ 12, stationär fördelning inom 60/40 | Generaliseras till fyra väggar — se §8.3. |
| §15.5 Vad är hooken? | Besvarad: presentationen, uttalad istället för antagen. Se §1. |

**Oförändrat och fortfarande låst:** one-tap. Determinismen ur
`(simVersion, contentHash, tierID, seed, tapSteps)`. Sex tiers, var och en oändlig, klarad
genom att överleva 60 s. `step: UInt32` som sanning. `OMTCore` utan imports. `RunEventSink`
synkron. Beam search genom den riktiga simuleringen. Ingen spelmotor.

### 0.1 Revisionen

Första utkastet granskades av tre oberoende granskare mot arbetsreglerna, mot koden och mot
matematiken. Femton fynd. Fyra var riktiga defekter i simuleringsmodellen — wrap-around i
kollisionen, en falsk exakthetsgaranti, en odefinierad fallriktning, och ett felaktigt
påstående om att `flipDuration` behåller sin betydelse. Två ändrade designen: tubens form
(§3.1) och svävandets karaktär (§3.5). Resten skärpte avgränsningar.

De ställen där granskningen ändrade ett beslut är märkta **[R]**, så att nästa läsare ser
vad som är genomtänkt och inte bara nedskrivet.

---

## 1. Varför: vad portalerna kostade

Beslutsloggens fjärde pass införde portaler som byter mekanik mitt i körningen. De löste ett
verkligt problem — tier-stegen toppade vid fyra luftflippar, så tier 5–6 kunde bara bli
svårare genom snävare marginaler och högre tempo, alltså samma färdighet under mer press.

Men de betalade med genrens mest igenkännbara idé. Det som läser som Geometry Dash är inte
*vilka* lägen som finns, det är **arkitekturen**: en bana som byter styrmekanik vid
portaler. Två lägen gav den formen; tre ger den tydligare.

Slutsatsen är därför inte att lägena ska bort, utan att **differentieringen måste ligga
någon annanstans än i mekanikens arkitektur.** Huvudspecens §15.5 hade redan tagit den
positionen — genren är mättad, spelet konkurrerar på känsla och presentation, med Downwell
som precedens — men skrev den som en öppen fråga snarare än som en plan.

Det här dokumentet gör den till en plan, och lägger till det tredje läget som ger tier 5–6
en ny färdighet istället för mer press.

**Vad som faktiskt är ovanligt i designen**, och som inte ändras av något här:

1. Blandaren efter den fasta öppningen. En Geometry Dash-bana är ändlig och helt handbyggd,
   alltså ett memoreringsobjekt. Den shufflade svansen är ett färdighetstest.
2. Det maskinverifierade rättvisegolvet. `robustnessMs` härleds av beam search genom den
   riktiga simuleringen. Genren har inga rättvisegarantier.
3. Klarande genom att överleva 60 s av oändlighet, inte genom att nå ett slut.

Alla tre är osynliga för en spelare under de första 30 sekunderna — exakt när hen avgör om
spelet är en kopia. Det är därför presentationen måste bära, och varför §6 är den dyraste
delen av det här dokumentet.

---

## 2. De tre lägena

| | Gravitationsvänd | Impuls | Tub |
|---|---|---|---|
| Geometri | Kanal, golv och tak | Kanal, golv och tak | Sluten slinga med fyra väggar |
| Vad ett tap gör | Vänder accelerationens tecken | Sätter vertikal hastighet | Flyttar `downWall` ett steg medsols |
| Analog axel | ingen | variabel hopphöjd | ingen |
| Färdighet | Precision i ytväxling, luftkorrigering | Uthållig höjdkontroll | Rumslig orientering, kedjade vridningar |
| Vänder ett tap dragriktningen? | Alltid | — | **Ungefär vartannat** — se §3.5 |
| Kameraram | Sidovy med djup | Sidovy med djup | Bakifrån, ner genom tuben |
| Innehållspool | delad med impuls | delad med gravitationsvänd | egen |

De två kanallägena ser identiska ut och skiljer sig bara i tappets betydelse. Tuben kan inte
förväxlas med någondera — geometrin annonserar sig själv. **Det tredje läget är därför det
säkraste av de tre**, och ökar inte lägesförvirringsrisken.

`Tuning.mode` är fortfarande bara *startläget*. Det aktiva läget bor i `SimState`.

---

## 3. Tubens simuleringsmodell

Tuben är inte en ny fysikmodell. **Det är kanalen böjd till en sluten slinga.** Det är ett
falsifierbart påstående, och §11 låser det med ett test.

### 3.1 Simuleringen är formagnostisk [R]

`theta` parametriserar en sluten slinga med omkrets 4, mätt i kvartsvarv. **Simuleringen vet
ingenting om slingans form.** Att den ritas som en fyrkantig tub är ett renderingsval (§6),
inte ett fysikval.

Första utkastet lät tuben vara kvadratisk hela vägen ner i kärnan, och det gick inte ihop:
med gravitationen vinkelrät mot en *plan* vägg har figuren ingen unik viloposition — den
glider till väggen och stannar var som helst i sidled — medan modellen ändå klampade `theta`
vid väggens mitt. Dessutom skiljer båglängd och vinkel en faktor 2 mellan väggmitt och hörn
på en kvadrat, så `theta` kunde inte betyda båda.

Den formagnostiska modellen löser bägge: `theta` är en abstrakt frihetsgrad med konstant
acceleration mot `downWall`, precis som `y` har konstant acceleration mot golvet. Renderaren
avbildar `theta` **uniformt på slingans omkrets**, så en kvadratisk tub får fyra lika långa
sidor och figuren rör sig med jämn fart längs varje sida.

**Följd för konsten:** gravitationen drar mot väggens *mitt*. Det är en spelregel, inte
fysik, och den är vad som gör en vägg till en *plats* istället för en yta — utan den finns
ingen viloposition att förankra innehåll i. Sidorna ritas därför med en grund konkav profil,
så att vilopunkten läses som naturlig istället för godtycklig.

### 3.2 Avbildningen

| Kanalen | Tuben |
|---|---|
| `y` — position mellan golv och tak | `theta` — position på slingan, i **kvartsvarv** |
| `vy` — vertikal hastighet | `vTheta` — kvartsvarv per sekund |
| `gravity: Sign` — golv eller tak | `downWall: UInt8` — vilken av fyra väggar som drar |
| Tap vänder `gravity` | Tap ökar `downWall` med 1 (mod 4) |
| `y` klampar vid `floorY` / `ceilingY` | `theta` klampar vid `downWall` |

Väggindex växer medsols sett från kameran i tubramen, alltså `0 → 1 → 2 → 3 → 0`. Det är
samma sak sagt två gånger, avsiktligt: teckenfel i den här riktningen är osynliga i ett test
som bara mäter varaktighet.

### 3.3 Vinkelrymd, inte kartesisk rymd

`theta` är tillståndet. Slingans radie och form förekommer **aldrig** i simuleringen. Följden
är att inga transcendentaler behövs i stegloopen och att determinismreglerna i CLAUDE.md
gäller oförändrat.

```
alphaMagnitude = 2 / flipDuration²        [kvartsvarv/s²]
```

Ett kvartsvarv från vila (`Δtheta = 1`) tar då exakt `flipDuration`.

### 3.4 Vad `flipDuration` bevarar, och vad den inte gör [R]

Första utkastet påstod att `flipDuration` och `flipFootprint` behåller sin betydelse. Det är
sant per **tap** och falskt per **traversering**, och skillnaden är en faktor `√2`:

| | Kanalen | Tuben |
|---|---|---|
| Ett tap → atomärt drag | golv → tak | ett kvartsvarv |
| Tid för det draget | `flipDuration` = 0,220 s | `flipDuration` = 0,220 s |
| Horisontellt avtryck per tap | `flipFootprint` | **samma** |
| Motsatt sida (vägg 0 → vägg 2) | `flipDuration` | `√2 · flipDuration` = 0,311 s |

**Vad som bevaras är avtrycket per tap**, och det är den storhet `flipFootprint` faktiskt
mäter — CLAUDE.md kallar den den enda konstant spelaren känner. Vad som *inte* bevaras är
traverseringen: tuben är 41 % tyngre att korsa från en sida till den motsatta, eftersom det
kräver två tap som inte kan slås ihop till ett.

Alternativet vore `alphaMagnitude = 4 / flipDuration²`, vilket bevarar traverseringen men
gör varje tap till `0,71 · flipDuration`. Det förkastas: tappet är spelets enhet, och att
göra tubens tap snabbare än kanalens skulle bryta den enda konstanten spelaren känner för
att rädda en analogi hen aldrig mäter. **Tyngden är en grindfråga** (§14).

### 3.5 Svävandet har en tröskel som kanalen saknar [R]

Hållamplituden i tuben är

```
A = T² / (2 · flipDuration²)              [kvartsvarv]
```

vilket är huvudspecens `A = h·T²/(2·t_f²)` med `h = 1`. Formeln är densamma. **Beteendet är
det inte**, av två skäl:

1. **Normeringen.** 0,161 kvartsvarv av ett spann på 2 kvartsvarv är 8,1 %, mot kanalens
   16,1 % av `usableHeight`. Samma formel, halva den relativa trängheten.
2. **Enkelriktningen bryter modellen.** Formeln förutsätter att ett tap *vänder*
   accelerationen. I tuben gör det inte det — `downWall += 1` vänder dragriktningen först
   när väggen passerat figuren, alltså ungefär vartannat tap.

Konsekvensen är mätt, inte gissad: vid 8 tap/s **cirkulerar figuren hela tuben** istället
för att hålla en position. Tröskeln ligger vid ungefär 11,3 tap/s, alltså `√2 ×` kanalens 8.
Under den kollapsar svävandet helt.

Det är en **egenskap, inte en defekt.** Kanalen har ingen sådan tröskel — där breddas bara
korridoren när tempot sjunker. Enkelriktad rotation ger tuben en skarp färdighetströskel,
vilket är precis vad tier 5–6 behövde. Den säljs ändå inte in som identitet: den är djup för
den som hittar den, aldrig ett krav, samma position som variabel hopphöjd fick i tredje
passet.

### 3.6 Wrappen [R]

`theta` hålls i `[0, 4)`. Första utkastet påstod att `theta ± 4.0` är exakt eftersom fyra är
en tvåpotens. **Det är sant åt ena hållet och falskt åt det andra:**

- `theta − 4.0` för `theta ∈ [4, 8)` är exakt. Resultatet är en multipel av samma ulp och
  ryms i `[0, 4)`.
- `theta + 4.0` för ett litet negativt `theta` är **inte** exakt: `(−2⁻⁵³) + 4.0 == 4.0`,
  vilket ligger *utanför* `[0, 4)`. Felet gäller varje `|theta| < 2⁻⁵²`.

Den farliga grenen var alltså precis den som kallades exakt. Normaliseringen sker därför med
**subtraktion i båda riktningarna**, och invarianten `0 ≤ theta < 4` assertas efter
normalisering istället för antas. Låst av `thetaWrapIsExactInBothDirections`.

### 3.7 Kollisionen måste vara modulär [R]

Första utkastet påstod att det svepta AABB-testet i `Collision.swift` fungerar oförändrat på
`(x, theta)`. **Det gör det inte.** `Sweep.slab` är ett linjärt min/max-test utan modulär
aritmetik, och en vägg `w` med centrum vid `theta = w` spänner `[w − 0.5, w + 0.5)` — vilket
för vägg 0 inte är ett intervall i `[0, 4)`. En figur vid `theta = 3.9` överlappar vägg 0
men testas mot `[−0.5, 0.5]` och missar. Det drabbar exakt den vägg `downWall := 0` (§4) gör
till vanligaste ingångsväggen.

Motiveringen i första utkastet — *"ett svep kan aldrig korsa wrappen, eftersom ett svep är
ett steg"* — blandade ihop rörelsens **storlek** med dess **position**. Ett svep på 0,054
kvartsvarv korsar `theta = 0` utmärkt väl (3,98 → 4,03) och gör det rutinmässigt.

**Rätt konstruktion:** jämför inte `theta` mot ett intervall, utan mot den wrappade
differensen.

```
d = theta − w                    // kan hamna utanför [−2, 2)
d = d − 4·round(d / 4)           // exakt: 4 är en tvåpotens, |d| < 8
träff  ⟺  x-intervallen överlappar  ∧  |d| ≤ 0.5 + vinkelhalvbredd
```

En subtraktion och en villkorad korrigering. Inga transcendentaler, ingen `Set`-iteration,
ingen sort. `Sweep.slab` behålls oförändrad för `x`-axeln, som inte är periodisk; den nya
modulära jämförelsen ersätter den bara för `theta`.

Vinkelhalvbredden är `(characterHeight / 2) / channelHeight` = 0,1 kvartsvarv med
referenstrimningen. Figuren täcker alltså 20 % av en vägg, vilket speglar `20/100` i
kanalen.

**Om hörn:** en figur vid `theta = w + 0.5` överlappar båda angränsande väggarna. Första
utkastet kallade det en emergent egenskap; det är det inte — det gäller för varje
vinkelhalvbredd större än noll och är en direkt följd av att figuren har utsträckning. Det
är ändå värt att känna till, eftersom det gör hörn riskabla och gäller 20 % av
`theta`-rymden. Validatorn mäter konsekvensen. Vi designar inte mot den, och låser den med
ett test så att den inte tystnar av en refaktorering.

### 3.8 Tunnling

Maximal fart är `√(2 · alphaMagnitude · 2)` = 12,86 kvartsvarv/s, alltså `|Δtheta| ≤ 0,054`
per steg. Att ett svep inte kan täcka hela slingan följer av den gränsen — inte av att ett
steg är kort — och marginalen är 74×. Det svepta testet behövs ändå: det är fartgränsen som
gör tunnling omöjlig, och fartgränsen är en konsekvens av trimningen, inte en garanti.

---

## 4. Övergångar

**Princip: en portal flyttar aldrig figuren till en position spelaren inte kunde förutse.
Övergångar är geometriska projektioner, inte teleporteringar.**

| Övergång | Regel |
|---|---|
| Kanal → tub | `y` avbildas **linjärt** på `theta ∈ [0, 2]`: golv → vägg 0, tak → vägg 2. `vy → vTheta` med samma skala. `downWall := 0`. |
| Tub → kanal | `theta` avbildas **linjärt** tillbaka: vägg 0 → golv, vägg 2 → tak, vägg 1 och 3 → mitten. `vTheta → vy` med samma skala. `gravity := .down`. |
| Kanal → impuls | Oförändrat: `gravity := .down`. Se beslutsloggen, fjärde passet. |

### 4.1 Linjär, inte visuell [R]

Avbildningen är linjär, och det är ett val med en mätt kostnad. Den *visuella* höjden av en
punkt på slingan är `R·cos(theta·π/2)`. Vid väggcentra (`theta = 0, 1, 2`) sammanfaller den
med den linjära avbildningen **exakt**. Däremellan avviker de som mest **0,105 av
`usableHeight`**, vilket är 1,05× `nearMissClearance` — alltså inte försumbart.

Den visuella avbildningen förkastas ändå, eftersom `cos` i `OMTCore` skulle bryta både
transcendentalregeln och importförbudet i CLAUDE.md.

Avvikelsen hanteras i stället där den hör hemma: **svepet (§5.2) är det som förenar de två
projektionerna visuellt.** Kameran rör sig från tubramen till kanalramen under en känd
varaktighet, och figurens ritade position interpoleras över samma intervall. Det gör svepet
bärande istället för dekorativt, och det är skälet att ett hårt snitt inte är gratis.

Testet heter därför `portalTransitionsPreserveRelativePosition`, inte `…ScreenPosition`: det
som bevaras är figurens relativa position i spelfältet, och pixeln är svepets ansvar.

### 4.2 Fallriktningen måste tie-breakas [R]

`downWall := 0` respektive `gravity := .down` vid inträde är samma regel som redan gäller
impulsläget: ett tap får inte göra motsatsen till vad spelaren förväntar sig direkt efter
bytet.

Men regeln har ett hål. En spelare som passerar portalen hängande i **taket** avbildas på
vägg 2, och `downWall := 0` ligger då på avstånd exakt 2 åt **båda** hållen — en symmetrisk
instabil jämvikt. Fallriktningen är odefinierad, alltså determinismkritisk.

**Regel:** vid `|theta − downWall| == 2` faller figuren i **växande `theta`-riktning**, samma
riktning som ett tap roterar. Motivet är att spelaren redan har en riktningsmodell från
tappet och inte behöver en andra. Låst av `symmetricEntryFallsInTapDirection`.

### 4.3 Fallets längd

Fallet från motsatt vägg tar `√2 · flipDuration` = **0,311 s**, inte `flipDuration`. Första
utkastet påstod att detta är "exakt vad `gravity := .down` redan gör i kanal → impuls" — det
är fel: kanalens fall från taket tar 0,220 s. Samma `√2` som i §3.4.

Säkerhetszonens `after` (§7) måste därför rymma **det längsta fall någon övergång kan
orsaka**, alltså 0,311 s, plus svepet, plus återanskaffningstiden.

---

## 5. Kameraramar och svepet

### 5.1 Två ramar, av läsbarhetsskäl

| | Kanalen | Tuben |
|---|---|---|
| Ram | Sidovy med djup. Spelplanet frontoparallellt; golv, tak och bakgrund har verklig geometri. | Kameran bakom figuren, blicken ner genom tuben. |
| Varför | `nearMissClearance` är 10 % av kanalhöjden. I perspektiv är det ett par pixlar, och spelet blir oläsligt. Ett frontoparallellt spelplan bevarar dagens läsbarhet exakt. | En tub sedd från sidan projicerar vägg 1 och vägg 3 till samma vertikala position. Oläsbart utan ocklusion. |
| Framförhållning | `playerX = playfieldRight − fixedLookaheadPx`, oförändrat från §10 | Fast **tidshorisont** av synlig korridor — samma rättviseregel uttryckt i djup istället för bredd |

### 5.2 Svepet

Portalen mellan två ramar spelas som en snabb kamerarörelse, inte ett hårt snitt. Fem
villkor gör det säkert:

1. **Fast, känd varaktighet.** Säkerhetszonen måste kunna budgetera den.
2. **Zonen växer med svepet:** `after ≥ fall + svepvaraktighet + återanskaffningstid`.
3. **Simuleringen pausar aldrig.** Figuren rör sig under svepet, och svepet konsumerar bana.
   Zonen mäter det i världsenheter.
4. **Svepet sväljer aldrig input.** Ett tap under svepet är speldata och ligger i replayen.
   Kameran är presentationslager och får inte ha en åsikt om tappet.
5. **Kameran hamnar aldrig i `SimState`.** Svepet drivs av `state.step − modeChangedStep`.
   Följd: en replay ser exakt likadan ut som körningen, och tappade frames flyttar aldrig
   kameran ur fas med simuleringen.

**`modeChangedStep` bor i `SimState`** — inte i renderaren. [R] Bara där uppfylls både
omstartsregeln (`state = SimState.initial(...)` och inget annat) och replay-identiteten; i
renderaren lämnar en omstart mitt i svepet kameran mitt i svepet. Att lagra *steget* i
`SimState` sätter inte kameran där: steget är speldata, kameramatrisen är en ren funktion av
det.

**Varaktighet: ett åttondelsslag vid tierns BPM, alltså `30 / BPM`.** [R] Första utkastet sa
"ett taktslag, klampat till `[0,15 s – 0,30 s]`", men ett taktslag vid spelets enda angivna
tempo (140 BPM) är 0,43 s. Klampen hade varit aktiv i varje tänkbart tier, så svepet hade i
praktiken alltid varit 0,30 s och BPM-kopplingen ren dekoration. Ett åttondelsslag ger
**0,214 s vid 140 BPM** — inom intervallet, nära `flipDuration` = 0,22 s, och rytmiskt
justerat på riktigt. Klampen `[0,15 s – 0,30 s]` behålls som skydd mot extrema tier-tempon.

### 5.3 Tillgänglighet [R]

`isReduceMotionEnabled` på → hårt snitt. Av → svep.

**De två varianterna är lika rättvisa i hindermarginaler**, eftersom säkerhetszonen
dimensioneras för den långsammare av dem. Ingen tillgänglighetsinställning ändrar
svårigheten.

Men första utkastet stannade där, och det var för tidigt. **Det hårda snittet är vad
reduce-motion slår på, och ett snitt är ett helskärmsbyte av både kameraram och palett**
(§9), flera gånger per 60-sekunderskörning, ovanpå dödsblixtarna. CLAUDE.md kräver begränsad
blixtfrekvens och luminansdelta. Alltså:

- Snittet har en **egen luminansdeltabudget** och räknas in i blixtfrekvensen.
- Snittet omfattas av **"reducera blinkningar"**. Är den påslagen korsfadar ramen över
  ~80 ms istället för att snitta — kortare än svepet, utan rörelse, och utan ett
  luminanssteg i en frame.
- Sekventiella portaler får inte ge två snitt inom blixtfrekvensens fönster. Det är en undre
  gräns på portalperioden, och den hör hemma i §7 tillsammans med zonen.

**Kameran rullar aldrig i tuben.** Figuren orbiterar; tuben står still. En tub som roterar
runt en stillastående figur är en vestibulär trigger, och rotationen *är* speltillstånd — den
kan inte grindas bort. En figur som orbiterar runt en stillastående tub bär samma
information utan att vrida spelarens referensram.

Det argumentet utesluter **rull**, och bara rull. [R] Det säger ingenting om det andra skälet
reduce-motion finns för tunnelvyer: storfältigt radiellt optiskt flöde från väggar som
strömmar mot kameran. Det behöver en egen dämpning — reducerad väggtextur och färre
fartstreck när inställningen är på — och den dämpningen får inte ändra tubens läsbarhet,
eftersom väggarna bär innehållet. Mäts på grinden.

Det är också skälet att en tidigare ansats — att rulla kameran 90° runt färdriktningen i
kanalen — lades ner: där bar rotationen **information**, så en grind hade gjort spelet
ospelbart, och att grinda den hade gett två olika svårighetsgrader. Svepet bär ingen
information, eftersom zonen garanterar att det inte finns något att läsa under det.

---

## 6. Perspektiv och pixel art

### 6.1 Pixelrutnätet tillhör offscreen-targeten, inte sprites

Huvudspecens §10 gör offscreen-targeten bärande, väljer heltalsfaktorn `k` per enhet och
håller spelfältsrektangeln på en fast texelstorlek inuti texturen. Det är precis den
arkitektur som gör perspektiv-3D med pixel art möjlig:

När 3D:n rastreras **in i** den lågupplösta targeten kvantiseras perspektivet automatiskt
till det virtuella rutnätet. Ett hinder på avstånd blir klumpiga texlar av sig självt.
Färgrymdsreglerna är oförändrade; heltalsblitten till skärmen är oförändrad.

### 6.2 Undantaget i snappningsregeln, avgränsat [R]

CLAUDE.md och huvudspecens §10 säger: snappa kamera och spritepositioner till hela virtuella
pixlar efter interpolation. Första utkastet skrev om regeln till "gäller HUD och skärmrymd",
vilket var för brett — **att kameran snappas är vad som gör blitten till heltalsreplikering
och dödar
shimret.** Undantaget avgränsas därför till:

> **Vertexpositioner för icke-frontoparallell geometri snappas inte.** Allt annat — kameran,
> HUD:en, och spelplanets frontoparallella element i kanalramen — snappas som förut.

Kanalens spelplan är frontoparallellt (§5.1) och räknas alltså **inte** som geometri i
perspektiv: det snappas, och bevarar dagens läsbarhet exakt. Undantaget gäller i praktiken
väggar, tub och bakgrundsgeometri som har djup.

**Priset:** avlägsen geometri kan poppa när vertexar rör sig mindre än en virtuell pixel per
frame. Det är Mode 7-artefakten, alltså i stil snarare än utanför den. Skrivet här för att
det ska vara ett val och inte en upptäckt.

**Följdändring:** CLAUDE.md:s renderingsavsnitt behöver den här avgränsningen inskriven,
ordagrant.

### 6.3 Moderna effekter

| Effekt | Beslut |
|---|---|
| Bloom / glöd | **I den lågupplösta bufferten, före uppskalning.** Full upplösning ovanpå klumpiga pixlar läser som fake retro. §10 tillåter redan blending i posteffekterna. |
| Palettbyte per läge | **Ja, och gratis.** Palettswap är den autentiska 16-bitarstekniken, och §9 kräver ändå en palett per läge. Luminansdeltat budgeteras enligt §5.3. |
| Chromatic aberration, shake, blixtar | Tillåtna, grindade av `isReduceMotionEnabled`. Oförändrat. |
| Radiellt flöde i tuben | Dämpas när reduce motion är på. Se §5.3. |
| Scanlines | Valfria. Läser som emulator snarare än som konsol; svag rekommendation mot. |
| CRT-kurvatur | **Nej.** Distorderar spelfältet och därmed rättvisan, och slåss med perspektivet. |

### 6.4 Silhuettaket

CLAUDE.md: fara får aldrig kodas med enbart färg — form och silhuett måste bära den. I
perspektiv krymper avlägsna silhuetter. Det sätter ett **tak** på framförhållningen: bortom
en viss punkt är ett hinder synligt men inte läsbart, vilket är värre än att inte se det.
Taket mäts på grinden, per kameraram.

---

## 7. Säkerhetszonen

Prototypens `guardZone(for:)` i `App/GameModel.swift` står som TODO med en gissad symmetrisk
halvsekund. Det här dokumentet ger den sin betydelse:

**Zonens `after` är budgeten för visuell återanskaffning, plus det som händer med figuren
under tiden.**

Validatorn mäter `robustnessMs` genom simuleringen, men kan inte mäta hur lång tid en
människa behöver för att läsa om en ny kameraram. Det måste därför vara en innehållsregel.

```
after ≥ längsta fall (0,311 s vid tub-inträde)
      + svepvaraktighet (0,214 s vid 140 BPM)
      + visuell återanskaffningstid (mäts på grinden)
```

Följder:

- **Zonen är asymmetrisk.** Att läsa en portal i förväg är billigt; att omorientera efter den
  är inte det.
- **Zonen är per lägesövergång, inte en konstant.** Ett ramskifte (kanal ↔ tub) kräver mer än
  ett kontrollbyte (gravitationsvänd ↔ impuls), och bara ramskiftet bär ett fall.
- **Portalperioden har en undre gräns** från blixtfrekvensen i §5.3, oberoende av zonen.
- Återanskaffningstiden mäts på grinden. `guardZone(for:)` står medvetet kvar som TODO till
  dess, och signaturen behåller sitt `mode`-argument även medan det är oanvänt — hela poängen
  är att värdet ska bero på det.

**Känd fälla, dokumenterad:** om portalperioden är kort i förhållande till zonen slukar
zonerna all bana och inga hinder genereras alls. Verifierat i prototypen: vid period 0,7 s
med zonen 2 × 341 världsenheter genereras **0 hinder på 60 s**, mot 86 vid default 4,5 s.
Trimpanelen måste visa antalet genererade hinder, eller grinden kommer att köras på en tom
bana utan att någon märker det.

---

## 8. Innehåll och validator

### 8.1 Mönsterformat — kostnaden, ärligt [R]

`Surface` (golv/tak) generaliseras till `wall: UInt8`. Kanalen använder 0 och 2; tuben
använder 0–3. Ett `Pattern` får en `geometry`-tagg — `channel` eller `tube`. Biblioteket
förblir **ett delat bibliotek** enligt §5 i huvudspecen, inte en mapp per läge.

Första utkastet antydde att det är ett typbyte. Det är åtta produktionsställen i fem filer
plus sex testställen:

| Fil | Vad |
|---|---|
| `Collision.swift` | `enum Surface`, `Obstacle.surface`, och `box()` som är rent kartesisk |
| `Simulation.swift` | dödsorsakens val, near-miss-`clearance` vars tecken beror på ytan, och klampningen mot `floorY`/`ceilingY` |
| `Events.swift` | **`DeathCause { floorObstacle, ceilingObstacle }`** |
| `GameModel.swift` | generatorns `(nextRandom() & 1) == 0`, en enbitsdragning som måste bli mod 4 |
| `ContentView.swift` | renderingens `y` |

**`DeathCause` är publikt API och kodar samma golv/tak-antagande binärt.** Fyra väggar kräver
antingen ett tredje fall eller en omdefinition till `obstacle(wall: UInt8)`. Det nämndes inte
alls i första utkastet och är den enskilt största dolda posten.

Noterat men inte planerat för: ett kanalmönster är formellt giltig tubgeometri med väggarna 1
och 3 tomma. Med medsols rotation kräver vägg 0 → vägg 2 två vridningar, så det är en
*annan* utmaning. Om validatorn råkar döma något sådant rättvist är det gratis innehåll.
Ingenting byggs för det.

### 8.2 Validatorn

Tredje passet. Samma beam search genom den riktiga simuleringen.

- **Förgreningsfaktorn är fortfarande 2.** Tap eller inte, per steg.
- **Tillståndsrymden växer 2×.** Kanalens diskreta dimension är `gravity` med två värden;
  tubens är `downWall` med fyra. Beamens bredd kan behöva höjas — en prestandafråga, inte en
  korrekthetsfråga.
- `reachableExits` och `survivableEntries` mäts i `(wall, theta, vTheta)` istället för
  `(y, vy)`. Skarvmaskineriet generaliseras utan omskrivning; det mätte redan tillstånd, inte
  koordinater.

### 8.3 Balansgrindarna generaliseras [R]

Huvudspecens §5 grindar att varje tillstånds **utgrad ≥ 12** och att mönstrens **stationära
fördelning ligger inom 60/40**. Första utkastet nämnde bara `robustnessMs` per läge och
lämnade grindarna odefinierade för fyra väggar — trots att felläget de finns för, bias mot en
enskild vägg, blir värre med fyra väggar, inte bättre.

| Grind | Kanalen | Tuben |
|---|---|---|
| Utgrad | ≥ 12 per tillstånd | ≥ 12 per tillstånd, oförändrat |
| Fördelning | inom 60/40 över två ytor | **ingen vägg under 15 % eller över 40 %** av den stationära fördelningen |

15/40 är den naturliga generaliseringen: jämn fördelning är 25 %, och gränserna ligger
proportionellt lika långt från den som 40/60 ligger från 50. Siffrorna är en utgångspunkt för
grinden, inte ett härlett resultat — men en odefinierad grind är värre än en grov.

### 8.4 Tier-ordningen

Ordningsvariabeln i huvudspecens §3 — max antal flippar i följd i luften — blir i tuben max
antal **kedjade vridningar**. Samma skala och samma monotonitet, men **inte samma kostnad per
steg**: en kedjad vridning är ett kvartsvarv, inte en hel traversering (§3.4). Stegen behöver
därför omkalibreras, inte bara återanvändas. Tuben ger tier 5–6 en ny färdighet istället för
snävare marginaler, vilket var den kostnad huvudspecens §3 uttryckligen noterade — och
tröskeln i §3.5 är den skarpaste ordningsvariabel designen har.

### 8.5 CI

`robustnessMs` grindas per läge, nu tre istället för två. **Omvalidering krävs när en tiers
`flipDuration` ändras** — oförändrad regel, en dimension mer.

---

## 9. Ljud, haptik, palett

Regeln från fjärde passet står oförändrad: bytet bärs av figurens utseende, paletten **och**
ljudets tonhöjd samtidigt.

- Tredje portalröst för tuben. De två befintliga är kvintstaplade svep — 330→990 Hz för
  impuls, 990→330 Hz för gravitation — så tubens röst måste skilja sig i klangfärg, inte bara
  i tonhöjd.
- Egen palett och egen figurfärg per läge. Implementerat för två lägen; utökas till tre.
  Luminansdeltat vid palettbytet budgeteras enligt §5.3.
- Dubbeltransient vid lägesbyte. Oförändrad.

---

## 10. Konstpipelinens kostnad

Detta är designens största enskilda kostnad, och den ska stå tydligt.

Huvudspecens §11 förrenderar sprites från Kenney CC0-modeller med **ortografisk** kamera och
slår fast att "ingen modellering och ingen riggning krävs". Två kameraramar betyder **en
renderuppsättning per ram**: sidovy för kanallägena, bakifrån för tuben.

- Bakifrån behöver färre frames — ingen ansikts- eller profildetalj — men det är ändå en
  andra uppsättning animationer.
- Figuren förblir en förrenderad billboard. Det fungerar eftersom kameraramen är **fast per
  läge**; en fri kamera hade krävt riktig 3D-figur och hade brutit hela §11.

**Miljögeometrin är författad 3D och bryter mot §0:s låsta konstkälla.** [R] Kanalväggar och
tub kommer inte ur sprite-pipelinen, och att bygga dem *är* modellering. Det är en ändring av
ett låst beslut och står därför i §0:s tabell. Konsekvens: miljögeometrin omfattas
fortfarande av CC0-regeln och ska föras in i `Art/CREDITS.md` med källa, licens och datum —
även när den är författad i projektet, för då är projektet källan och licensen måste anges
ändå.

Regeln i huvudspecens §11 att konstpipelinen byggs **efter** fun-grinden gäller oförändrat,
och blir viktigare: det är nu dubbelt så mycket arbete att kasta.

---

## 11. Teststrategi

### 11.1 Kärnan

Tubens tester speglar kanalens. Om påståendet i §3 är sant ska samma formler gälla.

| Test | Vad det låser |
|---|---|
| `aQuarterTurnFromRestTakesFlipDuration` | Avbildningen av `g = 2h/t²` till vinkelrymd |
| `oppositeWallTraverseTakesSqrtTwoFlipDurations` | §3.4 — att `√2` är avsiktligt och inte en bugg |
| `orbitalHoldAmplitudeMatchesTheAnalyticFormula` | **4x `hoverAmplitudeMatchesTheAnalyticFormula`s formel, med `h = 1`** — `downWall`s 4-lägesvarv (§3.5) ger en naturlig period på `4 · halfPeriod` istället för kanalens `2 · halfPeriod`, och amplituden skalar med periodens kvadrat. Se `docs/decision-log.md` 2026-09-14. Om faktorn inte gäller är det inte samma integration, och §3 är fel. |
| `orbitalHoldCollapsesBelowTheDirectionalThreshold` | §3.5 — att figuren cirkulerar under ~11,3 tap/s. Egenskapen, inte defekten. |
| `thetaWrapIsExactInBothDirections` | §3.6 — inklusive det lilla negativa fallet som `+ 4.0` inte klarar |
| `collisionWrapsAcrossWallZero` | §3.7 — en figur vid `theta = 3.9` träffar ett hinder på vägg 0 |
| `cornerOverlapsBothAdjacentWalls` | §3.7 — så att hörnexponeringen inte tystnar av en refaktorering |
| `fastRotationCannotTunnelThroughAWallObstacle` | §3.8 — att det svepta testet gäller i `(x, theta)` |
| `enteringTubeModeSetsDownWallToZero` | Spegling av `enteringImpulseModeForcesGravityDown` |
| `symmetricEntryFallsInTapDirection` | §4.2 — tie-breaket. Utan det är övergången icke-deterministisk. |
| `portalTransitionsPreserveRelativePosition` | §4.1, båda riktningarna |

Determinismgrinden kör allt detta i `-c debug` **och** `-c release`:

```bash
swift test --package-path Packages/OMTKit
swift test --package-path Packages/OMTKit -c release -Xswiftc -enable-testing
```

Fyrar den: hitta orsaken, höj inte toleransen.

### 11.2 Golden-test

En inspelad körning som passerar **båda** portaltyperna reproduceras ur
`(simVersion, contentHash, tierID, seed, tapSteps)`. Det är här tryck/släpp-**paret** i
inputformatet bevisar sitt värde: en replay som bara lagrat nedtryck kan inte återskapa en
kedjad vridning.

### 11.3 Renderaren

Utseendet går inte att enhetstesta. Tre invarianter går:

- **Blitten är exakt heltalsreplikering.** Rendera ett känt mönster till targeten, läs
  tillbaka, verifiera att ingen interpolation skett.
- **Svepet är en funktion av stegdelta.** Samma steg in ger samma kameramatris ut, oberoende
  av frametid.
- **Kameran snappas fortfarande.** §6.2 — undantaget gäller vertexar, inte kameran, och en
  regression där är osynlig i en skärmbild men syns som shimmer i rörelse.

### 11.4 Vad som inte testas

Om det är roligt. Det är grinden.

---

## 12. Ordning, och grindberoendet

`CLAUDE.md`: *"Fun-grinden ligger på dag 3, inte i slutet. Innan den är passerad: bygg inget
som skulle kastas om mekaniken visar sig tråkig."*

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
oberoende leveranser — perspektivrenderaren, tuben i kärnan, innehållet och konstpipelinen —
och ska bli **var sin plan**. Steg 3 delar ingen fil med steg 2 och kan planeras utan att
steg 2 är beslutat i detalj.

---

## 13. Icke-mål

- **Fri kamera.** Ramen är fast per läge. En fri kamera bryter §10:s förrenderade billboards
  och därmed hela konstpipelinen.
- **Två inputaxlar.** One-tap är låst. Tuben är 1-DOF, precis som kanalen.
- **Ett fjärde läge.** Tre är vad tier-stegen behöver. Fler pooler är innehållsfällan
  huvudspecens §3 avvisar.
- **Att tuben ska ha en impulsvariant.** Tre lägen, inte fyra.
- **Riktig fysik i tuben.** Gravitationen drar mot väggens mitt därför att det gör väggen
  till en plats. En pendelmodell vore fysikaliskt riktigare, kräver `sin`, och ger sämre
  spel.
- **CRT-kurvatur.** Se §6.3.
- **Att dimensionsbytet blir hela spelet** istället för ett läge bland tre. Det vore en fjärde
  ansats och en större omskrivning; den är inte utredd och inte förkastad.

---

## 14. Öppna frågor

1. **Säkerhetszonens återanskaffningstid per lägesövergång.** Fall och svep är räknade (§7);
   den mänskliga delen mäts på grinden. `guardZone(for:)` står som TODO till dess.
2. **Tubens tyngd.** `√2 · flipDuration` för en traversering (§3.4) är ett medvetet val. Känns
   tuben trög eller tyngd? Grindfråga, och den enda som kan omvärdera `alphaMagnitude`.
3. **Tröskeln vid ~11,3 tap/s** (§3.5) — djup eller en vägg? Den är skarp, och skarpa
   trösklar är antingen det bästa eller det värsta i ett färdighetsspel.
4. **Silhuettaket** — hur långt framförhållningen får sträcka sig innan hinder är synliga men
   oläsliga. Mäts per kameraram. Se §6.4.
5. **Virtuell upplösning.** Fortfarande öppen från huvudspecen, och nu mer bindande:
   perspektivet gör pixelstorleken till en läsbarhetsfråga och inte bara en stilfråga.
6. **Beamens bredd** för tuben, givet 2× tillståndsrymd.
7. **15/40-gränserna i §8.3** är en utgångspunkt, inte ett härlett värde.
8. **Radiella flödets dämpning** (§5.3) får inte kosta läsbarhet. Mäts på grinden med
   inställningen på.
9. **Är tre lägen för mycket för 60 sekunder?** Om varje läge behöver en säkerhetszon och en
   etablerande passage kan en 60-sekunderskörning sakna plats för alla tre. Kan bli en
   tier-ordningsfråga: tier 1–2 i ett läge, tuben introducerad i tier 3.

---

## 15. Vad detta dokument *inte* löser

Att tre lägen som blandas vid portaler fortfarande är Geometry Dash-arkitekturen. §6 gör
innehållet och utseendet distinkt; **formen är det inte.** Det är ett medvetet val med en
uttalad grund: §15.5 säger att konkurrensen ligger på känsla och presentation, och en mättad
genre besegras inte med en fjärde mekanikvariant.

Om det visar sig otillräckligt på grinden är nästa steg inte ett fjärde läge, utan
icke-målet i §13: att låta dimensionsbytet vara hela spelet.
