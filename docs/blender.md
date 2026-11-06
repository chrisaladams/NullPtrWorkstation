# Blender: 3D and 2.5D scenes

Blender has its own workspace, like LibreSprite:

| | |
|---|---|
| `Super+3` | workspace **3: blender** (Blender always opens here) |
| `Super+B` or `3d` | focus Blender, or start it if it isn't running (never a second copy) |
| `3d file.blend` | open a specific file |

`3d` starts Blender in the active project's `assets/` folder, so export dialogs default there.

On first start Blender shows a *Quick Setup* screen (language, shortcuts, theme). Click
**Continue** once; it doesn't block anything.

## Laptop settings worth changing once

*Edit ▸ Preferences ▸ Input*:

- **Emulate Numpad** on: the X1 Carbon has no number pad, and Blender's view keys
  (front/side/top view = `1`/`3`/`7`) live there. With this on, the number row works instead.
- The TrackPoint's middle button orbits the view, so *Emulate 3 Button Mouse* isn't needed.
  Turn it on if you use only the touchpad (`Alt` + left drag orbits).

The laptop's Intel UHD 620 handles modelling and the Solid/Workbench viewport well. Use
**EEVEE** for previews of small scenes; **Cycles** renders on the CPU only (no supported GPU),
so keep Cycles for final renders of small scenes.

The drawing tablet works for sculpting and texture painting. Unlike LibreSprite, Blender
reads pen pressure on X11. That is untested on your H640P (no tablet here).

## Getting models into raylib

raylib loads **glTF** (`.glb`/`.gltf`), OBJ, IQM, VOX and M3D. Use glTF binary (`.glb`): one
file with meshes, materials, textures and animations.

*File ▸ Export ▸ glTF 2.0*:
- Format: **glTF Binary (.glb)**
- *Include ▸ Limit to*: **Selected Objects** if you export one prop at a time
- *Transform*: **+Y Up** on (the default; raylib is Y-up, Blender is Z-up)
- *Mesh*: **Apply Modifiers** on
- Save into the project's `assets/` folder

```c
Model room = LoadModel("assets/room.glb");   // after InitWindow()
// in the draw loop, inside BeginMode3D(camera) / EndMode3D():
DrawModel(room, (Vector3){ 0, 0, 0 }, 1.0f, WHITE);
// on exit:
UnloadModel(room);
```

Skeletal animations come with `LoadModelAnimations("assets/pirate.glb", &count)` and
`UpdateModelAnimation(model, anims[i], frame)`.

## Two ways to do 2.5D rooms

1. **Real 3D, fixed camera.** Export each room as `.glb` and draw it with a fixed
   `Camera3D`. Use `CAMERA_ORTHOGRAPHIC` for the classic diorama look; characters are 3D
   models or camera-facing sprites (`DrawBillboard`). The same diorama in Blender is the
   in-game level.
2. **Pre-rendered.** Render the room in Blender from the game's camera angle to PNG
   (*Render ▸ Render Image*, then save into `assets/`). Draw it as a background and walk
   sprites over it, with a few invisible boxes for collision. Cheap to draw and looks exactly
   like the render.

For **Game Boy** projects only the second way applies: render at 160×144 (or tile-sized
pieces) with few colours, reduce to 4 shades in LibreSprite, then convert with
`/opt/gbdk/bin/png2asset`.

## Packages

`blender` and `python3-numpy`. Blender's glTF exporter needs numpy; without it,
*Export ▸ glTF* fails. On a system installed from an older ISO:

```bash
sudo apt install blender python3-numpy
```

## Test status

Verified automatically (`tests/blender/`): Blender exports a small diorama (floor, walls,
crate) headless as `.glb`, and a raylib program loads it with all 4 meshes and their materials
at the right size and orientation. Also verified: `3d` opens Blender on workspace 3 and never
starts a duplicate.
