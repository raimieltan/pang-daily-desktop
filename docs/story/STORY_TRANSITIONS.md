# The Ghost Line: scene transitions

Every boundary in play order: what it did before (Oct 17), the storyboard's EXIT / TRANSITION
line for the outgoing scene, and what it does now. The data is the beat's `enter` / `exit`
(`StoryScript.BEATS`); `StoryDirector._exit` and `_reveal` play it, `StoryBridge` carries sound
across scene loads. A boundary with nothing authored fades through black (another stage) or
carries straight on (same place).

Techniques: **fade** (through black) · **cut** (hard, no fade) · **J-cut** (the next scene's
sound starts under this one: `enter.sound` + `lead`) · **L-cut** (this scene's sound runs on
into the next: `exit.sound` + `carry`, or an `enter` loop released at the beat's end) ·
**tail / head** (a held shot, 1–3 s, skippable after 1 s) · **object** (a comic page whose
object carries over) · **coast** (a drive ends by rolling to a stop) · **ease** (a drive-to
eases the camera into the scene's shot).

Rules: tails and heads are skippable after 1 s and never longer than 3 s (the crash keeps its
own 4.4 s of black and the pulse). The warm tint and the period stamp arrive with the picture,
never over the outgoing shot. A return to the present is a hard cut whose sound lands on the
cut frame.

| # | Boundary | Before | Storyboard EXIT (outgoing scene) | Now | Flag |
|---|---|---|---|---|---|
| 1 | p_card → s00 | card, then black held for the cold open | — | unchanged: the cold open comes out of black | |
| 2 | s00 → a1_card | crash: white, impact, black, silence | S00: a wrench across the cut into the past | silence held (the crash's own); the act card | S00's wrench now belongs to #5: the clinic moved ahead of the first memory |
| 3 | a1_card → s14 | fade | — | J-cut: rain under the card's last second, low through the clinic (the window "did weather") | |
| 4 | s14 → s15 | fade, comic page | S14: Ruel's message about the car and the card | Ruel's text ends S14; the clinic rain carries (L-cut) into the talyer's own rain | |
| 5 | s15 → s01 | fade into the memory page | S00: wrench strikes concrete, continues into the past | **cut**: the KLANK! page lands on the cut; tint and MONTHS BEFORE arrive as the memory comes up | matches S00's exit, one scene later |
| 6 | s01 → s02 | shutter page, fade | S01: shutter becomes the start beep | shutter page (object); drive-to | no start-beep sound in the kit: the shutter stays on the page |
| 7 | s02 → s03 | race page | S02: Jolo announces the entry is paid | page carries Jolo's line, as written | |
| 8 | s03 → s04t | race ends, cut to the talk | S03: Dante's invitation | **coast** after the finish; J-cut crickets (PAST MIDNIGHT) | |
| 9 | s04t → s05 | VRRMM page, fade | S04: Nico arrives | crickets released into the page; J-cut engine out of the page's black, gone when the pass comes up | |
| 10 | s05 → s16 | race, fade, black, wrench, 0.5 s, fade up | S05: Jolo promises a clip | **coast**; "Don't tell Ruel about the tires." then a hard cut; the wrench and the present land together (NOW) | S05's exit line (the clip promise) was cut with the old lines |
| 11 | s16 → s17 | race result, drive | S16: someone mentions another car | **coast**; RJ's line sends you; drive-to | |
| 12 | s17 → s17e | arrive, jump to the shot | — | **ease**: the car rolls to a stop as the camera drifts to Kyo's shot; a 0.3 s dip covers the car moving to its mark | |
| 13 | s17e → s06 | phone page, fade | S17: Nico tried the Ghost Line and failed | object: Buko's phone, rain on the lens; the rain (J-cut) runs under the page and stops dead as the dry memory comes up | |
| 14 | s06 → s20 | page, fade, buzz, fade up | S18 (in the old order): a gear change into a memory | **cut** on "Light's gone, boss."; the buzz and Dante's table land together (NOW) | |
| 15 | s20 → a2_card | fade | S20: Dante refuses the files; Ruel remembers the drive | Ruel's line ends the act; fade | |
| 16 | a2_card → s18 | road page | — | unchanged | |
| 17 | s18 → s19 | fade to the panel | S18: gear change bridges into a memory | **cut** on Nico's "You think you do."; the wrench opens the fragments | the memory bridge is a wrench, not a gear change |
| 18 | s19 → s07 | ~cut, buzz, memory page | S19: a laugh lands on Dante laughing | buzz into the camera-bag page (object) | no laugh sound; S19's laugh is a buzz |
| 19 | s07 → s08 | fade | S07 (old S06): the edit cuts to a continuous engine note | J-cut engine under the chat's last line, gone when the pass comes up | matches S06's exit, moved to where the drive is |
| 20 | s08 → s09 | run ends, page | S08: Dante announces the public event | **coast**; the crowd page | |
| 21 | s09 → s10 | run ends, fade | S09: Jolo starts to tell him something | **coast**; J-cut rain into the parked car | |
| 22 | s10 → s21 | black, buzz, 0.5 s, fade up | S10: Dante calls with a bigger offer | **cut** on "He was tired. I remember that."; buzz and the talyer land together (NOW) | |
| 23 | s21 → s22 | straight on | S21: overlay two clips, watch the hands | straight on (same bench), as written | |
| 24 | s22 → a3_card | fade | S22: the clip loops, the engine note repeats | **tail** 2 s on the bench after "It looks that way."; fade | no repeating-note audio: the tail does the waiting |
| 25 | a3_card → s23 | fade | — | J-cut crickets: after closing | |
| 26 | s23 → s24 | rain page | S23: Ruel notices the timestamp | crickets carry (L-cut) under the drive-home page | |
| 27 | s24 → s25 | fade | S24: the project file, source clips by date | **tail** 2 s on the wet glass after Ruel's second "Yes."; 0.8 s fade | |
| 28 | s25 → s26 | fade | S25: the composite drives across the monitor | J-cut engine under "Nico peeled the tape off the shutter." | |
| 29 | s26 → a4_card | run ends, fade | S26: lights on the lower road | **coast**; fade | |
| 30 | a4_card → s11 | memory page | — | the 8A page; tint and THE WEEK OF THE NIGHT RUN arrive with the picture | |
| 31 | s11 → s12 | rain page | S11: Ruel wants the tires | J-cut rain under the FRIDAY · DUSK page | |
| 32 | s12 → s13 | wipers page, fade | S12: headlights in the mist, the event begins | rain L-cut across the load into the night run's own rain | |
| 33 | s13 → s27 | black, pulse, wiper, fade up | S13: sound drops out, a pulse continues | the crash's silence and pulse; then the wiper and daylight land together (NOW) | |
| 34 | s27 → s28 | fade, page | S27: Nico marks 8A; Ruel brings the logger | **head** 2 s on the view above 8A before anyone speaks; "Then we read the logger." | |
| 35 | s28 → s29 | straight on | S28: the anonymous-driver notes come off the board | **tail** 2 s after "He picked up a rag."; 0.6 s fade (LATE) | |
| 36 | s29 → s30 | page | S29: Dante messages; the files go to him | Kyo page | no message from Dante: Pang goes himself |
| 37 | s30 → s31 | fade to the phone | S30: Dante's choice, bury or circulate | **cut** on "Sugar?"; J-cut buzz into the group chat | |
| 38 | s31 → a5_card | fade | S31: one copy kept; to Jolo's family | fade | |
| 39 | a5_card → s32 | page | — | J-cut a far dog: "concrete and dogs" | |
| 40 | s32 → s33 | fade, drive | S32: leaves without resolution, through the community | **tail** 2.5 s after "Good."; a slow 1.2 s fade (weeks pass) | |
| 41 | s33 → s33t | arrive, jump | S33: Nico invites a daylight drive | **ease** into Kyo's shot | |
| 42 | s33t → s34 | page | — | "No timer." page | |
| 43 | s34 → s35 | drive ends, fade | S34: engine and tires settle into road noise | **coast** off the end; J-cut rain (the rains come back) | |
| 44 | s35 → end | fade, credits card | S35: the car fades into the ordinary night | L-cut: an engine idle under the end card, fading over 4 s | |
