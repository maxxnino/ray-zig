const std = @import("std");
const ray = @import("translate-c/raylib.zig");
const zz = @import("zig-zag");
const BroadPhase = zz.BroadPhase;
const basic_type = zz.basic_type;
const Vec2 = basic_type.Vec2;
const Rect = basic_type.Rect;
const Index = basic_type.Index;
const Proxy = BroadPhase.Proxy;
const QueryCallback = BroadPhase.QueryCallback;

fn randomPos(random: std.rand.Random, min: f32, max: f32) Vec2 {
    return Vec2.new(
        std.math.max(random.float(f32) * max, min),
        std.math.max(random.float(f32) * max, min),
    );
}

fn randomVel(random: std.rand.Random, value: f32) Vec2 {
    return Vec2.new(
        (random.float(f32) - 0.5) * value * 2,
        (random.float(f32) - 0.5) * value * 2,
    );
}
fn randomPosTo(random: std.rand.Random, m_pos: Vec2, h_size: Vec2) Vec2 {
    return m_pos.add(.{ .data = h_size.scale(2).data * @Vector(2, f32){
        random.float(f32) - 0.5,
        random.float(f32) - 0.5,
    } });
}

pub const ScreenQueryCallback = struct {
    stack: std.ArrayList(Index),
    entities: std.ArrayList(Index),
    pub fn init(allocator: std.mem.Allocator) ScreenQueryCallback {
        return .{
            .stack = std.ArrayList(Index).init(allocator),
            .entities = std.ArrayList(Index).init(allocator),
        };
    }

    pub fn deinit(q: *ScreenQueryCallback) void {
        q.stack.deinit();
        q.entities.deinit();
    }

    pub fn onOverlap(self: *ScreenQueryCallback, payload: void, entity: u32) void {
        _ = payload;
        self.entities.append(entity) catch unreachable;
    }

    pub fn reset(q: *ScreenQueryCallback) void {
        q.entities.clearRetainingCapacity();
    }
};

pub fn drawText(
    stack: *std.ArrayList(u8),
    writer: anytype,
    comptime fmt: []const u8,
    args: anytype,
    x: i32,
    y: i32,
    font_size: i32,
    color: anytype,
) !void {
    try std.fmt.format(writer, fmt, args);
    try stack.append(0);
    ray.DrawText(@ptrCast([*c]const u8, stack.items), x, y, font_size, color);
    stack.clearRetainingCapacity();
}

const Tag = enum {
    collied,
    none,
};
pub fn main() !void {
    // Initialization
    //--------------------------------------------------------------------------------------
    const pixel: f32 = 20;
    const screenWidth = 1200;
    const screenHeight = 675;
    var m_screen = Vec2.new(20, 20);
    const h_screen_size = Vec2.new(screenWidth / (2 * pixel), screenHeight / (2 * pixel));
    ray.InitWindow(screenWidth, screenHeight, "Physic zig zag");

    defer ray.CloseWindow();
    ray.SetTargetFPS(60);
    const allocator = std.heap.c_allocator;

    var bp = BroadPhase.init(allocator);
    defer bp.deinit();

    var stack = std.ArrayList(u8).init(allocator);
    defer stack.deinit();
    var writer = stack.writer();

    var random = std.rand.Xoshiro256.init(0).random();
    const Entity = std.MultiArrayList(struct {
        entity: u32,
        pos: Vec2,
        half_size: Vec2,
        proxy: Proxy = undefined,
        vel: Vec2,
        refresh_vel: f32,
        tag: Tag = .none,
    });

    var manager = Entity{};
    defer manager.deinit(allocator);
    var total_small: u32 = 50000;
    var total_big: u32 = 1000;
    const max_x: f32 = 5000;
    const min_size: f32 = BroadPhase.half_element_size.x() * 2;
    const max_size: f32 = 10;
    try manager.setCapacity(allocator, total_big + total_small);
    const small_size = BroadPhase.half_element_size.scale(0.99);
    // Init entities
    {
        var entity: u32 = 0;
        while (entity < total_small) : (entity += 1) {
            try manager.append(allocator, .{
                .entity = entity,
                .pos = randomPos(random, -max_x, max_x),
                .half_size = small_size,
                .vel = randomVel(random, 15),
                .refresh_vel = random.float(f32) * 10,
            });
        }
        while (entity < total_small + total_big) : (entity += 1) {
            try manager.append(allocator, .{
                .entity = entity,
                .pos = randomPos(random, -max_x, max_x),
                .half_size = randomPos(random, min_size, max_size),
                .vel = randomVel(random, 15),
                .refresh_vel = random.float(f32) * 10,
            });
        }
    }

    var slice = manager.slice();
    var entities = slice.items(.entity);
    var position = slice.items(.pos);
    var proxy = slice.items(.proxy);
    var h_size = slice.items(.half_size);
    var refresh_vel = slice.items(.refresh_vel);
    var vel = slice.items(.vel);
    var tag = slice.items(.tag);
    {
        var timer = try std.time.Timer.start();

        var index: u32 = 0;
        while (index < total_small) : (index += 1) {
            const p = bp.createProxy(position[index], h_size[index], entities[index]);
            std.debug.assert(p == .small);
            proxy[index] = p;
        }
        var time_0 = timer.read();
        std.debug.print("add {} entity to grid take {}ms\n", .{ total_small, time_0 / std.time.ns_per_ms });

        timer = try std.time.Timer.start();
        while (index < slice.len) : (index += 1) {
            const p = bp.createProxy(position[index], h_size[index], entities[index]);
            std.debug.assert(p == .big);
            proxy[index] = p;
        }
        time_0 = timer.read();
        std.debug.print("add {} entity to tree take {}ms\n", .{ total_big, time_0 / std.time.ns_per_ms });
    }

    var callback = QueryCallback.init(allocator);
    defer callback.deinit();

    var screen_callback = ScreenQueryCallback.init(allocator);
    defer screen_callback.deinit();

    var update = true;
    // Main game loop

    var update_timer = try std.time.Timer.start();
    while (!ray.WindowShouldClose()) {
        const dt = @intToFloat(f32, update_timer.lap() / std.time.us_per_s) / 1000;
        if (ray.IsKeyDown(ray.KEY_H)) {
            m_screen.data[0] -= dt * 50.0;
        }
        if (ray.IsKeyDown(ray.KEY_L)) {
            m_screen.data[0] += dt * 50.0;
        }
        if (ray.IsKeyDown(ray.KEY_K)) {
            m_screen.data[1] += dt * 50.0;
        }
        if (ray.IsKeyDown(ray.KEY_J)) {
            m_screen.data[1] -= dt * 50.0;
        }
        if (ray.IsKeyPressed(ray.KEY_F)) {
            var index: u32 = 0;
            var entity = @intCast(u32, slice.len);

            while (index < 50) : (index += 1) {
                const pos = randomPosTo(random, m_screen, h_screen_size);
                try manager.append(allocator, .{
                    .entity = entity,
                    .pos = pos,
                    .half_size = small_size,
                    .proxy = bp.createProxy(pos, BroadPhase.half_element_size, entity),
                    .vel = randomVel(random, 15),
                    .refresh_vel = random.float(f32) * 10,
                });
                entity += 1;
            }
            index = 0;
            while (index < 5) : (index += 1) {
                const pos = randomPosTo(random, m_screen, h_screen_size);
                const half_size = randomPos(random, min_size, max_size);
                try manager.append(allocator, .{
                    .entity = entity,
                    .pos = pos,
                    .half_size = half_size,
                    .proxy = bp.createProxy(pos, half_size, entity),
                    .vel = randomVel(random, 15),
                    .refresh_vel = random.float(f32) * 10,
                });
                entity += 1;
            }
            total_big += 5;
            total_small += 50;
            slice = manager.slice();
            entities = slice.items(.entity);
            position = slice.items(.pos);
            proxy = slice.items(.proxy);
            refresh_vel = slice.items(.refresh_vel);
            vel = slice.items(.vel);
            h_size = slice.items(.half_size);
            tag = slice.items(.tag);
        }
        if (ray.IsKeyPressed(ray.KEY_SPACE)) {
            update = !update;
        }

        //clear tag
        for (tag) |*t| {
            t.* = .none;
        }
        //timer
        for (refresh_vel) |*t, i| {
            t.* -= dt;
            if (t.* <= 0) {
                t.* = random.float(f32) * 10;
                vel[i] = randomVel(random, 15);
            }
        }
        //Move
        var move_timer = try std.time.Timer.start();
        if (update) {
            for (position) |*pos, i| {
                const new_pos = pos.add(vel[i].scale(dt));
                bp.moveProxy(proxy[i], pos.*, new_pos, h_size[i]);
                pos.* = new_pos;
            }
        }
        const moved_time = move_timer.read();

        // query
        var index: u32 = 0;
        var timer = try std.time.Timer.start();
        defer callback.reset();
        while (index < slice.len) : (index += 1) {
            try bp.query(position[index], h_size[index], proxy[index], entities[index], &callback);
        }
        const time_0 = timer.read();
        for (callback.pairs.items) |e| {
            tag[e] = .collied;
        }

        defer screen_callback.reset();
        try bp.userQuery(m_screen, h_screen_size, {}, &screen_callback);

        ray.BeginDrawing();
        defer ray.EndDrawing();
        ray.ClearBackground(ray.BLACK);

        const screen_rect = Rect.toScreenSpace(m_screen, h_screen_size, m_screen, h_screen_size, pixel);
        ray.DrawRectangle(
            screen_rect.lower_bound.x(),
            screen_rect.lower_bound.y(),
            screen_rect.upper_bound.x(),
            screen_rect.upper_bound.y(),
            ray.DARKGRAY,
        );
        for (screen_callback.entities.items) |entity| {
            const pos = Rect.posToScreenSpace(
                position[entity].sub(BroadPhase.half_element_size),
                m_screen,
                h_screen_size,
                pixel,
            );
            const aabb = Rect.toScreenSpace(
                position[entity],
                h_size[entity],
                m_screen,
                h_screen_size,
                pixel,
            );
            const color = if (tag[entity] == .collied) ray.SKYBLUE else ray.BLUE;
            ray.DrawRectangle(
                aabb.lower_bound.x(),
                aabb.lower_bound.y(),
                aabb.upper_bound.x(),
                aabb.upper_bound.y(),
                color,
            );
            try drawText(&stack, writer, "{d:.2}/{d:.2}", .{
                position[entity].x(),
                position[entity].y(),
            }, pos.x(), pos.y(), 20, ray.GOLD);
        }
        try drawText(&stack, writer, "Total Grids: {}", .{bp.grid_map.count()}, 20, 20, 19, ray.BEIGE);
        try drawText(&stack, writer, "Move big: {} and small: {}. Take {}ms\n", .{
            total_big,
            total_small,
            moved_time / std.time.ns_per_ms,
        }, 20, 40, 19, ray.BEIGE);
        try drawText(&stack, writer, "Query big: {} and small: {}. Take {}ms with {} pairs\n", .{
            total_big,
            total_small,
            time_0 / std.time.ns_per_ms,
            callback.total,
        }, 20, 60, 19, ray.BEIGE);
        try drawText(&stack, writer, "Objects on screen {}\n", .{screen_callback.entities.items.len}, 20, 80, 19, ray.BEIGE);
        // try drawText(&stack, writer, "Pairs overlap on screen {}\n", .{red_callback.pairs.items.len}, 20, 100, 19, ray.BEIGE);
    }
}
