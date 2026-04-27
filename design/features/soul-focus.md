# Soul and Focus

- **Goal:** earn soul by hitting enemies, spend it to heal a mask (HK's Focus).
- **Inputs:** hold L while stationary and grounded to charge for 1.0s; releases one mask per 33 soul.
- **Physics:** `SOUL_MAX=99`, `SOUL_PER_HIT=11`, `FOCUS_COST=33`, `FOCUS_DURATION=1.0`.
- **Edge cases:** any movement / jump / attack / dash / leaving ground / full HP / insufficient soul cancels focus; taking damage also cancels.
- **Done-when:** after three hits (33 soul), standing still and holding L for 1s restores one HP mask and deducts 33 soul.
