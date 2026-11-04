// __NAME__ — Game Boy "Hello" with GBDK-2020.
// Build: gb-build    Run: gb-run    Debug (C source, breakpoints): gb-debug  (or Space m b / m r / m d)
#include <gb/gb.h>
#include <stdint.h>
#include <stdio.h>
#include <gbdk/console.h>

uint8_t frame_counter = 0;              // global: visible in the debugger's Variables pane
uint16_t a_presses = 0;

void main(void)
{
    uint8_t keys = 0;

    printf("\n\n\n\n   Hello, Game Boy!\n");
    printf("\n\n     Press A\n");

    while (1) {
        keys = joypad();                // good first breakpoint: inspect `keys`
        if (keys & J_A) {
            a_presses++;
            gotoxy(3, 12);
            printf("A x %u   ", a_presses);
            waitpadup();
        }
        frame_counter++;
        vsync();                        // wait for the next frame (60 Hz)
    }
}
