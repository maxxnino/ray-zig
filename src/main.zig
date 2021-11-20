const std = @import("std");
const ray = @import("translate-c/raylib.zig");
const BroadPhase = @import("physic/BroadPhase.zig");
const basic_type = @import("physic/basic_type.zig");
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
    return Vec2.new(
        (random.float(f32) - 0.5) * h_size.x * 2 + m_pos.x,
        (random.float(f32) - 0.5) * h_size.y * 2 + m_pos.y,
    );
}

pub const ScreenQueryCallback = struct {
    stack: std.ArrayList(Index),
    entities: std.ArrayList(Index),
    pub fn init(allocator: *std.mem.Allocator) ScreenQueryCallback {
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
pub const RedCallback = struct {
    const Pair = struct { left: Index, right: Index };
    stack: std.ArrayList(Index),
    pairs: std.ArrayList(Pair),
    map: std.AutoHashMap(u32, void),
    pub fn init(allocator: *std.mem.Allocator) RedCallback {
        return .{
            .stack = std.ArrayList(Index).init(allocator),
            .pairs = std.ArrayList(Pair).init(allocator),
            .map = std.AutoHashMap(u32, void).init(allocator),
        };
    }

    pub fn deinit(q: *RedCallback) void {
        q.stack.deinit();
        q.pairs.deinit();
        q.map.deinit();
    }

    pub fn onOverlap(self: *RedCallback, left: u32, right: u32) void {
        if (left == right) return;
        const l = if(left < right) left else right;
        const r = if(l == left) right else left;
        const key = l << 16 | r;
        if (self.map.contains(key)) return;
        self.map.putNoClobber(key, {}) catch unreachable;
        self.pairs.append(.{ .left = l, .right = r }) catch unreachable;
    }

    pub fn reset(q: *RedCallback) void {
        q.pairs.clearRetainingCapacity();
        q.map.clearRetainingCapacity();
    }
};
pub fn main() !void {
    // Initialization
    //--------------------------------------------------------------------------------------
    const pixel = 20;
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
    });

    var manager = Entity{};
    defer manager.deinit(allocator);
    var total_small: u32 = 5000;
    var total_big: u32 = 100;
    const max_x: f32 = 1000;
    const min_size: f32 = 5;
    const max_size: f32 = 10;
    // bp.preCreateGrid(Vec2.zero(), Vec2.new(max_x, max_x));
    try manager.setCapacity(allocator, total_big + total_small);
    // Init entities
    {
        var entity: u32 = 0;
        while (entity < total_small) : (entity += 1) {
            try manager.append(allocator, .{
                .entity = entity,
                .pos = randomPos(random, 0, max_x),
                .half_size = BroadPhase.half_element_size,
                .vel = randomVel(random, 15),
                .refresh_vel = random.float(f32) * 10,
            });
        }
        while (entity < total_small + total_big) : (entity += 1) {
            try manager.append(allocator, .{
                .entity = entity,
                .pos = randomPos(random, 0, max_x),
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

    var red_callback = RedCallback.init(allocator);
    defer red_callback.deinit();
    var update = true;
    // Main game loop
    while (!ray.WindowShouldClose()) {
        if (ray.IsKeyDown(ray.KEY_H)) {
            m_screen.x -= 0.016 * 50.0;
        }
        if (ray.IsKeyDown(ray.KEY_L)) {
            m_screen.x += 0.016 * 50.0;
        }
        if (ray.IsKeyDown(ray.KEY_K)) {
            m_screen.y += 0.016 * 50.0;
        }
        if (ray.IsKeyDown(ray.KEY_J)) {
            m_screen.y -= 0.016 * 50.0;
        }
        if (ray.IsKeyPressed(ray.KEY_F)) {
            var index: u32 = 0;
            var entity = @intCast(u32, slice.len);

            while (index < 10) : (index += 1) {
                const pos = randomPosTo(random, m_screen, h_screen_size);
                try manager.append(allocator, .{
                    .entity = entity,
                    .pos = pos,
                    .half_size = BroadPhase.half_element_size,
                    .proxy = bp.createProxy(pos, BroadPhase.half_element_size, entity),
                    .vel = randomVel(random, 15),
                    .refresh_vel = random.float(f32) * 10,
                });
                entity += 1;
            }
            index = 0;
            while (index < 2) : (index += 1) {
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
            total_big += 2;
            total_small += 10;
            slice = manager.slice();
            entities = slice.items(.entity);
            position = slice.items(.pos);
            proxy = slice.items(.proxy);
            refresh_vel = slice.items(.refresh_vel);
            vel = slice.items(.vel);
            h_size = slice.items(.half_size);
        }
        if (ray.IsKeyPressed(ray.KEY_SPACE)) {
            update = !update;
        }
        //timer
        for (refresh_vel) |*t, i| {
            t.* -= 0.016;
            if (t.* <= 0) {
                t.* = random.float(f32) * 10;
                vel[i] = randomVel(random, 15);
            }
        }
        //Move
        var move_timer = try std.time.Timer.start();
        if (update) {
            for (position) |*pos, i| {
                const new_pos = pos.add(vel[i].scale(0.016));
                bp.moveProxy(proxy[i], pos.*, new_pos, h_size[i]);
                pos.* = new_pos;
            }
        }
        const moved_time = move_timer.read();

        // query
        var index: u32 = 0;
        var timer = try std.time.Timer.start();
        defer callback.total = 0;
        while (index < slice.len) : (index += 1) {
            try bp.query(position[index], h_size[index], proxy[index], entities[index], &callback);
        }
        const time_0 = timer.read();

        defer screen_callback.reset();
        defer red_callback.reset();
        try bp.userQuery(m_screen, h_screen_size, {}, &screen_callback);
        for (screen_callback.entities.items) |entity| {
            try bp.query(position[entity], h_size[entity], proxy[entity], entities[entity], &red_callback);
        }


        ray.BeginDrawing();
        defer ray.EndDrawing();
        ray.ClearBackground(ray.BLACK);

        for (red_callback.pairs.items) |p| {
            const aabb_left = Rect.newRectInt(
                position[p.left],
                h_size[p.left],
                m_screen,
                h_screen_size,
            );
            ray.DrawRectangle(
                aabb_left.lower_bound.x * pixel,
                aabb_left.lower_bound.y * pixel,
                aabb_left.upper_bound.x * pixel,
                aabb_left.upper_bound.y * pixel,
                ray.SKYBLUE,
            );
            const aabb_right = Rect.newRectInt(
                position[p.right],
                h_size[p.right],
                m_screen,
                h_screen_size,
            );
            ray.DrawRectangle(
                aabb_right.lower_bound.x * pixel,
                aabb_right.lower_bound.y * pixel,
                aabb_right.upper_bound.x * pixel,
                aabb_right.upper_bound.y * pixel,
                ray.SKYBLUE,
            );
        }

        for (screen_callback.entities.items) |entity| {
            const is_draw = blk: {
                for (red_callback.pairs.items) |p| {
                    if (entity == p.left or entity == p.right) {
                        break :blk false;
                    }
                } else {
                    break :blk true;
                }

                break :blk true;
            };
            if (is_draw) {
                const aabb = Rect.newRectInt(
                    position[entity],
                    h_size[entity],
                    m_screen,
                    h_screen_size,
                );
                ray.DrawRectangle(
                    aabb.lower_bound.x * pixel,
                    aabb.lower_bound.y * pixel,
                    aabb.upper_bound.x * pixel,
                    aabb.upper_bound.y * pixel,
                    ray.RED,
                );
            }
        }
        try std.fmt.format(writer, "Total Grids: {}", .{bp.grid_map.count()});
        try stack.append(0);
        ray.DrawText(@ptrCast([*c]const u8, stack.items), 20, 20, 20, ray.BEIGE);
        stack.clearRetainingCapacity();

        try std.fmt.format(
            writer,
            "Move big: {} and small: {}. Take {}ms\n",
            .{ total_big, total_small, moved_time / std.time.ns_per_ms },
        );
        try stack.append(0);
        ray.DrawText(@ptrCast([*c]const u8, stack.items), 20, 42, 20, ray.BEIGE);
        stack.clearRetainingCapacity();

        try std.fmt.format(
            writer,
            "Query big: {} and small: {}. Take {}ms with {} pairs\n",
            .{ total_big, total_small, time_0 / std.time.ns_per_ms, callback.total },
        );
        try stack.append(0);
        ray.DrawText(@ptrCast([*c]const u8, stack.items), 20, 64, 20, ray.BEIGE);
        stack.clearRetainingCapacity();

        try std.fmt.format(writer, "Objects on screen {}\n", .{screen_callback.entities.items.len});
        try stack.append(0);
        ray.DrawText(@ptrCast([*c]const u8, stack.items), 20, 86, 20, ray.BEIGE);
        stack.clearRetainingCapacity();

        defer screen_callback.reset();
        try std.fmt.format(writer, "Pairs overlap on screen {}\n", .{red_callback.pairs.items.len});
        try stack.append(0);
        ray.DrawText(@ptrCast([*c]const u8, stack.items), 20, 108, 20, ray.BEIGE);
        stack.clearRetainingCapacity();
    }
}
