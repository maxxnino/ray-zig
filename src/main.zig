const std = @import("std");
const ray = @import("translate-c/raylib.zig");
const PostProcessShader = enum {
    bloom,
    blur,
    cross_hatching,
    cross_stitching,
    dream_vision,
    fisheye,
    grayscale,
    pixelizer,
    posterization,
    predator_view,
    scanlines,
    sobel,
};
pub fn loadShader(shader_type: PostProcessShader) ray.Shader {
    return switch (shader_type) {
        .bloom => return ray.LoadShader(null, "3rd/raylib/examples/shaders/resources/shaders/glsl330/bloom.fs"),
        .blur => return ray.LoadShader(null, "3rd/raylib/examples/shaders/resources/shaders/glsl330/blur.fs"),
        .cross_hatching => return ray.LoadShader(null, "3rd/raylib/examples/shaders/resources/shaders/glsl330/cross_hatching.fs"),
        .cross_stitching => return ray.LoadShader(null, "3rd/raylib/examples/shaders/resources/shaders/glsl330/cross_stitching.fs"),
        .dream_vision => return ray.LoadShader(null, "3rd/raylib/examples/shaders/resources/shaders/glsl330/dream_vision.fs"),
        .fisheye => return ray.LoadShader(null, "3rd/raylib/examples/shaders/resources/shaders/glsl330/fisheye.fs"),
        .grayscale => return ray.LoadShader(null, "3rd/raylib/examples/shaders/resources/shaders/glsl330/grayscale.fs"),
        .pixelizer => return ray.LoadShader(null, "3rd/raylib/examples/shaders/resources/shaders/glsl330/pixelizer.fs"),
        .posterization => return ray.LoadShader(null, "3rd/raylib/examples/shaders/resources/shaders/glsl330/posterization.fs"),
        .predator_view => return ray.LoadShader(null, "3rd/raylib/examples/shaders/resources/shaders/glsl330/predator.fs"),
        .scanlines => return ray.LoadShader(null, "3rd/raylib/examples/shaders/resources/shaders/glsl330/scanlines.fs"),
        .sobel => return ray.LoadShader(null, "3rd/raylib/examples/shaders/resources/shaders/glsl330/sobel.fs"),
    };
}
pub fn unloadShader() void {}
pub fn main() anyerror!void {
    // Initialization
    //--------------------------------------------------------------------------------------
    const screenWidth = 800;
    const screenHeight = 450;
    const total_shader = @intCast(std.meta.Tag(PostProcessShader), std.meta.fields(PostProcessShader).len);
    ray.SetConfigFlags(ray.FLAG_MSAA_4X_HINT); // Enable Multi Sampling Anti Aliasing 4x (if available)
    ray.InitWindow(screenWidth, screenHeight, "raylib [shaders] example - postprocessing shader");
    defer ray.CloseWindow();

    // Define the camera to look into our 3d world
    var camera = ray.Camera{
        .position = ray.Vector3{ .x = 2, .y = 3, .z = 2 },
        .target = ray.Vector3{ .x = 0, .y = 1, .z = 0 },
        .up = ray.Vector3{ .x = 0, .y = 1, .z = 0 },
        .fovy = 45,
        .projection = ray.CAMERA_PERSPECTIVE,
    };

    var model = ray.LoadModel("3rd/raylib/examples/shaders/resources/models/church.obj"); // Load OBJ model
    defer ray.UnloadModel(model); // Unload model

    var texture = ray.LoadTexture("3rd/raylib/examples/shaders/resources/models/church_diffuse.png"); // Load model texture
    defer ray.UnloadTexture(texture); // Unload texture
    // (diffuse map)

    model.materials[0].maps[ray.MATERIAL_MAP_DIFFUSE].texture = texture; // Set model diffuse texture

    var position = ray.Vector3{ .x = 0, .y = 0, .z = 0 }; // Set model position

    // Load all postpro shaders
    // NOTE 1: All postpro shader use the base vertex shader
    // (DEFAULT_VERTEX_SHADER) NOTE 2: We load the correct shader depending on
    // GLSL version

    var shaders: [total_shader]ray.Shader = undefined;
    for (shaders) |*sh, i| {
        sh.* = loadShader(@intToEnum(PostProcessShader, @intCast(std.meta.Tag(PostProcessShader), i)));
    }
    //TODO: find a way to deffer clean shader
    // comptime for (shaders) |sh| {
    //     defer ray.UnloadShader(sh);
    // };
    var current_shader = PostProcessShader.bloom;
    // Create a RenderTexture2D to be used for render to texture
    var target = ray.LoadRenderTexture(screenWidth, screenHeight);
    defer ray.UnloadRenderTexture(target); // Unload render texture

    // Setup orbital camera
    ray.SetCameraMode(camera, ray.CAMERA_ORBITAL); // Set an orbital camera mode

    ray.SetTargetFPS(60); // Set our game to run at 60 frames-per-second
    //--------------------------------------------------------------------------------------

    // Main game loop
    while (!ray.WindowShouldClose()) {
        // Update
        //----------------------------------------------------------------------------------
        ray.UpdateCamera(&camera); // Update camera

        if (ray.IsKeyPressed(ray.KEY_RIGHT)) {
            current_shader = @intToEnum(PostProcessShader, (@enumToInt(current_shader) +% 1) % total_shader);
        } else if (ray.IsKeyPressed(ray.KEY_LEFT)) {
            current_shader = @intToEnum(PostProcessShader, (@enumToInt(current_shader) -% 1) % total_shader);
        }

        //----------------------------------------------------------------------------------

        // Draw
        //----------------------------------------------------------------------------------
        ray.BeginTextureMode(target); // Enable drawing to texture
        ray.ClearBackground(ray.RAYWHITE); // Clear texture background

        ray.BeginMode3D(camera); // Begin 3d mode drawing
        ray.DrawModel(model, position, 0.1, ray.WHITE); // Draw 3d model with texture
        ray.DrawGrid(10, 1); // Draw a grid
        ray.EndMode3D(); // End 3d mode drawing, returns to orthographic 2d mode
        ray.EndTextureMode(); // End drawing to texture (now we have a texture available
        // for next passes)

        ray.BeginDrawing();
        ray.ClearBackground(ray.RAYWHITE); // Clear screen background

        // Render generated texture using selected postprocessing shader
        ray.BeginShaderMode(shaders[@enumToInt(current_shader)]);
        // NOTE: Render texture must be y-flipped due to default OpenGL coordinates
        // (left-bottom)
        ray.DrawTextureRec(target.texture, ray.Rectangle{
            .x = 0,
            .y = 0,
            .width = @intToFloat(f32, target.texture.width),
            .height = @intToFloat(f32, -target.texture.height),
        }, ray.Vector2{ .x = 0, .y = 0 }, ray.WHITE);
        ray.EndShaderMode();

        // Draw 2d shapes and text over drawn texture
        ray.DrawRectangle(0, 9, 580, 30, ray.Fade(ray.LIGHTGRAY, 0.7));

        ray.DrawText("(c) Church 3D model by Alberto Cano", screenWidth - 200, screenHeight - 20, 10, ray.GRAY);
        ray.DrawText("CURRENT POSTPRO SHADER:", 10, 15, 20, ray.BLACK);
        ray.DrawText(std.meta.tagName(current_shader).ptr, 330, 15, 20, ray.RED);
        ray.DrawText("< >", 540, 10, 30, ray.DARKBLUE);
        ray.DrawFPS(700, 15);
        ray.EndDrawing();
    }
}
