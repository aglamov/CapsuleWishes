# CapsuleWishes

CapsuleWishes is a reflective iOS app for working with wishes without turning them into pressure, superstition, or a productivity dashboard.

The app helps a person name a wish, give it emotional form, place it into a time capsule, notice what happens around it, and return later with a calmer, more honest view of what changed.

## Product Idea

CapsuleWishes sits between:

- a private journal;
- a gentle goal companion;
- a symbolic ritual;
- an emotional self-reflection tool.

It is not a manifestation engine, horoscope app, therapy replacement, or task tracker. The desired feeling is closer to a private night-sky room where the user can place something important and return to it over time.

## Core Loop

1. Create a capsule.
2. Write the wish and the feeling behind it.
3. Choose when the capsule should open.
4. Seal it with a short visual ritual.
5. Add observations while the capsule is waiting:
   - strange signs;
   - thoughts;
   - dreams;
   - tiny steps.
6. Open the capsule on the selected day.
7. Choose an honest outcome:
   - fulfilled;
   - still unfolding;
   - changed;
   - released.

The result is intentionally not binary. A wish can come true, continue unfolding, change shape, or become something the user is ready to release.

## Current App

The current version includes:

- narrative first-run introduction;
- capsule creation flow;
- wish, desired feeling, opening date, color, and symbol;
- animated sealing ceremony;
- capsule list with active and opened capsules;
- capsule detail screen;
- linked journal entries;
- standalone journal tab;
- local notification signals;
- opening ceremony with non-binary outcomes;
- optional AI assistance for prompts, wording, sealing reflections, future letters, and opening reflections;
- sound and motion details with reduced-motion support.

## Interaction Model

The app should feel calm, atmospheric, and private. Motion, glow, particles, and sound are used to make the capsule feel alive, but the product meaning should stay grounded:

- the app does not promise that wishes will come true;
- the app encourages attention, reflection, and small movement;
- the app avoids guilt, streak pressure, fake urgency, and guaranteed outcome language;
- magical language is treated as metaphor and atmosphere, not as a claim.

## Main Screens

### Capsules

The capsule screen shows active wishes as personal objects with status, opening date, progress, and visual state. Opened capsules are preserved separately so the user can revisit past intentions.

### Create Capsule

The creation flow helps the user formulate a wish without requiring a perfect sentence. The minimum useful capsule contains:

- wish text;
- desired feeling;
- opening date;
- color;
- symbol.

AI can optionally help polish the wording or suggest prompts, but the user remains the author of the wish.

### Capsule Detail

The detail screen is where the wish lives while sealed. The user can add short observations and tiny steps connected to the capsule.

Journal entry types:

- Strange thing;
- Thought;
- Dream;
- Step.

When the capsule becomes ready, the user opens it and chooses the outcome that feels most honest.

### Journal

The journal trains attention without demanding daily perfection. Entries can be linked to a capsule or saved without a capsule.

## Product Boundaries

CapsuleWishes may support reflection, gratitude, emotional awareness, and gentle goal movement. It should not make clinical claims or position itself as treatment for anxiety, depression, trauma, or any mental health condition.

Important rules:

- no diagnosis;
- no crisis-handling claims unless a proper safety flow exists;
- no shame-based retention;
- no competitive streaks;
- no public wishes or social feed in early versions;
- no guaranteed manifestation language.

## Roadmap

Near-term product direction:

- make the small-step mechanic more explicit;
- improve archive and opened-capsule review;
- add deeper reflection around recurring themes;
- add ritual support only when it helps attention and action;
- keep AI optional, privacy-aware, and non-authoritative.

See also:

- [Product concept](docs/PRODUCT.md)
- [UX and interaction model](docs/UX.md)
- [Roadmap](docs/ROADMAP.md)
- [AI backend](docs/AI_BACKEND.md)
