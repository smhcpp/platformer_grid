const std = @import("std");
const print = std.debug.print;
const mach = @import("mach");
const T = @import("types.zig");
const gpu = mach.gpu;
const App = @This();

pub const Modules = mach.Modules(.{
    mach.Core,
    App,
});

pub const mach_module = .app;
pub const mach_systems = .{ .main, .init, .tick, .deinit };

pub const main = mach.schedule(.{
    .{ mach.Core, .init },
    .{ App, .init },
    .{ mach.Core, .main },
});

window: mach.ObjectID,
map_pipeline: *gpu.RenderPipeline,
player_pipeline: *gpu.RenderPipeline,
map_bind_group: *gpu.BindGroup,
player_bind_group: *gpu.BindGroup,
plats_buffer: *gpu.Buffer,
player_buffer: *gpu.Buffer,
globals_buffer: *gpu.Buffer,

player: T.Player,
globals: T.Globals,
map: *T.MapArea = undefined,

pub fn init(core: *mach.Core, app: *App, app_mod: mach.Mod(App)) !void {
    core.on_tick = app_mod.id.tick;
    core.on_exit = app_mod.id.deinit;

    const window = try core.windows.new(.{
        .title = "Some Platformer",
    });

    app.* = .{
        .window = window,
        .map_pipeline = undefined,
        .player_pipeline = undefined,
        .player = .{
            .shape = .{
                .pos = .{ 0.0, 0.0 },
                .size = .{ 0.1, 0.2 },
            },
            .velocity = .{ 0.0, 0.0 },
        },
        .globals = .{
            .aspect_ratio = 1.0,
        },
        .player_buffer = undefined,
        .plats_buffer = undefined,
        .globals_buffer = undefined,
        .map_bind_group = undefined,
        .player_bind_group = undefined,
    };
    try app.setup();
}

fn setup(app: *App) !void {
    app.map = try T.MapArea.init(std.heap.c_allocator);
}

fn setupBuffers(app: *App, window: anytype) *gpu.BindGroupLayout {
    app.player_buffer = window.device.createBuffer(&.{
        .label = "player uniform buffer",
        .usage = .{ .storage = true, .copy_dst = true },
        .size = @sizeOf(T.RectGPU),
        .mapped_at_creation = .false,
    });
    app.plats_buffer = window.device.createBuffer(&.{
        .label = "platforms uniform buffer",
        .usage = .{ .storage = true, .copy_dst = true },
        .size = @sizeOf(T.RectGPU) * app.map.plats.len,
        .mapped_at_creation = .false,
    });
    app.globals_buffer = window.device.createBuffer(&.{
        .label = "globals uniform buffer",
        .usage = .{ .uniform = true, .copy_dst = true },
        // .size = @sizeOf(T.Globals),
        .size =  256,
        .mapped_at_creation = .false,
    });

    const bind_group_layout = window.device.createBindGroupLayout(&gpu.BindGroupLayout.Descriptor.init(.{
        .label = "bind group layout",
        .entries = &.{
            .{
                .binding = 0,
                .visibility = .{ .vertex = true, .fragment = true },
                .buffer = .{
                    .type = .storage,
                    .has_dynamic_offset = .false,
                    .min_binding_size = @sizeOf(T.RectGPU),
                },
            },
            .{
                .binding = 1,
                .visibility = .{ .vertex = true, .fragment = true },
                .buffer = .{
                    .type = .uniform,
                    .has_dynamic_offset = .false,
                    .min_binding_size = @sizeOf(T.Globals),
                },
            },
        },
    }));
    // app.bind_group = window.device.createBindGroup(&gpu.BindGroup.Descriptor.init(.{
    //     .label = "Bind groups",
    //     .layout = bind_group_layout,
    //     .entries = &.{
    //         .{
    //             .binding = 0,
    //             .buffer = app.player_buffer,
    //             .offset = 0,
    //             .size = @sizeOf(T.RectGPU),
    //         },
    //         .{
    //             .binding = 1,
    //             .buffer = app.globals_buffer,
    //             .offset = 0,
    //             .size = @sizeOf(T.Globals),
    //         },
    //     },
    // }));
    app.player_bind_group = window.device.createBindGroup(&gpu.BindGroup.Descriptor.init(.{
        .layout = bind_group_layout,
        .entries = &.{
            .{ .binding = 0, .buffer = app.player_buffer, .offset = 0, .size = @sizeOf(T.RectGPU) },
            .{ .binding = 1, .buffer = app.globals_buffer, .offset = 0, .size = @sizeOf(T.Globals) },
        },
    }));

    // Group B: Platforms
    app.map_bind_group = window.device.createBindGroup(&gpu.BindGroup.Descriptor.init(.{
        .layout = bind_group_layout,
        .entries = &.{
            .{ .binding = 0, .buffer = app.plats_buffer, .offset = 0, .size = @sizeOf(T.RectGPU) * app.map.plats.len },
            .{ .binding = 1, .buffer = app.globals_buffer, .offset = 0, .size = @sizeOf(T.Globals) },
        },
    }));
    return bind_group_layout;
}

fn setupPipeline(core: *mach.Core, app: *App, window_id: mach.ObjectID) !void {
    var window = core.windows.getValue(window_id);
    defer core.windows.setValueRaw(window_id, window);
    var bind_group_layout = setupBuffers(app, &window);
    defer bind_group_layout.release();
    // ADD THIS BLOCK:
    const pipeline_layout = window.device.createPipelineLayout(&gpu.PipelineLayout.Descriptor.init(.{
        .label = "pipeline layout",
        .bind_group_layouts = &.{bind_group_layout},
    }));
    defer pipeline_layout.release();
    /////// the line above needs to be tested
    const shader_module = window.device.createShaderModuleWGSL("shader.wgsl", @embedFile("shader.wgsl"));
    defer shader_module.release();

    const blend = gpu.BlendState{};
    const color_target = gpu.ColorTargetState{
        .format = window.framebuffer_format,
        .blend = &blend,
    };

    // --- PIPELINE 1: MAP ---
    const frag_map = gpu.FragmentState.init(.{
        .module = shader_module,
        .entry_point = "frag_map",
        .targets = &.{color_target},
    });
    const map_desc = gpu.RenderPipeline.Descriptor{
        .fragment = &frag_map,
        .layout = pipeline_layout,
        .vertex = gpu.VertexState{
            .module = shader_module,
            .entry_point = "vertex_map",
        },
    };
    app.map_pipeline = window.device.createRenderPipeline(&map_desc);
    // --- PIPELINE 2: PLAYER ---
    const frag_player = gpu.FragmentState.init(.{
        .module = shader_module,
        .entry_point = "frag_player",
        .targets = &.{color_target},
    });
    const player_desc = gpu.RenderPipeline.Descriptor{
        .fragment = &frag_player,
        .layout = pipeline_layout,
        .vertex = gpu.VertexState{
            .module = shader_module,
            .entry_point = "vertex_player",
        },
    };
    app.player_pipeline = window.device.createRenderPipeline(&player_desc);
}

pub fn updateSystems(app: *App, core: *mach.Core) void {
    const window = core.windows.getValue(app.window);
    app.globals.aspect_ratio = @as(f32, @floatFromInt(window.width)) / @as(f32, @floatFromInt(window.height));
    app.player.shape.pos += app.player.velocity;
}

pub fn updateBuffers(app: *App, core: *mach.Core) void {
    const window = core.windows.getValue(app.window);
    const rgpu = T.RectGPU{
        .x = app.player.shape.pos[0],
        .y = app.player.shape.pos[1],
        .w = app.player.shape.size[0],
        .h = app.player.shape.size[1],
    };
    window.queue.writeBuffer(app.player_buffer, 0, &[_]T.RectGPU{rgpu});
    var platforms: []T.RectGPU = undefined;
    var count: usize = 0;
    for (app.map.plats) |plat| {
        platforms[count] = .{
            .x = plat.shape.pos[0],
            .y = plat.shape.pos[1],
            .w = plat.shape.size[0],
            .h = plat.shape.size[1],
        };
        count += 1;
    }
    window.queue.writeBuffer(app.plats_buffer, 0, platforms[0..count]);
    window.queue.writeBuffer(app.globals_buffer, 0, &[_]T.Globals{app.globals});
}

pub fn handleEvents(app: *App, core: *mach.Core) void {
    const dl: f32 = 0.02;
    while (core.nextEvent()) |event| {
        switch (event) {
            .window_open => |ev| {
                try setupPipeline(core, app, ev.window_id);
            },
            .close => core.exit(),
            .key_press => |ev| {
                if (ev.key == .right) {
                    app.player.velocity[0] = dl;
                } else if (ev.key == .left) {
                    app.player.velocity[0] = -dl;
                } else if (ev.key == .up) {
                    app.player.velocity[1] = dl;
                } else if (ev.key == .down) {
                    app.player.velocity[1] = -dl;
                }
            },
            .key_release => |ev| {
                if (ev.key == .right) {
                    app.player.velocity[0] = 0.0;
                } else if (ev.key == .left) {
                    app.player.velocity[0] = 0.0;
                } else if (ev.key == .up) {
                    app.player.velocity[1] = 0.0;
                } else if (ev.key == .down) {
                    app.player.velocity[1] = 0.0;
                }
            },
            else => {},
        }
    }
}

pub fn tick(app: *App, core: *mach.Core) void {
    handleEvents(app, core);
    app.updateSystems(core);
    app.updateBuffers(core);

    const window = core.windows.getValue(app.window);
    const back_buffer_view = window.swap_chain.getCurrentTextureView().?;
    defer back_buffer_view.release();

    const encoder = window.device.createCommandEncoder(&.{});
    defer encoder.release();

    const color_attachment = gpu.RenderPassColorAttachment{
        .view = back_buffer_view,
        .clear_value = gpu.Color{ .r = 0.1, .g = 0.1, .b = 0.1, .a = 1.0 },
        .load_op = .clear,
        .store_op = .store,
    };

    const render_pass = encoder.beginRenderPass(&gpu.RenderPassDescriptor.init(.{
        .color_attachments = &.{color_attachment},
    }));
    defer render_pass.release();

    // Draw Platforms
    render_pass.setPipeline(app.map_pipeline);
    render_pass.setBindGroup(0, app.map_bind_group, &.{});
    render_pass.draw(6, @intCast(app.map.plats.len), 0, 0);

    // Draw Player
    render_pass.setPipeline(app.player_pipeline);
    render_pass.setBindGroup(0, app.player_bind_group, &.{});
    render_pass.draw(6, 1, 0, 0);

    render_pass.end();

    var command = encoder.finish(&.{});
    defer command.release();
    window.queue.submit(&[_]*gpu.CommandBuffer{command});
}

pub fn deinit(app: *App) void {
    app.map_pipeline.release();
    app.player_pipeline.release();

    app.map_bind_group.release();
    app.player_bind_group.release();

    app.plats_buffer.release();
    app.player_buffer.release();
    app.globals_buffer.release();

    app.map.deinit(std.heap.c_allocator);
}
