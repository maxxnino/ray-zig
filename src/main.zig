const std = @import("std");
const ray = @import("translate-c/raylib_all.zig");
pub fn main() anyerror!void {
    // Initialization
    //--------------------------------------------------------------------------------------
    const screenWidth = 800;
    const screenHeight = 450;

    ray.InitWindow(screenWidth, screenHeight, "raylib [core] example - 2d camera platformer");
    defer ray.CloseWindow();

    ray.SetTargetFPS(60);
    //--------------------------------------------------------------------------------------

    // Main game loop
    while (!ray.WindowShouldClose()) {
        // Update
        //----------------------------------------------------------------------------------
        // const deltaTime = ray.GetFrameTime();

        // Draw
        //----------------------------------------------------------------------------------
        ray.BeginDrawing();
        ray.ClearBackground(ray.LIGHTGRAY);

        ray.EndDrawing();
    }
}
