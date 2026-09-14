# One More Try

A one-tap skill game for iOS.

You run automatically. Tapping flips gravity — you fall to the ceiling, or back to the
floor. Obstacles grow out of both surfaces. You die on contact and restart instantly.
Mid-run portals can switch you into a different control mode entirely.

The design target is a single sentence: *"I'll just try one more time."*

## The thing that makes it different

Gravity-flip runners are not new, and neither is switching control mechanics mid-run — that
architecture is Geometry Dash's signature. What we're not competing on is mechanical
novelty; the genre is saturated, and the plan (Downwell is the precedent) is to compete on
feel and presentation instead.

What's actually unusual, and doesn't show up in the first 30 seconds:

- **A shuffled tail.** Every attempt opens with an identical hand-authored stretch — the
  part you see 200 times, and therefore the part you actually learn — after which a
  shuffler takes over. A Geometry Dash level is finite and fully hand-built; this isn't.
- **A machine-verified fairness floor.** Every generated pattern is validated by beam
  search through the real simulation, not a separate solver, so `robustnessMs` is measured
  rather than assumed.
- **Clearing means surviving**, not reaching an end. Six difficulty tiers, each endless,
  each cleared by surviving 60 seconds.

We first tried making *hovering* — holding a line mid-channel via rapid alternating taps —
the identity. On-device play falsified that: at the reference tuning it demands a sustained
6.4 taps/second, which is an endurance drill, not a skill. It's kept as a correction tool
(one or two taps to nudge a line), and a second control mode, **impulse**, sets vertical
speed directly (Mario-style: a short tap gives a small hop, a held one a full jump), which
makes hovering cheaper without ever requiring it.

## Structure

Six difficulty tiers. Each is endless, and each is cleared by surviving 60 seconds. Every
attempt opens with an identical hand-authored 20 seconds, after which a shuffler takes
over. A third control mode — traversing a closed tube instead of a channel — is designed
but not yet built.

## Status

Playable prototype, not yet the shipping build. `OMTCore` has the simulation
(kinematics, swept-AABB collision, gravity-flip and impulse modes, variable jump height,
portals) with a green determinism-gated test suite. The app wraps it in a throwaway
SwiftUI/Canvas renderer with synthesised audio and haptics — enough to answer "does this
feel good?" on a phone; the real renderer is a custom `CAMetalLayer` pipeline, not yet
built. Every push and pull request runs format, lint, the determinism suite in both debug
and release, and a full device build.

Not run yet: the fun grind (three people who don't build this game, 30 voluntary attempts,
one returns the next day unprompted). Nothing that would be thrown away if the mechanic
turns out unfun gets built before it passes.

The full design lives in
[`docs/superpowers/specs/2026-09-13-one-more-try-design.md`](docs/superpowers/specs/2026-09-13-one-more-try-design.md),
with the three-mode/perspective follow-up in
[`docs/superpowers/specs/2026-09-13-three-modes-and-perspective-design.md`](docs/superpowers/specs/2026-09-13-three-modes-and-perspective-design.md).

## Built with

Swift 6.3, heading toward a custom Metal renderer with no game engine. The simulation core
imports nothing at all — not UIKit, not Metal, not Foundation — so it runs headless on
macOS and Linux at thousands of runs per second. That property is what the rest of the
architecture is built on.

Character art will be pre-rendered from CC0 rigged 3D models via Blender, in the tradition
of Donkey Kong Country and Dead Cells. No assets are committed yet.

## Licence

Not yet chosen. Until one is added, all rights are reserved.
