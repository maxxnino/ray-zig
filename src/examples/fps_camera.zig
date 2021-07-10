const std = @import("std");
const ray = @import("translate-c/raylib_all.zig");

pub fn getRandomValue(comptime T: type, min: i32, max: i32) T {
    const re = ray.GetRandomValue(min, max);
    switch (@typeInfo(T)) {
        .Int => return @intCast(T, re),
        .Float => return @intToFloat(T, re),
        else => unreachable,
    }
}
pub fn main() anyerror!void {
    // Initialization
    //--------------------------------------------------------------------------------------
    const screenWidth = 800;
    const screenHeight = 450;

    ray.InitWindow(screenWidth, screenHeight, "raylib [core] example - 3d camera first person");
    defer ray.CloseWindow();
    // Define the camera to look into our 3d world
    var camera = ray.Camera3D{
        .position = ray.Vector3{ .x = 4, .y = 2, .z = 4 },
        .target = ray.Vector3{ .x = 0, .y = 1.8, .z = 0 },
        .up = ray.Vector3{ .x = 0, .y = 1, .z = 0 },
        .fovy = 60,
        .projection = ray.CAMERA_PERSPECTIVE,
    };
    // Generates some random columns
    const max_columns = 20;
    var heights = [_]f32{0} ** max_columns;
    var positions = [_]ray.Vector3{ray.Vector3{ .x = 0, .y = 0, .z = 0 }} ** max_columns;
    var colors = [_]ray.Color{ray.Color{ .r = 0, .g = 0, .b = 0, .a = 0 }} ** max_columns;
    {
        var i: usize = 0;
        while (i < max_columns) : (i += 1) {
            heights[i] = getRandomValue(f32, 1, 12);
            positions[i] = ray.Vector3{
                .x = getRandomValue(f32, -15, 15),
                .y = heights[i] / 2,
                .z = getRandomValue(f32, -15, 15),
            };
            colors[i] = ray.Color{
                .r = getRandomValue(u8, 20, 255),
                .g = getRandomValue(u8, 10, 55),
                .b = 30,
                .a = 255,
            };
        }
    }
    ray.SetCameraMode(camera, ray.CAMERA_FIRST_PERSON); // Set a first person camera mode
    ray.SetTargetFPS(60);
    //--------------------------------------------------------------------------------------

    // Main game loop
    while (!ray.WindowShouldClose()) {
        // Update
        //----------------------------------------------------------------------------------
        // const deltaTime = ray.GetFrameTime();
        ray.UpdateCamera(&camera);

        // Draw
        //----------------------------------------------------------------------------------
        ray.BeginDrawing();
        ray.ClearBackground(ray.RAYWHITE);

        ray.BeginMode3D(camera);

        ray.DrawPlane(ray.Vector3{ .x = 0, .y = 0, .z = 0 }, ray.Vector2{ .x = 32, .y = 32 }, ray.LIGHTGRAY); // Draw ground
        ray.DrawCube(ray.Vector3{ .x = -16, .y = 2, .z = 0 }, 1, 5, 32, ray.BLUE); // Draw a blue wall
        ray.DrawCube(ray.Vector3{ .x = 16, .y = 2, .z = 0 }, 1, 5, 32, ray.LIME); // Draw a green wall
        ray.DrawCube(ray.Vector3{ .x = 0, .y = 2, .z = 16 }, 32, 5, 1, ray.GOLD); // Draw a yellow wall

        // Draw some cubes around

        var i: usize = 0;
        while (i < max_columns) : (i += 1) {
            ray.DrawCube(positions[i], 2, heights[i], 2, colors[i]);
            ray.DrawCubeWires(positions[i], 2, heights[i], 2, ray.MAROON);
        }

        ray.EndMode3D();

        ray.DrawRectangle(10, 10, 220, 70, ray.Fade(ray.SKYBLUE, 0));
        ray.DrawRectangleLines(10, 10, 220, 70, ray.BLUE);

        ray.DrawText("First person camera default controls:", 20, 20, 10, ray.BLACK);
        ray.DrawText("- Move with keys: W, A, S, D", 40, 40, 10, ray.DARKGRAY);
        ray.DrawText("- Mouse move to look around", 40, 60, 10, ray.DARKGRAY);
        ray.EndDrawing();
    }
}
