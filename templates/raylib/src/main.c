// __NAME__ — a minimal raylib game loop.
// Build: build        Run: run-game        Debug: debug-game  (or Space m b / m r / m d in AstroVim)
#include "raylib.h"

#define SCREEN_WIDTH  800
#define SCREEN_HEIGHT 450

int main(void)
{
    InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "__NAME__");
    SetTargetFPS(60);

    const char *message = "Hello, raylib!";
    int fontSize = 40;
    int frameCount = 0;              // try a breakpoint on the line below and watch this grow

    while (!WindowShouldClose())     // Esc or the window close button ends the loop
    {
        frameCount++;

        // --- update --------------------------------------------------------
        float bounce = (float)((frameCount / 2) % 40) - 20.0f;
        if (bounce < 0) bounce = -bounce;

        // --- draw ----------------------------------------------------------
        BeginDrawing();
            ClearBackground((Color){ 26, 27, 38, 255 });           // Tokyo Night background
            int textWidth = MeasureText(message, fontSize);
            DrawText(message, (SCREEN_WIDTH - textWidth) / 2,
                     SCREEN_HEIGHT / 2 - fontSize / 2 - (int)bounce, fontSize,
                     (Color){ 122, 162, 247, 255 });               // blue
            DrawText("Press Esc to quit", 10, SCREEN_HEIGHT - 30, 20, (Color){ 158, 206, 106, 255 });
            DrawFPS(SCREEN_WIDTH - 90, 10);
        EndDrawing();
    }

    CloseWindow();                   // release the window and OpenGL context
    return 0;
}
