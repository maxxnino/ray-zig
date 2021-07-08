const std = @import("std");
const ray = @cImport(@cInclude("raylib.h"));
pub fn main() anyerror!void {
    const screenWidth = 800;
    const screenHeight = 600;
    ray.InitWindow(screenWidth, screenHeight, "olala");
    defer ray.CloseWindow();
    ray.SetTargetFPS(60);
    var ballPosition = ray.Vector2{ .x = 400.0, .y = 300.0 };
    var ballColor = ray.DARKBLUE;
    while (!ray.WindowShouldClose()) {
        //Keyboard
        if (ray.IsKeyDown(ray.KEY_RIGHT)) {
            ballPosition.x += 2.0;
        }
        if (ray.IsKeyDown(ray.KEY_LEFT)) {
            ballPosition.x -= 2.0;
        }
        if (ray.IsKeyDown(ray.KEY_UP)) {
            ballPosition.y -= 2.0;
        }
        if (ray.IsKeyDown(ray.KEY_DOWN)) {
            ballPosition.y += 2.0;
        }

        //mouse
        ballPosition = ray.GetMousePosition();
        if (ray.IsMouseButtonPressed(ray.MOUSE_BUTTON_LEFT)) {
            ballColor = ray.MAROON;
        } else if (ray.IsMouseButtonPressed(ray.MOUSE_BUTTON_MIDDLE)) {
            ballColor = ray.LIME;
        } else if (ray.IsMouseButtonPressed(ray.MOUSE_BUTTON_RIGHT)) {
            ballColor = ray.DARKBLUE;
        } else if (ray.IsMouseButtonPressed(ray.MOUSE_BUTTON_SIDE)) {
            ballColor = ray.PURPLE;
        } else if (ray.IsMouseButtonPressed(ray.MOUSE_BUTTON_EXTRA)) {
            ballColor = ray.YELLOW;
        } else if (ray.IsMouseButtonPressed(ray.MOUSE_BUTTON_FORWARD)) {
            ballColor = ray.ORANGE;
        } else if (ray.IsMouseButtonPressed(ray.MOUSE_BUTTON_BACK)) {
            ballColor = ray.BEIGE;
        }
        //Draw
        ray.BeginDrawing();
        ray.ClearBackground(ray.RAYWHITE);
        ray.DrawText("Congrats! You created your first window!", 190, 200, 20, ballColor);
        ray.DrawCircleV(ballPosition, 50, ray.MAROON);
        ray.EndDrawing();
    }
}
