# Mana running movement model

## Game behavior

Mana charging remains the player's responsibility. A mana run begins when the player charges mana and double-taps `W`. Tapping Up Arrow after the run starts puts it into a neutral state: the character runs in place without changing the camera direction. From neutral, holding Up Arrow moves forward and holding Down Arrow moves backward. Physical `A` and `D` move left and right while the neutral run is active.

## Runtime modes

Multi-Directional mode is the default. It supports all four directions and keeps one axis session alive:

| Activation | Setup after the second tap |
| --- | --- |
| `W` | Uses the native second `W` press, taps Up to establish neutral, then holds Up |
| `S` | Synthesizes a `W` tap and hold, taps Up for neutral, then taps and holds Down |
| `A` | Synthesizes a `W` tap and hold, taps Up for neutral, then uses physical `A` |
| `D` | Synthesizes a `W` tap and hold, taps Up for neutral, then uses physical `D` |

Only the opposite direction on the active axis changes the session:

- `W ↔ S` releases the current synthetic arrow and holds the opposite arrow.
- In an `S`-initiated session, synthetic `W` remains held for as long as physical `S` remains held. During that state, physical `W` is consumed as an Up Arrow rebind, so its key-up cannot release Roblox's synthetic `W` foundation. In vertical sessions outside that state, physical `W` is forwarded normally, including native double-tap activation. If `S` is released while physical `W` remains held, ownership transfers to the player's `W` without sending `W Up`.
- `A ↔ D` releases the previously active lateral key in Roblox while the physical key remains held, allowing the newly pressed opposite key to take control instead of letting `A + D` cancel each other.
- During an `A`/`D` session, physical `W` is consumed and held as synthetic Up Arrow input. Releasing `W` releases Up Arrow without disturbing the synthetic `W` that sustains the mana run.
- Releasing the newer direction falls back to the opposite direction when that key is still physically held.
- Releasing the active-axis keys leaves the session running while any other physical `W`/`A`/`S`/`D` key is still held. This allows, for example, an `A`-initiated run to continue forward on held Up Arrow after `W` is pressed and `A` is released.
- The session ends and releases all synthetic output only after every physical `W`/`A`/`S`/`D` key is released.
- Other keys from the opposite axis pass through without replacing the active session.

If a physical `W` release would cancel a session while another WASD key remains held, the runtime transfers ownership of the existing logical `W` hold to the session without emitting `W Up`. The final WASD release emits the matching synthetic `W Up`. Remap output blocks new activation but does not interrupt an active run. Losing Roblox focus, opening chat, disabling the runtime, or shutting it down releases every synthetic key and restores any temporarily suppressed physical lateral key.

In Multi-Directional mode only, physical `G`, `Q`, `V`, left click, and right click remain passed through to Roblox and immediately reset pending taps and active run state, with one exception: left click (M1) and right click (M2) preserve the run while autoclicking is on **HOLD** because of the selected ability's policy (`AbilityAutoclickEnabled = false`). This uses the same state as the HUD's HOLD indicator, not whether the click loop happens to be running. Once autoclicking is allowed again, the next physical M1 or M2 press cancels normally. `G`, `Q`, and `V` still cancel during HOLD. Held physical `W`/`S` keeps its matching synthetic Up/Down Arrow after cancellation even though the run HUD and activation state switch off; that arrow is released with the physical key or before a new run activates. If physical `W` is still held, ownership of the existing logical `W` hold also returns to that physical key instead of emitting `W Up`. Because Roblox can clear its internal movement state while processing a cancellation input, the runtime reasserts every still-held physical WASD direction after 30 ms. Physical movement therefore resumes in Roblox's walking state, and normal key-up events release it later.

For `Q` during an active Multi-Directional run with physical `A` or `S` held, the runtime intercepts the dash key, releases `W` and any forward arrow, and reasserts A if physically held before forwarding `Q Down`. An existing Down Arrow hold is preserved while physical S remains held. This prevents `W` from taking priority when Roblox selects the dash direction. There is no additional sleep before `Q`; its physical release is forwarded as `Q Up`. The run state ends as usual. After the existing 30 ms walking-resume delay, other physically held directions are restored, so synthetic `W` stays released unless the player is also physically holding `W`.

These dash adjustments require an active macro run. Outside that state, Q
forwards only `Q Down` / `Q Up`: no directional prefix, movement reset, or new
walking-restoration timer. Pending taps and any existing walking arrow remain
untouched. This includes A+Q, S+Q, mixed held directions, and Q key repeat after
the initial dash has already ended the run. A restoration timer already pending
from an earlier run cancellation retains its original behavior.

S remains continuously under physical input control during the dash: no
synthetic `S Up` or `S Down` is sent before Q, after Q-down, after Q-up, or by
the dash's delayed movement callback when S was held at dash initiation.
An existing backward arrow is not released/re-pressed by the dash; the physical
S release releases it normally. The same physical S behavior applies while
walking, without creating a backward arrow. Focus/chat/disable/shutdown cleanup
still releases macro-owned arrows. This preserves the macro's output hold;
in-game validation is needed to confirm how Roblox handles the dash animation.

Legacy mode keeps the original held-`W` behavior. Pressing `S` while `W` is held enters backward movement; releasing `S` returns to forward movement. `G`, `Q`, `V`, left click, and right click do not reset legacy run state or release its arrow output; `Q` passes through without dash interception.

## Stability validation

The current priority is a stable input-driven Multi-Directional baseline.
Image detection is deferred; see the [future design and training plan](IMAGE_DETECTION.md).
The Run HUD indicates macro state, not confirmed game state. Climbing and other
game-driven interruptions can still leave that estimate out of sync. Space is
not treated as proof of climbing.

The periodic movement check processes missed key releases through the same
ownership and arrow cleanup as normal key-up callbacks, including walking
arrows retained after cancellation. Focus/chat/disable cleanup runs before
direction reconciliation and cancels pending walking restoration. This check
currently shares the 250 ms overlay timer; it is a fallback, not an immediate
observation of game state.

Automated AHK regressions capture generated keys and supply fake physical key
states. They exercise all four activations, opposite-direction fallback,
native/synthetic W ownership transfers, lateral W arrow rebinding, missed
key-up recovery, cancellation and delayed walking restoration, tap expiry,
remap gating, focus/chat/disable cleanup, shutdown, and legacy cancellation
isolation. They do not prove Roblox accepted the generated input.

### In-game acceptance checklist — pending

Run these in Roblox with mana charged as required. Record pass/fail, runtime
revision, game settings, and reproduction steps. Verify actual movement as
well as the HUD, and finish each case with all physical keys released.

| Case | Expected result |
| --- | --- |
| Double-tap W, A, S, D separately | Correct direction; final key release stops output |
| Single taps, slow taps, held-key repeat | No unintended activation |
| W-to-S and S-to-W, then release the newer key | Opposite direction takes priority, then falls back |
| A-to-D and D-to-A; hold longer than keyboard repeat delay | Opposite direction stays in control; no opposing-key cancellation |
| W run, hold A/D, release W, then release remaining key | Session survives W release; final release cleans up |
| S run, press W, release S, then W | Forward handoff works; no stuck W or arrow |
| Lateral run, press/release W; also release A/D before W | W uses forward arrow without breaking the run; final release cleans up |
| G, V during each direction; M1/M2 with autoclick allowed | HUD resets; held movement continues walking; key-up stops it |
| M1/M2 press/release with autoclick HOLD in each direction | Run/HUD and movement output persist; next M1/M2 after leaving HOLD cancels normally |
| G, Q, V with autoclick HOLD | Run still cancels; HOLD exempts M1/M2 |
| Q with A/S, including W+A and W+S held | Intended dash direction; run resets; held walking resumes |
| A+Q, S+Q, A+S+Q, W+A+Q, W+S+Q outside a run | Only Q is forwarded; no movement changes or new restoration timer |
| Hold S, press/release Q while running and while walking | Physical S stays held; existing backward arrow is continuous; no S re-press at Q-up or on the timer |
| Release S before Q-up or the delayed restoration | S stays released; no unexpected backward movement |
| Cancel then immediately release or start a new run | Delayed callback neither resurrects released movement nor overwrites the new run |
| Open chat, toggle off, Alt-Tab/minimize, stop/reload runtime while holding movement | Synthetic output cleans up; no unexpected restart or stuck keys |
| Release keys while unfocused, then return | No stale held-key state; next activation works |
| Remap during active run, then attempt activation during remap | Existing run survives; new activation is blocked while remap output is busy |
| Repeat representative cases in Legacy mode | Original held-W behavior; G/Q/V/clicks do not reset macro state |
| Climb, jump, land, take a game-driven interruption | Record input-model limitations; do not claim visual state confirmation |

Automated checks are a prerequisite. This checklist must pass before describing
the baseline as validated in-game or beginning the image-detection variant.
