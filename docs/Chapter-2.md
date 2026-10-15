# Chapter 2: Build It

Opens when Chapter 1 grants `chapter_2_access`; the server creates the `chapter_2` progress row the
first time it looks (`advanceChapterTwo`, `apps/api/src/database/chapter-state.ts`). Like Chapter 1,
every beat is a read model of rows the economy already writes; the chapter stores only its markers.

| Beat ID | Evidence |
| --- | --- |
| `first_upgrade` | Any `InstalledPart` on an owned car. |
| `marketplace_gamble` | A `PART_PURCHASE` transaction whose source starts with `marketplace:`. |
| `trusted_inspection` | A `PART_INSPECTION` transaction (Tito Jun revealed a part). |
| `rematch_casey` | `pahuway_descent` finished (win or loss); a started attempt shows as active, a DNF as recoverable. |
| `crew_invitation` | `CrewMembership` for `kyo_regulars` with status `member`. |

Completion grants `chapter_3_access`. `chapter_continue` accepts `chapterId: 'chapter_2'`; beat ids are
validated per chapter. The HUD (`ChapterExperience`) shows whichever chapter is not yet complete
(`activeChapterId`), with Chapter 2 scenes from `CHAPTER_TWO_SCENES`; `ChapterGuide` points at the
talyer, the mountain road and KYO (the Marketplace beat is on the phone and points nowhere).

Not authored yet: Chapter 2 dialogue beats at KYO (Casey's rivalry turning into friendship is told
through the existing rival outcome conversations), and Chapter 3.
