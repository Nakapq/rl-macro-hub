# Mana running movement model

## Game behavior

Mana charging remains the player's responsibility. A mana run begins when the player charges mana and double-taps `W`. Tapping Up Arrow after the run starts puts it into a neutral state: the character runs in place without changing the camera direction. From neutral, holding Up Arrow moves forward and holding Down Arrow moves backward. Physical `A` and `D` move left and right while the neutral run is active.

## Runtime modes

Legacy mode keeps the original held-`W` behavior. Pressing `S` while `W` is held enters backward movement; releasing `S` returns to forward movement.

Double Tap mode implements the supplied independent `S`/`A`/`D` structure. A second press within 200 ms synthesizes the `W` mana-run setup and taps Up Arrow. `S` also taps and holds Down Arrow. Releasing the activating direction ends the sequence.

Multi-Directional mode extends that structure to all four directions and keeps one axis session alive:

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

Physical `G`, `Q`, `V`, left click, and right click remain passed through to Roblox and immediately reset pending taps and active run state. In Multi-Directional mode, held physical `W`/`S` keeps its matching synthetic Up/Down Arrow even though the run HUD and activation state switch off; that arrow is released with the physical key or before a new run activates. If physical `W` is still held, ownership of the existing logical `W` hold also returns to that physical key instead of emitting `W Up`. Because Roblox can clear its internal movement state while processing a cancellation input, the runtime reasserts every still-held physical WASD direction after 30 ms. Physical movement therefore resumes in Roblox's walking state, and normal key-up events release it later.
