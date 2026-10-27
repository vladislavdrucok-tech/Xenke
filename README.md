# Afterfall · Остання теплиця — v0.2

A buildless browser prototype for mobile and desktop. Ukrainian interface, detailed pixel-art sprite atlases, a cached environment plate, and local-only progress. No backend or package install is required. v0.1 is retained in repository history.

## Play

Serve `dist/` over HTTP. Hold arrow buttons to move, use the jump button, and hold the context action to harvest. On desktop use A/D or arrow keys, Space to jump, E to interact, C for crafting, I for inventory, Escape for pause.

Complete the short expedition: collect wood and stone, build a workbench at the shelter, salvage metal, cloth and a fuse, build a filter, restore power, collect water, jump over the fallen beam, retrieve seed stock, craft three planting kits, plant three beds, then defend the greenhouse for 90 seconds. The quest, compass, recipe costs, contextual labels and interaction progress bars guide the player.

Hold the action to collect objects or repel nearby burrowing mutants. Health recovers at base, berries restore food, and clean water restores thirst. On defeat the player returns to shelter and keeps their resources. A greenhouse defense failure restarts only the defense; crafted equipment and planting progress are retained. The optimal scripted route takes 163 seconds of simulation, excluding reading and menus, so the first human playthrough is approximately three minutes or more.

## Scope

One fixed map, six recipes, an eight-pose Einstein explorer sprite atlas, a detailed object/creature atlas, resource nodes, a safe stream, a locked seed repository, a jump obstacle, a mutant encounter and six defense waves, planting beds, a companion fox, pollinators and a completion state. The detailed environment is used during actual gameplay. Equipment appears at fixed places when crafted. No freeform terrain digging, multiplayer, native app, token economy, or full world simulation is included in this small scene.

## Performance

The static environment and lower earth are baked once. Gameplay draws the visible rectangle plus culled sprites; it does not reconstruct terrain and skyline each frame. Resource icons are created once and counts update only when changed. The simulation runs at a fixed 60 Hz with bounded catch-up, independently from the 30 FPS default rendering cap. Optional detail mode raises the rendering cap to 60 FPS and the backbuffer budget. Pixel area and particle counts are bounded. CSS blur and external font requests were removed. Local saves are debounced; hidden/paused scenes stop gameplay and unnecessary repaints. Three WebP gameplay assets total about 1 MB. FPS settings are targets, not a guarantee on every device.

## Verification

`node tests.mjs` checks crafting prerequisites, the economy through completion, duplicate planting prevention, defense completion and save validation.

`node engine-test.mjs` drives the actual engine with pointer events under a deterministic DOM/canvas harness. It checks the full route, hold interactions, generator/vault progression, jump obstacle in both directions, water collection, all planting interactions, and the 90-second defense. It also verifies equivalent movement at 15/30/60 FPS and that the resource strip is built only once. Browser QA checks the loaded detailed graphics, crafting UI, and 390×844 and 844×390 embedded mobile viewports. Application console errors were not observed; extension metadata errors are unrelated. This is not a benchmark on the user's physical phone.

Progress is stored in localStorage under `afterfall-last-greenhouse-v2`; it does not sync across devices or browsers. The earlier v0.1 save key is preserved separately. Reset clears only the current expedition and asks for confirmation.

The gameplay screenshot in `docs/afterfall-v02-gameplay.jpg` is captured from the actual running scene. Asset generation briefs and paths are in `docs/art-briefs.md`.
