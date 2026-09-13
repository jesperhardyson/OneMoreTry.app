# One More Try

A one-tap skill game for iOS.

You run automatically. Tapping flips gravity — you fall to the ceiling, or back to the
floor. Obstacles grow out of both surfaces. You die on contact and restart instantly.

The design target is a single sentence: *"I'll just try one more time."*

## The thing that makes it different

Gravity-flip runners are not new. The mechanic that is: **flipping is allowed mid-air.**
Rapid alternating taps let you hold a line in the middle of the channel instead of
bouncing between the surfaces.

That technique — hovering — is the game's identity rather than a hidden trick. Tiers are
ordered by how many consecutive mid-air flips a pattern demands, from zero (pure surface
switching) to sustained. It is taught by geometry in tier 2, never by a tutorial.

## Structure

Six difficulty tiers. Each is endless, and each is cleared by surviving 60 seconds. Every
attempt opens with an identical hand-authored 20 seconds — the part you see 200 times, and
therefore the part you actually learn — after which a shuffler takes over.

## Status

Design phase. No game code yet.

The full design lives in
[`docs/superpowers/specs/2026-09-13-one-more-try-design.md`](docs/superpowers/specs/2026-09-13-one-more-try-design.md).
It has been through three independent reviews (game design, Swift/Metal architecture,
adversarial risk) and section 16 records what those reviews changed.

## Built with

Swift 6.3, a custom Metal renderer, and no game engine. The simulation core imports
nothing at all — not UIKit, not Metal, not Foundation — so it runs headless on macOS and
Linux at thousands of runs per second. That property is what the rest of the architecture
is built on.

Character art is pre-rendered from CC0 rigged 3D models via Blender, in the tradition of
Donkey Kong Country and Dead Cells.

## Licence

Not yet chosen. Until one is added, all rights are reserved.
