# Advanced movement

- **Goal:** make jumping feel Hollow-Knight-ish — variable height with forgiving timing.
- **Inputs:** Space to jump (press=high arc, release during ascent=short hop).
- **Physics:** `JUMP_VELOCITY=-500`, `JUMP_CUT=-150`, `GRAVITY=1200`, `COYOTE_TIME=0.10`, `JUMP_BUFFER=0.12`.
- **Edge cases:** coyote blocked during dash/focus; jump buffer cleared on successful jump so it can't "echo"; release-cut only applies while still ascending.
- **Done-when:** short taps produce low hops, held presses full height, and jumping one frame after stepping off a ledge still works.
