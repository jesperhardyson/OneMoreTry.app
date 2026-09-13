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
