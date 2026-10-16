# Input

Every device funnels into named actions (`src/game/input/InputActions.ts`); gameplay never sees a key
code, a gamepad index or a pointer event. `InputManager` samples all devices once per frame:

- **Keyboard** and **gamepad** (standard mapping), with deadzones and a steering response curve.
- **Touch** (2026-10-15): `touchState.ts` is a virtual device the on-screen controls write into.
  `TouchControls.tsx` renders on coarse-pointer devices (phones, tablets; `touchAvailable()`): steering
  on the left thumb and the pedals on the right while driving, with e-brake, horn and exit; a move pad
  and the action button on foot. Pointer up, cancel, leave, a pause or an unmount all release what was
  held. The manager treats touch as a controller so the speed-sensitive steering authority applies.

Whichever device is pushed furthest wins an axis; buttons OR across devices; a tap shorter than a frame
still counts once. Menus (`setPaused`) and dialogue (`setContext`) release every device, including touch.

## First-run hints (2026-10-15)

`OnboardingHints` (rules in `hintRules.ts`) teaches the hands while Chapter 1 teaches the story: one
hint at a time, in the order a first drive meets them (pedals and steering; getting out once parked;
using the on-foot prompt; contacts and the menu after 45 s). Each shows once, ever, leaves as soon as
the player does the thing (or taps it), and is remembered in `pang-daily:hints-seen`. Labels follow the
device in hand: a connected gamepad first, then a coarse touch screen, else the keyboard.
