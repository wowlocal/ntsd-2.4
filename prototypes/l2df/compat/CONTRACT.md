# Compatibility modules — implementation contract

These modules derive their algorithms from retained NTSD source studies and
accepted native translations. They never consume expected after-state as game
state. The current adapter is a candidate integration; full tick fidelity needs
separate comparison. Original execution is outside this task.

`actor_input.lua` exposes `captureEdges(a)`, `invalidates(a,key,advanced)`,
`transfer(a,target,frames,globals)`, `recognizeCombos(a,frames,globals)`,
`applyFrameInput(a,frames,globals)` and `apply(a,frames,globals)`.
Mutating operations return a new actor and (except capture) event list, leaving
inputs unchanged on unsupported-frame errors. `invalidates` takes ASCII key
letters or byte values. This is not a parser or raw memory ABI.

Actor fields: `sourceID, frame, facing` (0 right/1 left), `hp, mp, healthSpent,
chakraSpent, status98, field324, field328, field338`; `buffers` contains raw-byte
`attack,jump,defend,defendCooldown,right,left,up,down`; `previous/current` contain
raw-byte held flags for the seven keys; `history[1..5]` is oldest to newest;
`progress[1..9]` follows the nine source recognizers. The caller owns every field.
The explicit `practice` initializer declares controlled initial values, not
unknown source constructor backing. MP/HP/stat arithmetic is wrapping Int32.

`frames[id]` has `present` and numeric `mp,hit_a,hit_d,hit_j,hit_Fa,hit_Ua,hit_Da,
hit_Fj,hit_Uj,hit_Dj,hit_ja`. Missing scalar fields mean known Frame-constructor
zero; a missing frame-table entry explicitly means absent within the declared
400-entry projection. Target outside 0..399 is unsupported and throws. Globals:
`costEnabled` is bool or original integer; `flag458428` is original integer.

Source: `docs/research/ACTOR_INPUT.md`, `OriginalActorInput.swift`, addresses
413080..4132ef,40e170..40e48a,412800..413077. Standalone comparisons may cover the
whole projected contract; integration into L2DF does not prove original update
order, loader storage, physics or all callers.

`spawn.spawn(pool,parentSlot,frame,catalog,heldInputs)` returns new owned pool
and an ordered array of born zero-based slots. Pool entries are
`{slot,id,owner,team,motion}` (fighters occupy slots0/1); `motion` uses the names
in retained `FighterState`, original y negative upwards and facing0/1. `vrest`
has keys0..399, not Lua1..400. `frame.opoint` has original named numeric fields;
`catalog[id][frameID]` has original state/velocity/schedule scalar fields.
`heldInputs[playerSlot]` contains up/down booleans. These are actual caller inputs.
The retained spawn domain is kind1 and facing0/1/50; unsupported catalog/frame
or forms throw before the old pool is changed. Allocation is first-free50..399;
input-derived aim, integer parent projection, z+1, pending0.1, fan, rest and
mutual vrest are computed by the module. No Opoint DVZ is invented.

`projectile.control/physics/pending(state,frames)` return a new motion state;
`bounds(state,width,zMin,zMax)` returns state, alive;
`schedule(state,frames)` returns state, alive, ordered sound paths;
`hitReaction(state,frames,guarded)` performs the original state3000 reaction.
`pending` does not require frames. This is the bounded PROJECTILES domain,
including type3 schedule during freeze. A draining hit_a scheduler is explicitly
unsupported here; it needs the newer whole scheduler contract rather than a guess.
The caller must retain render-before-schedule and ascending dynamic slot visits.

`projectile_hits.collect(pool,catalog,random)` returns owned pool, ordered
per-slot contacts and the frozen frame records used for this contact pass.
The RNG callback must implement declared original draws; none is substituted.
`resolve(pool,attackerSlot,targetSlot,itr,attackerFrame,targetFrame,catalog)`
returns pool plus damage/guard/sound events. Domain: original kind0/effect0,1,
type0 target slots0/1, PROJECTILES catalog/controlled values. Other effects or
target types reject. It preserves auxiliary boxes, ascending unordered pairs,
strict rectangle/depth boundaries, defender-indexed vrest, owned damage/kill
credit, and the distinct type3 normal/guard frame10 reactions. The domain does
not claim all OriginalHitDamage/OriginalHitGuard source-ID/weapon exceptions.
