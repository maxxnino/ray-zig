const std = @import("std");
const ray = @cImport(@cInclude("raylib.h"));
pub fn main() anyerror!void {
    const screenWidth = 800;
    const screenHeight = 600;
    ray.InitWindow(screenWidth, screenHeight, "olala");
    defer ray.CloseWindow();
    ray.SetTargetFPS(60);
    while (!ray.WindowShouldClose()) {
        ray.BeginDrawing();
        ray.ClearBackground(ray.RAYWHITE);
        ray.DrawText("Congrats! You created your first window!", 190, 200, 20, ray.LIGHTGRAY);
        ray.EndDrawing();
    }
}
