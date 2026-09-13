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
