// Loads a .glb with raylib (the way a game does) and reports what arrived.
// usage: load_glb FILE.glb MIN_MESHES      exit 0 if the model has >= MIN_MESHES meshes
#include <stdio.h>
#include <stdlib.h>
#include "raylib.h"

int main(int argc, char **argv)
{
    if (argc < 3) { fprintf(stderr, "usage: %s FILE.glb MIN_MESHES\n", argv[0]); return 2; }
    SetTraceLogLevel(LOG_WARNING);
    SetConfigFlags(FLAG_WINDOW_HIDDEN);        // needs a GL context, but no visible window
    InitWindow(64, 64, "load_glb");
    Model m = LoadModel(argv[1]);
    BoundingBox b = GetModelBoundingBox(m);
    printf("meshes=%d materials=%d bounds=(%.1f %.1f %.1f)..(%.1f %.1f %.1f)\n",
           m.meshCount, m.materialCount, b.min.x, b.min.y, b.min.z, b.max.x, b.max.y, b.max.z);
    int ok = m.meshCount >= atoi(argv[2]);
    UnloadModel(m);
    CloseWindow();
    return ok ? 0 : 1;
}
