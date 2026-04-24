# UX and Interaction Model

Capsule Wishes should feel like a private emotional space, not a productivity dashboard. The interface should be calm, atmospheric, and focused on the user's inner movement.

## Information Architecture

Primary destinations:

- **Capsules**: active wishes and their states.
- **Journal**: signs, small joys, dreams, thoughts, and reflections.
- **Rituals**: personal practices connected to wishes.
- **Archive**: opened, fulfilled, changed, and released capsules.
- **Path**: recurring themes and personal patterns.

## Navigation Model

MVP can start with a simple tab structure:

- Capsules;
- Journal;
- Rituals;
- Archive.

The `Path` screen can be introduced later once enough user history exists to make insights meaningful.

## Screen: Onboarding

Goal: create emotional context.

Content:

- short narrative about childhood wishes;
- explanation that each person may have a personal ritual;
- invitation to create the first capsule;
- honest note that the app supports reflection and action, not guaranteed outcomes.

Motion:

- slow background movement;
- subtle light particles;
- text appearing in short, readable moments.

## Screen: Capsule Constellation

Goal: make all wishes feel alive.

Elements:

- active capsules as glowing objects;
- opening countdown;
- quick create button;
- daily prompt entry;
- visual state by glow, scale, and motion.

Capsule states:

- sleeping: dim and quiet;
- active: soft pulse;
- recently updated: brighter edge;
- ready to open: visible internal light;
- opened: warmer, calmer glow.

## Screen: Create Capsule

Goal: help the user formulate a wish.

Steps:

1. Name the wish.
2. Describe what fulfillment would look like.
3. Describe the feeling behind the wish.
4. Choose an opening date.
5. Choose color or symbol.
6. Seal the capsule.

The flow should support skipping optional questions. A blocked user should still be able to create a simple capsule.

## Screen: Capsule Detail

Goal: make one wish easy to revisit.

Core actions:

- add sign;
- add small joy;
- add thought;
- complete ritual;
- add tiny step;
- open capsule when ready.

Layout:

- capsule visualization at the top;
- status and opening date;
- current ritual;
- recent journal entries;
- small steps;
- reflection prompt.

## Screen: Journal

Goal: help the user notice life.

Fast entry buttons:

- Strange thing;
- Small joy;
- Thought;
- Dream;
- Gratitude;
- Tiny step.

Prompts:

- What felt slightly unusual today?
- What made the day one percent lighter?
- What stayed with you?
- What did you do even though it was hard?
- What might this be connected to?

The journal must allow imperfect, short, unfinished entries.

## Screen: Rituals

Goal: help the user discover what kind of practice creates resonance.

Ritual card attributes:

- title;
- type;
- duration;
- emotional tone;
- difficulty;
- "try now" action;
- "this resonated" feedback.

Ritual completion should end with a tiny reflection, not a performance score.

## Screen: Opening Ceremony

Goal: create a meaningful closing moment.

Sequence:

1. Capsule becomes ready.
2. User chooses to open.
3. Original wish appears.
4. Related entries and steps are shown.
5. User reflects on the outcome.
6. Capsule receives a final status.

Outcome options:

- fulfilled;
- still unfolding;
- changed;
- released;
- begin another cycle.

## Motion Principles

- Use slow, soft motion.
- Respect reduced motion settings.
- Avoid visual noise during writing.
- Use glow to communicate state, not urgency.
- Make sealing and opening memorable but brief.

## Accessibility

- All screens must work without animation.
- Color should never be the only state indicator.
- Journal entry must be usable with VoiceOver.
- Text should remain readable over atmospheric backgrounds.
- Emotional copy should avoid shame, urgency, or pressure.
