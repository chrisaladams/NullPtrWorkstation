# Blockbench: low-poly 3D models

[Blockbench](https://www.blockbench.net/) makes low-poly, pixel-textured 3D models: props,
characters and rooms for 2.5D games. You paint textures right on the model, and it exports to
glTF and OBJ.

| | |
|---|---|
| `Super+5` | workspace **5: blockbench** (Blockbench always opens here) |
| `Super+B` or `3d` | focus Blockbench, or start it if it isn't running (never a second copy) |
| `3d model.bbmodel` | open a specific model |

`3d` starts in the project you are working on (its `assets/` folder if it has one), so save and
export dialogs start there.

## Getting models into a game

- Start a **Generic Model** project (*File ▸ New ▸ Generic Model*).
- Pixel textures: set the texture size to match your sprites (16×16, 32×32), then paint with the
  pencil. Textures can also be PNGs you made in LibreSprite.
- *File ▸ Export ▸ Export glTF Model*: choose **.glb** (one file with mesh, textures and
  animations). OBJ exports a mesh plus a `.mtl` and the PNG textures.
- raylib loads both: `LoadModel("assets/room.glb")`. Other engines and libraries (cgltf, assimp,
  tinyobjloader) read the same files.

Blockbench is Y-up, like raylib. One Blockbench unit is 1/16 of a block, so scale the model when
you draw it (`DrawModel(model, pos, 1.0f/16.0f, WHITE)`) or scale it on export.

## Version

Blockbench 5.2.2, the official `.deb` from its GitHub releases, pinned by SHA-256 in
`versions.lock` and installed by the ISO and by `nullptr-update`. Blockbench can also check for
updates itself; the workstation's version only changes when `versions.lock` does.
