# Story mode restructure: the present, with flashbacks

Oct 17, 2026 · from a playthrough of the whole story by the author.

## Intent

"The Ghost Line" is a mystery: after the crash Pang hunts the driver called Ghost, learns Ghost
is himself, then learns the perfect run never happened. As built, the story plays in date order,
so the player watches Jolo stitch the composite in Act I and then sits through two acts of
characters "discovering" it. The playthrough feedback: the Dante confrontation is a duplicate,
the scenes feel like disconnected storyboard panels, "everything is confusing".

The fix is structural: the story is told from after the crash, and the months before come back
as flashbacks that the present triggers. The one memory the game withholds is the edit. The
reveal then uses the player's own recorded passes, which is what the mode was built on
(`docs/story/STORY_MODE.md`, "the evidence is the player's own driving").

Plot, manuscript and storyboard in `docs/story/` stay canon for *what happens*; this document
replaces the play order in `STORY_MODE.md` § Structure and the Acts table.

## Goals

- The player does not know Ghost is Pang, or that the clip is a composite, until Act III.
- Every flashback is unmistakably a flashback, going in and coming out.
- Every scene change has a reason the player can feel (a trigger, a cut, a sound), not a jump.
- Dante is confronted twice with different stakes: suspicion first, proof second.
- The speedometer shows in story races.

## Non-goals

- New scenes, new rooms, new characters, new races. This reorders and rewrites; the beats,
  stages, rooms, recorded passes, the Ghost Line composite and the evidence boards stay.
- Watercolour or full-colour flashbacks. The cheap look (below) first; the full art pipeline
  change is a separate project if the idea holds.
- Comic pages for every transition in Acts II–V. Only the flashback entries and exits get
  pages in this project; the rest keep the fade through black.

## Anti-goals

- A memory that contradicts what the player saw. Nothing in a flashback may show Pang learning
  the clip is a composite before Act III.
- Tutorial text ("FLASHBACK") in place of a feeling. The stamp is period and place, in the
  story's own voice.
- A reveal the player cannot trust: the Act III split must show the player's own three passes,
  not canned footage.

## The order

Beat ids are the current `StoryScript.BEATS` ids; storyboard scenes S00–S35 all stay (the unit
test enforces it). `→ MEMORY` marks a flashback entry, `→ NOW` the return.

```
PROLOGUE   THE MISSING SECONDS
  p_card, s00 (cold open crash; comic pages as now)

ACT I      THE RETURN                       (present: rain, the scar, the empty seat)
  a1_card
  s14   clinic → rented room
  s15   the talyer: what is left of the car; Ruel           trigger: the wrench
    → MEMORY 1  "MONTHS BEFORE"
      s01   the talyer, Jolo alive, the tires
      s02   drive to the meet
      s03   NOTHING TO LOSE (loop race)
      s04t  Kyo: Dante's table, Nico
      s05   NICO'S LESSON (Pass 1 race)
    → NOW
  s16   THE FIRST RETURN (loop race, trauma)
  s17   drive to Kyo
  s17e  ask around: the rumours of Ghost                      trigger: the clip on Buko's phone
    → MEMORY 2  "THE LINE STUDY"
      s06   A LINE STUDY: the three passes, Jolo filming
            after: "Which one?" / "The one we'll pretend you meant to do."
    → NOW   (the laptop scene s06e is withheld: see "What is hidden")
  s20   DANTE, FIRST: suspicion (rewritten)

ACT II     THE GHOST                        (present)
  a2_card
  s18   NICO REPEATS THE TEST (flying sectors vs the ghost)
  s19   the memory montage (paper)                            trigger: Jolo's camera bag
    → MEMORY 3  "GHOST GOES PUBLIC"
      s07   the group chat: Dante posts the clip; "anonymous driver"
      s08   CHASE THE COMPOSITE (attack; Pang believes it is another driver)
      s09   THE COMBINED-SECTOR CHALLENGE (attack; Nico: "not behaving like one run")
      s10   the parked car: Jolo, "there is something about the clip I should've—"
    → NOW
  s21   the computer bench: Jolo's backup folder
  s22   TWO CLIPS, SYNCED: the Ghost clip is Pang's car, Pang's hands   = GHOST IS YOU

ACT III    THE GHOST IS YOU                 (present)
  a3_card
  s23   the talyer after closing
  s24   the parked car
  s25   THE PROJECT TIMELINE: the composite splits into the three passes = IT NEVER HAPPENED
  s26   THE SECTOR TRIALS, then all of it in one run

ACT IV     WHAT HAPPENED ON THE MOUNTAIN
  a4_card                                                     trigger: the bent sign at 8A
    → MEMORY 4  "THE NIGHT RUN"
      s11   the estimate, the event, Jolo's notes
      s12   the talyer at dusk, rain
      s13   THE LAST NIGHT RUN (the crash, driven)
    → NOW
  s27   the overlook above 8A, daylight
  s28   the logger
  s29   the workbench
  s30   DANTE, SECOND: proof (as written, trimmed of the lines s20 now owns)
  s31   the group chat, a week later

ACT V      THE ROAD IS NOT A RECORDING
  a5_card, s32, s33, s33t, s34, s35, end
```

Data dependencies that fix this order: the Ghost Line composite is cut from the passes
recorded in s06, so s06 precedes s18, s08, s09, s26; the crash log read in s28 is recorded in
s13, so Memory 4 precedes s27–s29. Both hold above.

Act cards: six chapters (prologue + five), titles as above; `StoryScript.acts()` still drives
the title screen's act list.

## What is hidden, and what the memories believe

- **s06e (Jolo's laptop) is cut from play.** Its card ("GHOST_LINE_COMPOSITE") moves into
  s25's board. Pang was asleep in the garage that night (the manuscript's chapter one opens on
  him waking there): the memory never had it.
- **In Memory 3 Pang believes Ghost is another driver.** Rewrite s08's "after"/"beaten" lines:
  Jolo no longer says "it's a time built out of the best parts of different runs"; he starts to
  ("Pang, about the clip—") and is cut off by Pang's "I'm close." s09's Nico lines stay: "the
  target isn't behaving like one run" is a fair clue. s10 stays as written.
- **s07 keeps "Reference pace from an anonymous driver"** and Jolo's unease at Kyo; Jolo's
  "it's not one run" to Dante is cut (Pang is not in that exchange in the new order; keep
  Dante's "nobody cares about a clip labelled study" as a line Pang overhears without context).
- **The attack runs show the ghost car driving Pang's own line.** That is allowed: it is only
  legible in retrospect.

## Dante, twice

- **s20 (Act I, suspicion).** Rewrite from the plot (`GHOST_LINE_PLOT.md` § the first
  confrontation): Pang asks whether Dante had a driver arranged that night, whether the event
  was manipulated, and who Ghost is. Dante: he never arranged for anyone to interfere, people
  came to watch a run, not an accident; and he does not know who Ghost is, the clip came to him
  through Jolo (my call: Dante's "I never asked" is true, and lands again in s30 when Pang knows
  Dante had seen the source material). Ruel's "I backed up his camera folder" line moves here
  from the current s20 ending, so it sets up s21.
- **s30 (Act IV, proof).** Keep as written (the composite, "a legend sells the next event", "I
  didn't cause the crash", "release the files"). Remove the opening "You knew the clip was
  edited" exchange that s20 currently duplicates; s30 opens on the files on the table.

## Flashbacks: in, during, out

**In.** A comic page (`StoryComic`) of 2–3 panels: the trigger object in the present (black
panel or frozen scene), a caption in the story's voice, then the period stamp as the last
panel's caption. The page ends on black; the memory's scene fades up from it.

**During.** The cheap look:
- the paper tint warms (`MangaType.PAPER` → a warm cream, e.g. `#F5E6C8`) across the
  compositor and the UI panels; the present keeps the current paper;
- cars and accents keep their colour (they already do); the world stays ink and tone;
- no rain, dry road, low sun (`night_value` ≤ 0.3) unless the memory says otherwise (s12/s13
  are rain by the plot);
- Jolo's portrait appears; Pang's portrait has no scar;
- a red stamp sits top-left for the whole memory: period on the first line (MONTHS BEFORE,
  THE WEEK OF THE NIGHT RUN), place on the second, replacing the current one-line caption.
  It never goes away inside a memory, including during races (it sits above the HUD).

**Out.** A hard cut to black on a present-day sound (rain, the phone, the wrench) held ~0.5 s;
the present fades up with the stamp reading NOW and the place. No comic page on the way out
(the cut is the point).

Beats carry this as data: `"memory": "MONTHS BEFORE"` on the first beat of a memory and
`"now": true` on the first beat after it; StoryDirector owns the tint, stamp and transitions so
no scene file knows about flashbacks.

## Present-day signals

- The scar on Pang's portrait is "not inside a memory", not "beat ≥ Act II".
- Present-day talk and evidence scenes with no conditions of their own default to rain or wet
  road and overcast (the Act I–IV present). Drive beats keep their own conditions.
- The empty passenger seat: cabin scenes in the present have no Jolo line; in Memory 3's s10 he
  is there.

## Fixes riding along

- **Speedometer in story races.** `StoryDirector._hold(true)` hides the HUD through
  `DriveSession.set_clean_feed`, which remembers each HUD node's visibility and restores it.
  When a story scene loads, the gauges are still hidden (the race intro / menu own them), so the
  "restore" after dialogue restores them hidden. Fix: when the director releases the car for a
  drive beat, show `session.gauges` (and `day_night`) explicitly, the way the title menu's
  `_set_play_hud(true)` does; the clean feed stays off during drives.
- **Saves.** The beat index is the save's position; the new order invalidates old positions.
  Add a `script_version` to the save; a mismatch restarts the story from the prologue (records
  of passes are kept only if the script version matches, since the passes' meaning moved).

## Constraints

- English dialogue only (`[[story-dialogue-english-comics]]`).
- Keep `tests/test_story.gd` green: every S00–S35 scene present, six chapters, well-formed
  lines and comic pages. Add tests for: every `memory` beat has a matching `now` beat later;
  s06 precedes every beat that needs the ghost; s13 precedes s27–s29; s06e is absent.
- `tests/probe_story.gd` must still reach the end card headless; `tools/story_shot.gd` is how
  the flashback look is checked (shoot a memory beat and the beat after its `now`).
- Commit with explicit pathspecs (`[[commit-only-own-paths]]`).

## Calls made after the builder check (the author was asleep; revisit if wrong)

1. **The player must not know either.** Not dramatic irony. So Memory 2 and s20 are dulled:
   s06's pass labels drop the "SIGN AT 8A INTACT / BENT" notes (the sign still bends between
   passes on the road; nobody says so); s05's "I'll make a clip that shows what you can do" is
   cut; s06's entry caption becomes "It began with a joke."; Dante in s20 does not name Jolo
   ("It came to me the way everything does. Somebody sends it, I post it."). The s25 board
   states the sign evidence itself (a card: "SIGN AT 8A: intact in /raw_tuesday, bent in
   /raw_thursday"), so its question no longer depends on the player having read pass labels.
   s17e's "by the bent sign at 8A" card stays: it dates the clip, it does not name the driver.
2. **The rain default covers only beats with no conditions of their own.** s16, s18, s26, s27
   keep their dry data: the trials and the connected run must be under the ghost's own
   conditions or the evidence argues the wrong thing. Drop "Act V's daylight drive is the first
   dry present-day road".
3. **Jolo's face is a memory-only signal.** Outside a memory `StoryPortrait` shows no face for
   JOLO; present-day JOLO lines are footage and the name slab shows the speaker as written
   ("JOLO (ON THE CLIP)", "JOLO (THE CAMERA'S LAST AUDIO)"). s19 is present-day paper, no tint,
   no stamp: Pang's own montage, the trigger for Memory 3 (it already ends on the phone buzz).
   Also: `StoryMode` (or the director) exposes "inside a memory" so the portrait, the scar and
   the tint all read one flag.

## Left to the builder

- Exact comic page content for the four memory entries (from the manuscript where it has the
  words; the chapter openings "The Sound of a Wrench", "Ghost Goes Public", "The Last Night
  Run" are the sources).
- The s20 rewrite's lines, within the plot's limits above.
- Where the stamp sits relative to the minimap during races (top-left is the minimap's corner;
  below it or over it is the builder's call, as long as it is never hidden).
- Whether the warm tint is one compositor uniform or a paper-colour swap in `MangaType`; it
  must reach both the 3D compositor and the dialogue/comic UI.
