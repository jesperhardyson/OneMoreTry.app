# Tube Mode Core Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the third control mode — traversing a closed tube instead of a channel — to `OMTCore`, including its physics, wall collision, and channel↔tube portal transitions. No rendering, no app wiring, no content authoring.

**Architecture:** The tube reuses the existing `SimState`/`Tuning`/`Simulator.step` machinery rather than a parallel simulator. `theta`/`vTheta`/`downWall` are new fields alongside the existing `y`/`vy`/`gravity`, unused when `mode != .tube`, exactly like `gravity` is unused (but not removed) once a run leaves the channel today. A new `Angle` module holds the two pieces of periodic-domain math (wrap, wrapped delta to a wall) that both the physics step and the collision test need, so neither duplicates the other's modular arithmetic. Wall obstacles get their own lightweight type (`WallObstacle`) rather than overloading `Obstacle`, because a wall obstacle has no independent "height" — its hit zone is a fixed angular band around the wall, derived from `Tuning`, not from the obstacle.

**Tech Stack:** Swift 6.3, `swift-testing` (`@Test`, `#expect`), Swift Package Manager (`Packages/OMTKit`).

**Spec:** `docs/superpowers/specs/2026-09-13-three-modes-and-perspective-design.md` §3 (tube simulation model), §4 (transitions), §11.1 (required test names). Parent spec: `docs/superpowers/specs/2026-09-13-one-more-try-design.md`.

## Global Constraints

- `OMTCore` imports nothing — not Foundation, not UIKit, not Metal. `sqrt`/`.squareRoot()` is the only allowed non-arithmetic math; no `sin`/`cos`/`pow`/`exp`/`atan2`.
- No `Set`/`Dictionary` iteration anywhere in `OMTCore`. Arrays only.
- `sort()` (if ever needed) requires a total-order comparator; not used in this plan.
- Never `shuffled(using:)` or `Double.random(in:using:)`. Not used in this plan (no randomness needed).
- `step: UInt32` is the truth; never accumulate `Double` time. Not touched by this plan beyond reading `Simulator.dt`.
- The determinism gate runs the same test in `-c debug` and `-c release`. If it fails in release only, find the root cause — never raise the tolerance.
- `public` types get explicit `Sendable`, never implicit.
- Documentation comments in Swedish, code identifiers and commit messages in English (existing file convention — follow it).

---

## File Structure

- **Create:** `Packages/OMTKit/Sources/OMTCore/Angle.swift` — periodic-domain math (`wrap`, `wrappedDelta`) shared by physics and collision. New file because it's genuinely reusable, tiny, and has no dependency on `SimState`.
- **Modify:** `Packages/OMTKit/Sources/OMTCore/Simulation.swift` — `ControlMode.tube` case, `Tuning.alphaMagnitude`/`.angularHalfWidth`, `SimState.theta`/`.vTheta`/`.downWall`, tube integration branch and tap handling in `Simulator.step`, portal-transition mapping.
- **Modify:** `Packages/OMTKit/Sources/OMTCore/Collision.swift` — `WallObstacle`, `Sweep.hitsWall`.
- **Modify:** `Packages/OMTKit/Sources/OMTCore/Events.swift` — `DeathCause.wallObstacle`.
- **Create:** `Packages/OMTKit/Tests/OMTCoreTests/TubeTests.swift` — all tube-specific tests, kept separate from the existing channel/impulse/portal tests in `SimulationTests.swift` rather than growing that file further.

---

### Task 1: Angle module

**Files:**
- Create: `Packages/OMTKit/Sources/OMTCore/Angle.swift`
- Test: `Packages/OMTKit/Tests/OMTCoreTests/TubeTests.swift`

**Interfaces:**
- Produces: `Angle.wrap(_ theta: Double) -> Double` (normalizes to `[0, 4)`), `Angle.wrappedDelta(_ theta: Double, _ w: Double) -> Double` (shortest signed distance from `theta` to `w`, in `[-2, 2)`).

- [ ] **Step 1: Write the failing tests**

```swift
import Testing
@testable import OMTCore

@Test func `theta wrap is exact in both directions`() {
    #expect(Angle.wrap(0.5) == 0.5)
    #expect(Angle.wrap(4.5) == 0.5)
    #expect(Angle.wrap(-0.5) == 3.5)
    #expect(Angle.wrap(4.0) == 0.0)
    #expect(Angle.wrap(0.0) == 0.0)

    // Adversarial: theta so close to 0 from below that a naive `theta + 4.0`
    // rounds to exactly 4.0, one full ulp outside [0, 4). Se spec §3.6 och
    // beslutsloggen. Invarianten far korrigeras, men far aldrig brytas.
    let tinyNegative = -0x1p-53
    let wrapped = Angle.wrap(tinyNegative)
    #expect(wrapped >= 0)
    #expect(wrapped < 4)
}

@Test func `wrapped delta finds the shortest signed distance to a wall`() {
    #expect(Angle.wrappedDelta(0.5, 0) == 0.5)
    #expect(Angle.wrappedDelta(3.5, 0) == -0.5)
    // 0.125/3.875/0.25 ar exakt representerbara i binart flyttal (2^-3, 31/8,
    // 2^-2), sa testet paverkas inte av flyttalsbrus fran subtraktionen —
    // 0.1/3.9 skulle inte vara det.
    #expect(Angle.wrappedDelta(0.125, 3.875) == 0.25)
    // Symmetriskt intrade: alltid -2, aldrig +2, oavsett argumentordning.
    // Se spec §4.2.
    #expect(Angle.wrappedDelta(2, 0) == -2)
    #expect(Angle.wrappedDelta(0, 2) == -2)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --package-path Packages/OMTKit --filter TubeTests`
Expected: FAIL to build — `Angle` does not exist.

- [ ] **Step 3: Write the implementation**

```swift
/// Vinkelrymden for tuben: en sluten slinga med omkrets 4, matt i kvartsvarv.
/// Formfri — simuleringen kanner aldrig till radien eller den faktiska formen.
/// Se spec §3.1, §3.3, §3.6, §3.7.
enum Angle {
    /// Normaliserar `theta` till [0, 4). En enkel `theta + 4.0` racker inte:
    /// for ett `theta` inom en ulp av 0 fran undersidan rundar additionen till
    /// exakt 4.0, vilket ligger utanfor det halvoppna intervallet. Darfor
    /// asserteras invarianten efter normaliseringen istallet for att antas —
    /// traffar vi 4.0 exakt, dras ytterligare en period bort.
    static func wrap(_ theta: Double) -> Double {
        var t = theta
        if t >= 4 {
            t -= 4
        } else if t < 0 {
            t += 4
        }
        if t >= 4 {
            t -= 4
        }
        return t
    }

    /// Kortaste signerade avstandet fran `theta` till vagg `w`, normaliserat
    /// till [-2, 2). Halvoppet, inte symmetriskt: `.rounded()` (round to
    /// nearest, ties away from zero) ar antisymmetrisk i sitt argument och
    /// ger -2 for ena argumentordningen men +2 for den andra vid exakt
    /// motsatt vagg — de tva representerar samma vinkel (2 ≡ -2 mod 4) och
    /// maste darfor mappas till samma varde. `.rounded(.down)` (golv) pa
    /// `(d + 2) / 4` gor det: bada -2 och +2 som ravarde hamnar i samma
    /// intervallhalva och normaliseras till -2. Se
    /// `symmetric entry falls in tap direction` for varfor det spelar roll.
    static func wrappedDelta(_ theta: Double, _ w: Double) -> Double {
        let d = theta - w
        return d - 4 * ((d + 2) / 4).rounded(.down)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --package-path Packages/OMTKit --filter TubeTests`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Packages/OMTKit/Sources/OMTCore/Angle.swift Packages/OMTKit/Tests/OMTCoreTests/TubeTests.swift
git commit -m "feat: add Angle module for tube-mode periodic math"
```

---

### Task 2: Tube physics — acceleration, tap, clamp

**Files:**
- Modify: `Packages/OMTKit/Sources/OMTCore/Simulation.swift`
- Test: `Packages/OMTKit/Tests/OMTCoreTests/TubeTests.swift`

**Interfaces:**
- Consumes: `Angle.wrap(_:)`, `Angle.wrappedDelta(_:_:)` from Task 1.
- Produces: `ControlMode.tube` case; `Tuning.alphaMagnitude: Double`, `Tuning.angularHalfWidth: Double`; `SimState.theta: Double`, `SimState.vTheta: Double`, `SimState.downWall: UInt8` (all default `0`); tube branch inside `Simulator.step` that later tasks (3, 4) extend.

- [ ] **Step 1: Write the failing tests**

```swift
@Test func `a quarter turn from rest takes flip duration`() {
    var t = Tuning.reference
    t.mode = .tube
    var s = SimState.initial(tuning: t)
    s.downWall = 1

    while s.theta < 1, s.step < 10_000 {
        s = Simulator.step(s, tuning: t, flip: false).state
    }

    let seconds = Double(s.step) * Simulator.dt
    #expect(s.theta == 1)
    #expect(abs(seconds - t.flipDuration) / t.flipDuration < 0.02)
}

@Test func `opposite wall traverse takes sqrt two flip durations`() {
    var t = Tuning.reference
    t.mode = .tube
    var s = SimState.initial(tuning: t)
    s.downWall = 2 // motsatt vagg fran theta = 0: symmetriskt intrade

    while s.theta < 2, s.step < 10_000 {
        s = Simulator.step(s, tuning: t, flip: false).state
    }

    let seconds = Double(s.step) * Simulator.dt
    let expected = t.flipDuration * 2.0.squareRoot()
    #expect(s.theta == 2)
    #expect(abs(seconds - expected) / expected < 0.02)
}

@Test func `symmetric entry falls in tap direction`() {
    var t = Tuning.reference
    t.mode = .tube
    var s = SimState.initial(tuning: t)
    s.theta = 2
    s.downWall = 0

    s = Simulator.step(s, tuning: t, flip: false).state
    #expect(s.theta > 2)
}

@Test func `orbital hold amplitude matches the analytic formula`() {
    var t = Tuning.reference
    t.mode = .tube
    let tapsPerSecond = 16.0 // val over tubens tröskel (~11,3/s), se spec §3.5
    let halfPeriod = 1 / tapsPerSecond
    let halfPeriodSteps = Int((halfPeriod / Simulator.dt).rounded())
    let expectedAmplitude = halfPeriod * halfPeriod / (2 * t.flipDuration * t.flipDuration)

    var s = SimState.initial(tuning: t)
    s.theta = 2
    s.downWall = 3
    s.vTheta = -t.alphaMagnitude * halfPeriod / 2

    var lo = Double.infinity
    var hi = -Double.infinity
    for i in 0 ..< (40 * halfPeriodSteps) {
        let flip = i > 0 && i % halfPeriodSteps == 0
        s = Simulator.step(s, tuning: t, flip: flip).state
        if i > 30 * halfPeriodSteps {
            lo = min(lo, s.theta)
            hi = max(hi, s.theta)
        }
    }

    let measured = hi - lo
    // Om detta inte konvergerar inom toleransen: kontrollera forst att fasen
    // (start-`downWall`/`theta`/tecknet pa den seedade `vTheta`) motsvarar ett
    // steady-state svangningslage — det ar amplituden som testas, inte fasen.
    #expect(abs(measured - expectedAmplitude) / expectedAmplitude < 0.05)
}

@Test func `orbital hold collapses below the directional threshold`() {
    var t = Tuning.reference
    t.mode = .tube
    let tapsPerSecond = 8.0 // under tubens tröskel (~11,3/s): cirkulerar istallet
    let halfPeriodSteps = Int((1 / tapsPerSecond / Simulator.dt).rounded())

    var s = SimState.initial(tuning: t)
    var totalTravel = 0.0
    var previousTheta = s.theta

    for i in 0 ..< (20 * halfPeriodSteps) {
        let flip = i > 0 && i % halfPeriodSteps == 0
        s = Simulator.step(s, tuning: t, flip: flip).state
        totalTravel += abs(Angle.wrappedDelta(s.theta, previousTheta))
        previousTheta = s.theta
    }

    // Havallning skulle ge en total forflyttning i storleksordningen amplituden
    // (< 4). Cirkulation varvar hela slingan flera ganger.
    #expect(totalTravel > 8)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --package-path Packages/OMTKit --filter TubeTests`
Expected: FAIL to build — `ControlMode.tube`, `Tuning.alphaMagnitude`, `SimState.theta`/`.vTheta`/`.downWall` do not exist.

- [ ] **Step 3: Write the implementation**

In `Simulation.swift`, add one case to the existing `ControlMode` declaration (`public enum ControlMode: Sendable, Hashable`), keeping its existing conformances:

```swift
    /// Figuren rör sig langs en sluten slingas omkrets istallet for att falla
    /// mellan golv och tak. Se spec §3.
    case tube
```

Extend `Tuning` with two computed properties (placed alongside the other computed properties, e.g. `usableHeight`):

```swift
    /// Vinkelaccelerationens magnitud, sa att en kvarts varv fran vila tar
    /// exakt `flipDuration`: `alpha = 2 / flipDuration^2`. Se spec §3.4.
    public var alphaMagnitude: Double { 2 / (flipDuration * flipDuration) }

    /// Halva figurens vinkelutstracking, i kvartsvarv. Motsvarar
    /// `characterHeight` i kanalen. Se spec §3.7.
    public var angularHalfWidth: Double { (characterHeight / 2) / channelHeight }
```

Extend `SimState`'s stored properties (add after the existing `mode` field):

```swift
    public var theta: Double
    public var vTheta: Double
    public var downWall: UInt8
```

Extend its `init` to accept the three new fields with defaults, so every existing positional/labeled call site keeps compiling unchanged:

```swift
    public init(
        step: UInt32, x: Double, y: Double, vy: Double,
        gravity: Sign, alive: Bool, mode: ControlMode = .gravityFlip,
        theta: Double = 0, vTheta: Double = 0, downWall: UInt8 = 0,
    ) {
        self.step = step
        self.x = x
        self.y = y
        self.vy = vy
        self.gravity = gravity
        self.alive = alive
        self.mode = mode
        self.theta = theta
        self.vTheta = vTheta
        self.downWall = downWall
    }
```

`SimState.initial` needs no change — it calls the same initializer without naming `theta`/`vTheta`/`downWall`, which now default to `0`/`0`/`0`.

Add the direction helper as a private static function on `Simulator`:

```swift
    /// Riktningen `theta` accelererar i for att na `downWall`. Se spec §3.1,
    /// §4.2. Vid symmetriskt intrade (motsatt vagg) ger `Angle.wrappedDelta`
    /// alltid -2, vilket redan faller igenom till `+1` nedan — fallet skrivs
    /// trots det ut explicit sa att det inte ar en oavsiktlig konsekvens av
    /// avrundningsregeln i `Angle.wrappedDelta`.
    private static func tubeAccelerationDirection(theta: Double, downWall: UInt8) -> Double {
        let d = Angle.wrappedDelta(theta, Double(downWall))
        if d == -2 {
            return 1
        }
        return d > 0 ? -1 : 1
    }
```

In the existing `if flip { switch s.mode { ... } }` block inside `Simulator.step` (currently `case .gravityFlip:` / `case .impulse:`), add a third case:

```swift
            case .tube:
                s.downWall = (s.downWall + 1) % 4
                events.append(.flipped(step: s.step, direction: .up))
```

(`.up` is a placeholder direction — `Sign` has two cases and `downWall` has four, so the mapping is lossy by construction. The event only drives audio/haptic feedback today, which does not yet branch on direction for tube taps; a richer tube-specific event is deferred to the renderer/feedback deliverable, step 4/6 of spec §12.)

Just below, capture `theta0` alongside the existing `x0`/`y0`:

```swift
        let x0 = s.x
        let y0 = s.y
        let theta0 = s.theta
```

Replace the following unconditional integration block:

```swift
        s.vy += s.gravity.acceleration * tuning.gravityMagnitude * dt
        s.y += s.vy * dt
        s.x += tuning.scrollSpeed * dt

        if s.y <= tuning.floorY {
            s.y = tuning.floorY
            s.vy = 0
        } else if s.y >= tuning.ceilingY {
            s.y = tuning.ceilingY
            s.vy = 0
        }
```

with a switch over `s.mode` that keeps that exact block under `.gravityFlip, .impulse` and adds the tube branch:

```swift
        switch s.mode {
        case .gravityFlip, .impulse:
            s.vy += s.gravity.acceleration * tuning.gravityMagnitude * dt
            s.y += s.vy * dt
            s.x += tuning.scrollSpeed * dt

            if s.y <= tuning.floorY {
                s.y = tuning.floorY
                s.vy = 0
            } else if s.y >= tuning.ceilingY {
                s.y = tuning.ceilingY
                s.vy = 0
            }
        case .tube:
            s.x += tuning.scrollSpeed * dt
            let direction = Simulator.tubeAccelerationDirection(theta: s.theta, downWall: s.downWall)
            s.vTheta += direction * tuning.alphaMagnitude * dt
            let advanced = Angle.wrap(s.theta + s.vTheta * dt)
            let deltaAfter = Angle.wrappedDelta(advanced, Double(s.downWall))
            // Klampar exakt pa vaggen om steget skulle passera den, precis
            // som golv/tak-klampen ovan. Se spec §3.4.
            if (direction > 0 && deltaAfter >= 0) || (direction < 0 && deltaAfter <= 0) {
                s.theta = Double(s.downWall)
                s.vTheta = 0
            } else {
                s.theta = advanced
            }
        }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --package-path Packages/OMTKit --filter TubeTests`
Expected: PASS. If `orbital hold amplitude matches the analytic formula` doesn't converge, adjust the seed's `downWall`/sign of `vTheta` — the physics (acceleration magnitude, clamp) is exercised and locked by the other four tests in this task, so a phase mismatch in the hold test is a test-seeding issue, not an implementation bug.

- [ ] **Step 5: Also run the full existing suite to confirm no regression**

Run: `swift test --package-path Packages/OMTKit`
Expected: PASS (existing channel/impulse/portal tests unaffected — the `.gravityFlip, .impulse` branch is byte-for-byte the prior unconditional code).

- [ ] **Step 6: Commit**

```bash
git add Packages/OMTKit/Sources/OMTCore/Simulation.swift Packages/OMTKit/Tests/OMTCoreTests/TubeTests.swift
git commit -m "feat: add tube-mode physics (acceleration, tap, wall clamp)"
```

---

### Task 3: Wall collision

**Files:**
- Modify: `Packages/OMTKit/Sources/OMTCore/Collision.swift`
- Modify: `Packages/OMTKit/Sources/OMTCore/Events.swift`
- Modify: `Packages/OMTKit/Sources/OMTCore/Simulation.swift`
- Test: `Packages/OMTKit/Tests/OMTCoreTests/TubeTests.swift`

**Interfaces:**
- Consumes: `Angle.wrappedDelta(_:_:)` from Task 1; `SimState.theta`/`.downWall`, `Tuning.angularHalfWidth` from Task 2.
- Produces: `WallObstacle` (`wall: UInt8`, `x: Double`, `width: Double`), `Sweep.hitsWall(wall:angularHalfWidth:obstacleMinX:obstacleMaxX:fromX:fromTheta:toX:toTheta:) -> Bool`, `DeathCause.wallObstacle`. `Simulator.step` gains a `wallObstacles: [WallObstacle] = []` parameter, defaulted so existing callers (App layer, existing tests) are unaffected.

- [ ] **Step 1: Write the failing tests**

```swift
@Test func `collision wraps across wall zero`() {
    var t = Tuning.reference
    t.mode = .tube
    var s = SimState.initial(tuning: t)
    s.theta = Angle.wrap(-0.02) // precis under vagg 0
    s.downWall = 0
    let wall0 = WallObstacle(wall: 0, x: s.x, width: 4)

    let result = Simulator.step(s, tuning: t, flip: false, wallObstacles: [wall0])
    #expect(!result.state.alive)
    #expect(result.events.contains(.died(step: result.state.step, cause: .wallObstacle)))
}

@Test func `corner overlaps both adjacent walls`() {
    var t = Tuning.reference
    t.mode = .tube
    var s = SimState.initial(tuning: t)
    s.theta = 1.0 // exakt pa vagg 1: bade vagg 0 och vagg 2 ligger 1 kvartsvarv bort
    s.downWall = 1
    let wall0 = WallObstacle(wall: 0, x: s.x, width: 4)
    let wall2 = WallObstacle(wall: 2, x: s.x, width: 4)

    let hit0 = Sweep.hitsWall(
        wall: 0, angularHalfWidth: t.angularHalfWidth,
        obstacleMinX: wall0.x - wall0.width / 2, obstacleMaxX: wall0.x + wall0.width / 2,
        fromX: s.x, fromTheta: s.theta, toX: s.x, toTheta: s.theta,
    )
    let hit2 = Sweep.hitsWall(
        wall: 2, angularHalfWidth: t.angularHalfWidth,
        obstacleMinX: wall2.x - wall2.width / 2, obstacleMaxX: wall2.x + wall2.width / 2,
        fromX: s.x, fromTheta: s.theta, toX: s.x, toTheta: s.theta,
    )
    // Pa avstand exakt 1 kvartsvarv, utanfor bada vaggarnas 0,5+0,1-zon.
    #expect(!hit0)
    #expect(!hit2)
}

@Test func `fast rotation cannot tunnel through a wall obstacle`() {
    var t = Tuning.reference
    t.mode = .tube
    var s = SimState.initial(tuning: t)
    s.theta = Angle.wrap(-0.03)
    s.downWall = 1 // accelererar bort fran vagg 0, mot vagg 1
    s.vTheta = 12.8 // nara maxfarten (~12,86 kvartsvarv/s), se spec §3.8
    let wall0 = WallObstacle(wall: 0, x: s.x, width: 4)

    let result = Simulator.step(s, tuning: t, flip: false, wallObstacles: [wall0])
    #expect(!result.state.alive)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --package-path Packages/OMTKit --filter TubeTests`
Expected: FAIL to build — `WallObstacle`, `Sweep.hitsWall`, `DeathCause.wallObstacle`, and the `wallObstacles:` parameter do not exist.

- [ ] **Step 3: Write the implementation**

In `Events.swift`, extend `DeathCause`:

```swift
public enum DeathCause: Sendable, Equatable {
    case floorObstacle
    case ceilingObstacle
    /// Ett hinder pa en av tubens fyra vaggar. Vaggarna ar symmetriska, sa
    /// till skillnad fran golv/tak bar orsaken ingen ytterligare diagnostik
    /// i att peka ut vilken av de fyra.
    case wallObstacle
}
```

In `Collision.swift`, add `WallObstacle` near the existing `Obstacle` struct, and `hitsWall` inside the existing `Sweep` enum:

```swift
/// Ett hinder fast vid en av tubens fyra vaggar. Motsvarar `Obstacle` for
/// kanalen, men indexerar vagg istallet for golv/tak — se spec §3.7. Har
/// ingen egen "hojd": traffzonen ar en fast vinkelbredd runt vaggen, harledd
/// ur `Tuning.angularHalfWidth`, inte ur hindret.
public struct WallObstacle: Sendable {
    public var wall: UInt8
    public var x: Double
    public var width: Double

    public init(wall: UInt8, x: Double, width: Double) {
        self.wall = wall
        self.x = x
        self.width = width
    }
}
```

```swift
extension Sweep {
    /// Motsvarar `hits`, men for tubens (x, theta) istallet for kanalens
    /// (x, y). `slab` ateranvands oforandrat for x, som inte ar periodisk;
    /// theta jamfors mot den wrappade differensen till vaggen istallet for
    /// ett fast intervall — se spec §3.7.
    static func hitsWall(
        wall: UInt8,
        angularHalfWidth: Double,
        obstacleMinX: Double,
        obstacleMaxX: Double,
        fromX x0: Double,
        fromTheta theta0: Double,
        toX x1: Double,
        toTheta theta1: Double,
    ) -> Bool {
        let threshold = 0.5 + angularHalfWidth
        let d0 = Angle.wrappedDelta(theta0, Double(wall))
        let d1 = Angle.wrappedDelta(theta1, Double(wall))

        var tMin = 0.0
        var tMax = 1.0
        guard slab(origin: x0, delta: x1 - x0, lo: obstacleMinX, hi: obstacleMaxX, &tMin, &tMax) else {
            return false
        }
        guard slab(origin: d0, delta: d1 - d0, lo: -threshold, hi: threshold, &tMin, &tMax) else {
            return false
        }
        return tMin <= tMax
    }
}
```

(`slab` is the existing private static function in `Collision.swift` used by `Sweep.hits`; it takes an origin/delta/lo/hi and narrows `tMin`/`tMax` in place. No change to `slab` itself.)

In `Simulation.swift`, add one new trailing parameter to `Simulator.step`'s existing signature (`holding`, `obstacles`, and `portals` already exist unchanged — only `wallObstacles` is new). The channel obstacle loop is unguarded by mode, relying on the caller to only pass obstacles that match the run's current mode; `wallObstacles` follows the same convention:

```swift
    public static func step(
        _ state: SimState,
        tuning: Tuning,
        flip: Bool,
        holding: Bool = false,
        obstacles: [Obstacle] = [],
        portals: [Portal] = [],
        wallObstacles: [WallObstacle] = [],
    ) -> StepResult {
```

Add a second collision loop directly after the existing `for obstacle in obstacles { ... }` loop (same structure: sweep test, then die-and-revert-and-return-early on a hit — matching the existing loop's `s.alive = false; s.x = x0; s.y = y0; events.append(.died(...)); return StepResult(state: s, events: events)` pattern exactly, just for `theta` instead of `y`):

```swift
        for obstacle in wallObstacles {
            let hit = Sweep.hitsWall(
                wall: obstacle.wall,
                angularHalfWidth: tuning.angularHalfWidth,
                obstacleMinX: obstacle.x - obstacle.width / 2,
                obstacleMaxX: obstacle.x + obstacle.width / 2,
                fromX: x0, fromTheta: theta0,
                toX: s.x, toTheta: s.theta,
            )
            if hit {
                s.alive = false
                s.x = x0
                s.theta = theta0
                events.append(.died(step: s.step, cause: .wallObstacle))
                return StepResult(state: s, events: events)
            }
        }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --package-path Packages/OMTKit --filter TubeTests`
Expected: PASS

- [ ] **Step 5: Run the full suite and the determinism gate**

Run:
```bash
swift test --package-path Packages/OMTKit
swift test --package-path Packages/OMTKit -c release -Xswiftc -enable-testing
```
Expected: PASS in both configurations.

- [ ] **Step 6: Commit**

```bash
git add Packages/OMTKit/Sources/OMTCore/Collision.swift Packages/OMTKit/Sources/OMTCore/Events.swift Packages/OMTKit/Sources/OMTCore/Simulation.swift Packages/OMTKit/Tests/OMTCoreTests/TubeTests.swift
git commit -m "feat: add tube wall-obstacle collision"
```

---

### Task 4: Channel ↔ tube portal transitions

**Files:**
- Modify: `Packages/OMTKit/Sources/OMTCore/Simulation.swift`
- Test: `Packages/OMTKit/Tests/OMTCoreTests/TubeTests.swift`

**Interfaces:**
- Consumes: `SimState.theta`/`.vTheta`/`.downWall` (Task 2), existing `Portal` struct (`x: Double`, `mode: ControlMode`) and the existing portal-crossing loop in `Simulator.step`.
- Produces: no new public API — extends the existing portal-crossing branch to handle `.tube` as a source or target mode.

- [ ] **Step 1: Write the failing tests**

```swift
@Test func `entering tube mode sets down wall to zero`() {
    let t = Tuning.reference
    // Portalen ligger precis vid starten: korsningen sker redan pa forsta
    // steget, sa inget hinner drifta innan mappningen lases av.
    let portal = Portal(x: 0.001, mode: .tube)
    var s = SimState.initial(tuning: t)
    s.y = t.floorY

    s = Simulator.step(s, tuning: t, flip: false, portals: [portal]).state

    #expect(s.mode == .tube)
    #expect(s.downWall == 0)
}

@Test func `portal transitions preserve relative position entering the tube`() {
    let t = Tuning.reference
    let portal = Portal(x: 0.001, mode: .tube)
    var s = SimState.initial(tuning: t)
    s.y = t.ceilingY
    s.vy = -40 // nedat, sa klampen vid taket inte nollar farten samma steg

    s = Simulator.step(s, tuning: t, flip: false, portals: [portal]).state

    #expect(s.mode == .tube)
    // Tak -> vagg 2. Ett enda steg kanalfysik hinner paverka y/vy nagot
    // innan mappningen lases av (tyngdkraften pa -40 ger en liten forskjutning
    // fran exakt taket) — se rakningen i den brief-lankade motiveringen.
    #expect(abs(s.theta - 2) < 0.01)
    #expect(s.vTheta < 0)
    #expect(s.downWall == 0)
}

@Test func `portal transitions preserve relative position leaving the tube`() {
    var t = Tuning.reference
    t.mode = .tube
    let portal = Portal(x: 0.001, mode: .gravityFlip)
    var s = SimState.initial(tuning: t)
    s.theta = 3
    s.downWall = 3 // redan pa vaggen: klampen i tubintegrationen haller
    // theta/vTheta exakt pa 3/0 aven efter ett integrationssteg.

    s = Simulator.step(s, tuning: t, flip: false, portals: [portal]).state

    #expect(s.mode == .gravityFlip)
    // Vagg 3 -> mitten, med nollfart eftersom figuren vilade pa vaggen.
    #expect(abs(s.y - (t.floorY + t.usableHeight / 2)) < 1e-9)
    #expect(s.vy == 0)
    #expect(s.gravity == .down)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --package-path Packages/OMTKit --filter TubeTests`
Expected: FAIL — `entering tube mode sets down wall to zero` and the two mapping tests fail because the portal loop doesn't yet touch `theta`/`vTheta`/`downWall`/`y`/`vy` for tube transitions (mode switches, but the mapped fields stay at their pre-crossing values).

- [ ] **Step 3: Write the implementation**

In `Simulation.swift`, find the existing portal-crossing loop (the one that currently does `if portal.mode == .impulse { s.gravity = .down }` before setting `s.mode = portal.mode`). Replace it with:

```swift
        for portal in portals where x0 <= portal.x && s.x > portal.x {
            guard s.mode != portal.mode else { continue }

            if portal.mode == .tube {
                // Kanal -> tub: y avbildas linjart pa theta ∈ [0, 2]. Se spec §4.
                s.theta = Angle.wrap(2 * (s.y - tuning.floorY) / tuning.usableHeight)
                s.vTheta = s.vy * 2 / tuning.usableHeight
                s.downWall = 0
            } else if s.mode == .tube {
                // Tub -> kanal: theta avbildas linjart tillbaka. vagg 0 -> golv,
                // vagg 2 -> tak, vagg 1 och 3 -> mitten. Se spec §4.
                let folded = s.theta <= 2 ? s.theta : 4 - s.theta
                let sign: Double = s.theta <= 2 ? 1 : -1
                s.y = tuning.floorY + (folded / 2) * tuning.usableHeight
                s.vy = s.vTheta * (tuning.usableHeight / 2) * sign
                s.gravity = .down
            }

            if portal.mode == .impulse {
                s.gravity = .down
            }

            s.mode = portal.mode
            events.append(.modeChanged(step: s.step, mode: portal.mode))
        }
```

(The `guard s.mode != portal.mode else { continue }` and the `if portal.mode == .impulse { s.gravity = .down }` lines are the pre-existing behavior, unchanged — only the two new `if`/`else if` branches for `.tube` are added, and `s.mode = portal.mode` / the `.modeChanged` event append are the same statements moved after the new branches.)

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --package-path Packages/OMTKit --filter TubeTests`
Expected: PASS

- [ ] **Step 5: Run the full suite and the determinism gate**

Run:
```bash
swift test --package-path Packages/OMTKit
swift test --package-path Packages/OMTKit -c release -Xswiftc -enable-testing
```
Expected: PASS in both configurations. This is the last task in the plan, so this is also the final regression check before opening the PR.

- [ ] **Step 6: Commit**

```bash
git add Packages/OMTKit/Sources/OMTCore/Simulation.swift Packages/OMTKit/Tests/OMTCoreTests/TubeTests.swift
git commit -m "feat: add channel-tube portal transitions"
```

---

## Self-Review

**Spec coverage** — all 11 named tests from spec §11.1 are present:
`aQuarterTurnFromRestTakesFlipDuration` (Task 2), `oppositeWallTraverseTakesSqrtTwoFlipDurations` (Task 2), `orbitalHoldAmplitudeMatchesTheAnalyticFormula` (Task 2), `orbitalHoldCollapsesBelowTheDirectionalThreshold` (Task 2), `thetaWrapIsExactInBothDirections` (Task 1), `collisionWrapsAcrossWallZero` (Task 3), `cornerOverlapsBothAdjacentWalls` (Task 3), `fastRotationCannotTunnelThroughAWallObstacle` (Task 3), `enteringTubeModeSetsDownWallToZero` (Task 4), `symmetricEntryFallsInTapDirection` (Task 2), `portalTransitionsPreserveRelativePosition` (Task 4, split into an entering- and a leaving-tube test since the spec's single name covers both directions of §4's transition table).

§3.1–§3.8 (model, acceleration, tap, hold, clamp, collision, tunneling margin) are covered by Tasks 1–3. §4.1–§4.3 (transition mapping, tie-break, forced-gravity-down) are covered by Task 4. §5 (camera/rendering) and §8 (content/validator authoring) are explicitly out of scope, per the plan's arguments — not covered, by design.

**Placeholder scan** — no TBD/TODO. The one deliberately approximate piece (`.flipped(direction: .up)` for tube taps in Task 2) is a real, documented decision, not a stub: it is fully functional today (drives existing audio/haptics unchanged) and the comment states exactly why a richer signal is deferred and to which later deliverable.

**Type consistency** — `WallObstacle`'s field names (`wall`, `x`, `width`), defined in Task 3, are used consistently in Task 3's own tests and are untouched by Task 4 (Task 4 only touches `Portal`/`SimState`). `Simulator.step`'s parameter list accumulates additively: `holding`/`obstacles`/`portals` already exist before this plan; `wallObstacles: [WallObstacle] = []` is the only new parameter (added in Task 3). Task 4's tests call `step(_:tuning:flip:portals:)` without `wallObstacles:`, which compiles because of that default. `Tuning.alphaMagnitude`/`.angularHalfWidth` (Task 2) are used with matching names in Task 3's `Sweep.hitsWall` calls and Task 2's `tubeAccelerationDirection`.
