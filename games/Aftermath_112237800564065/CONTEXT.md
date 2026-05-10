# Aftermath v1 Notes

PlaceId: `112237800564065`

## Dump analysis summary

- Source dump: `Pro Script Dumper/[112237800564065] Aftermath`
- Scripts processed: `2878`
- Failed/timeouts: `0`
- Core combat remotes observed under `ReplicatedStorage.GunSystem.Event.GunEvent.*`
- Generic networking observed under `ReplicatedStorage.BufferNetRemotes.*` and Ember shared buffer net routes

## v1 script scope

The first implementation is intentionally visual-only and low risk:

- Square ESP (Drawing square around enemies)
- Tracer (bottom-center screen line to enemy)
- Team check toggle
- Small draggable panel built with `New_Mya/lib/ui.luau`

No remote firing or weapon mutation is used in this first version.
