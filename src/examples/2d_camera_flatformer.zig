const std = @import("std");
const ray = @import("translate-c/raylib_all.zig");
const ArrayList = std.ArrayList;
const EnvItem = struct { rect: ray.Rectangle, blocking: bool, color: ray.Color };
const Player = struct {
    const G = 400;
    const hor_speed = 200.0;
    const jump_speed = 350.0;

    position: ray.Vector2,
    speed: f32,
    can_jump: bool,

    pub fn updatePlayer(self: *@This(), envItems: []EnvItem, delta: f32) void {
        if (ray.IsKeyDown(ray.KEY_LEFT)) {
            self.position.x -= hor_speed * delta;
        }
        if (ray.IsKeyDown(ray.KEY_RIGHT)) {
            self.position.x += hor_speed * delta;
        }
        if (ray.IsKeyDown(ray.KEY_SPACE) and self.can_jump) {
            self.speed = -jump_speed;
            self.can_jump = false;
        }
        var hitObstacle = false;
        for (envItems) |item| {
            if (item.blocking and item.rect.x <= self.position.x and
                item.rect.x + item.rect.width >= self.position.x and
                item.rect.y >= self.position.y and
                item.rect.y < self.position.y + self.speed * delta)
            {
                hitObstacle = true;
                self.speed = 0.0;
                self.position.y = item.rect.y;
            }
        }

        if (!hitObstacle) {
            self.position.y += self.speed * delta;
            self.speed += G * delta;
            self.can_jump = false;
        } else {
            self.can_jump = true;
        }
    }
};
const CameraMode = enum {
    center,
    inside,
    smooth,
    bound,
};
pub fn updateCameraCenter(camera: *ray.Camera2D, player: Player, width: f32, height: f32) void {
    camera.offset = ray.Vector2{ .x = width / 2.0, .y = height / 2.0 };
    camera.target = player.position;
}
pub fn updateCameraCenterInsideMap(
    camera: *ray.Camera2D,
    player: Player,
    envItems: []EnvItem,
    width: f32,
    height: f32,
) void {
    camera.target = player.position;
    camera.offset = ray.Vector2{ .x = width / 2.0, .y = height / 2.0 };

    var minX: f32 = 1000;
    var minY: f32 = 1000;
    var maxX: f32 = -1000;
    var maxY: f32 = -1000;

    for (envItems) |ei| {
        minX = std.math.min(ei.rect.x, minX);
        maxX = std.math.max(ei.rect.x + ei.rect.width, maxX);
        minY = std.math.min(ei.rect.y, minY);
        maxY = std.math.max(ei.rect.y + ei.rect.height, maxY);
    }

    var max = ray.GetWorldToScreen2D(ray.Vector2{ .x = maxX, .y = maxY }, camera.*);
    var min = ray.GetWorldToScreen2D(ray.Vector2{ .x = minX, .y = minY }, camera.*);

    if (max.x < width) camera.offset.x = width - (max.x - width / 2);
    if (max.y < height) camera.offset.y = height - (max.y - height / 2);
    if (min.x > 0) camera.offset.x = width / 2 - min.x;
    if (min.y > 0) camera.offset.y = height / 2 - min.y;
}

pub fn updateCameraCenterSmoothFollow(
    camera: *ray.Camera2D,
    player: Player,
    delta: f32,
    width: f32,
    height: f32,
) void {
    const minSpeed = 30;
    const minEffectLength = 10;
    const fractionSpeed = 0.8;

    camera.offset = ray.Vector2{ .x = width / 2.0, .y = height / 2.0 };
    const diff = ray.Vector2Subtract(player.position, camera.target);
    const length = ray.Vector2Length(diff);

    if (length > minEffectLength) {
        const speed = std.math.max(fractionSpeed * length, minSpeed);
        camera.target = ray.Vector2Add(camera.target, ray.Vector2Scale(diff, speed * delta / length));
    }
}
pub fn updateCameraPlayerBoundsPush(camera: *ray.Camera2D, player: Player, width: f32, height: f32) void {
    const bbox = ray.Vector2{ .x = 0.2, .y = 0.2 };

    const bboxWorldMin = ray.GetScreenToWorld2D(ray.Vector2{
        .x = (1 - bbox.x) * 0.5 * width,
        .y = (1 - bbox.y) * 0.5 * height,
    }, camera.*);
    const bboxWorldMax = ray.GetScreenToWorld2D(ray.Vector2{
        .x = (1 + bbox.x) * 0.5 * width,
        .y = (1 + bbox.y) * 0.5 * height,
    }, camera.*);
    camera.offset = ray.Vector2{ .x = (1 - bbox.x) * 0.5 * width, .y = (1 - bbox.y) * 0.5 * height };

    if (player.position.x < bboxWorldMin.x) camera.target.x = player.position.x;
    if (player.position.y < bboxWorldMin.y) camera.target.y = player.position.y;
    if (player.position.x > bboxWorldMax.x) camera.target.x = bboxWorldMin.x + (player.position.x - bboxWorldMax.x);
    if (player.position.y > bboxWorldMax.y) camera.target.y = bboxWorldMin.y + (player.position.y - bboxWorldMax.y);
}
pub fn main() anyerror!void {
    // Initialization
    //--------------------------------------------------------------------------------------
    const screenWidth = 800;
    const screenHeight = 450;

    ray.InitWindow(screenWidth, screenHeight, "raylib [core] example - 2d camera platformer");
    defer ray.CloseWindow();
    var player = Player{ .position = ray.Vector2{ .x = 400, .y = 200 }, .speed = 0, .can_jump = false };
    var envItems = ArrayList(EnvItem).init(std.testing.allocator);
    try envItems.append(EnvItem{
        .rect = ray.Rectangle{ .x = 0, .y = 0, .width = 1000, .height = 1000 },
        .blocking = false,
        .color = ray.LIGHTGRAY,
    });
    try envItems.append(EnvItem{
        .rect = ray.Rectangle{ .x = 0, .y = 400, .width = 1000, .height = 200 },
        .blocking = true,
        .color = ray.GRAY,
    });
    try envItems.append(EnvItem{
        .rect = ray.Rectangle{ .x = 300, .y = 200, .width = 400, .height = 10 },
        .blocking = true,
        .color = ray.GRAY,
    });
    try envItems.append(EnvItem{
        .rect = ray.Rectangle{ .x = 650, .y = 300, .width = 100, .height = 10 },
        .blocking = true,
        .color = ray.GRAY,
    });

    var camera = ray.Camera2D{
        .target = player.position,
        .offset = ray.Vector2{ .x = screenWidth / 2.0, .y = screenHeight / 2.0 },
        .rotation = 0,
        .zoom = 1,
    };
    var cam_mode = CameraMode.center;

    ray.SetTargetFPS(60);
    //--------------------------------------------------------------------------------------

    // Main game loop
    while (!ray.WindowShouldClose()) {
        // Update
        //----------------------------------------------------------------------------------
        const deltaTime = ray.GetFrameTime();
        player.updatePlayer(envItems.items, deltaTime);

        camera.zoom += ray.GetMouseWheelMove() * 0.05;

        if (camera.zoom > 3.0) {
            camera.zoom = 3.0;
        } else if (camera.zoom < 0.25) camera.zoom = 0.25;

        if (ray.IsKeyPressed(ray.KEY_R)) {
            camera.zoom = 1.0;
            player.position = ray.Vector2{ .x = 400, .y = 280 };
        }

        if (ray.IsKeyPressed(ray.KEY_C)) {
            cam_mode = @intToEnum(CameraMode, @enumToInt(cam_mode) +% 1);
        }

        switch (cam_mode) {
            .center => updateCameraCenter(&camera, player, screenWidth, screenHeight),
            .inside => updateCameraCenterInsideMap(&camera, player, envItems.items, screenWidth, screenHeight),
            .smooth => updateCameraCenterSmoothFollow(&camera, player, deltaTime, screenWidth, screenHeight),
            .bound => updateCameraPlayerBoundsPush(&camera, player, screenWidth, screenHeight),
        }

        // Draw
        //----------------------------------------------------------------------------------
        ray.BeginDrawing();
        ray.ClearBackground(ray.LIGHTGRAY);

        ray.BeginMode2D(camera);

        for (envItems.items) |item| {
            ray.DrawRectangleRec(item.rect, item.color);
        }

        const playerRect = ray.Rectangle{
            .x = player.position.x - 20,
            .y = player.position.y - 40,
            .width = 40,
            .height = 40,
        };
        ray.DrawRectangleRec(playerRect, ray.RED);

        ray.EndMode2D();
        ray.DrawText("Controls:", 20, 20, 10, ray.BLACK);
        ray.DrawText("- Right/Left to move", 40, 40, 10, ray.DARKGRAY);
        ray.DrawText("- Space to jump", 40, 60, 10, ray.DARKGRAY);
        ray.DrawText("- Mouse Wheel to Zoom in-out, R to reset zoom", 40, 80, 10, ray.DARKGRAY);
        ray.DrawText("- C to change camera mode", 40, 100, 10, ray.DARKGRAY);
        ray.DrawText("Current camera mode:", 20, 120, 10, ray.BLACK);
        switch (cam_mode) {
            .center => ray.DrawText("Camera Center", 40, 140, 10, ray.DARKGRAY),
            .inside => ray.DrawText("Camera Center Inside Map", 40, 140, 10, ray.DARKGRAY),
            .smooth => ray.DrawText("Camera Smooth Follow Player Center", 40, 140, 10, ray.DARKGRAY),
            .bound => ray.DrawText("Player push camera on getting too close to screen edge", 40, 140, 10, ray.DARKGRAY),
        }

        ray.EndDrawing();
    }
}
