const std = @import("std");
const mach = @import("mach");
const gpu = mach.gpu;
pub fn F32U(value: u32) f32 {
    return @floatFromInt(value);
}
pub fn U32F(value: f32) u32 {
    return @intFromFloat(value);
}
pub const Vec2 = @Vector(2, f32);
pub const Globals = struct {
    aspect: f32,
};
pub const Rect = struct {
    pos: Vec2,
    size: Vec2,
};
pub const Player = struct {
    shape: Rect,
    velocity: Vec2,
};
const App = @This();
// mach stuff:
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
title_timer: mach.time.Timer,
pipeline: *gpu.RenderPipeline,

//----------------------------------
// Here We define all fields in app:
bind_group: *gpu.BindGroup,
//player buffer(for now)
player: Player,
player_buffer: *gpu.Buffer,
// Globals:
globals: Globals,
globals_buffer: *gpu.Buffer,
//----------------------------------

pub fn init(core: *mach.Core, app: *App, app_mod: mach.Mod(App)) !void {
    core.on_tick = app_mod.id.tick;
    core.on_exit = app_mod.id.deinit;
    const window = try core.windows.new(.{
        .title = "testing mach!",
    });
    app.* = .{
        .window = window,
        .title_timer = try mach.time.Timer.start(),
        .player = .{
            .shape = .{
                .pos = .{ 0.0, 0.0 },
                .size = .{ 0.1, 0.05 },
            },
            .velocity = .{ 0.0, 0.0 },
        },
        .globals = .{
            .aspect = 1.0,
        },
        .player_buffer = undefined,
        .bind_group = undefined,
        .globals_buffer = undefined,
        .pipeline = undefined,
    };
}

fn setupPipeline(core: *mach.Core, app: *App, window_id: mach.ObjectID) !void {
    var window = core.windows.getValue(window_id);
    defer core.windows.setValueRaw(window_id, window);
    app.globals.aspect = F32U(window.width) / F32U(window.height);

    // Create uniform buffer for player data
    app.player_buffer = window.device.createBuffer(&.{
        .label = "player uniform buffer",
        .usage = .{ .uniform = true, .copy_dst = true },
        .size = @sizeOf(Rect),
        .mapped_at_creation = .false,
    });
    app.globals_buffer = window.device.createBuffer(&.{
        .label = "globals uniform buffer",
        .usage = .{ .uniform = true, .copy_dst = true },
        .size = @sizeOf(Globals),
        .mapped_at_creation = .false,
    });
    // wgpu stuff:
    const shader_module = window.device.createShaderModuleWGSL("shader.wgsl", @embedFile("shader.wgsl"));
    defer shader_module.release();

    // Create bind group layout
    const bind_group_layout = window.device.createBindGroupLayout(&gpu.BindGroupLayout.Descriptor.init(.{
        .label = "bind group layout",
        .entries = &.{
            .{
                .binding = 0,
                .visibility = .{ .vertex = true, .fragment = true },
                .buffer = .{
                    .type = .uniform,
                    .has_dynamic_offset = .false,
                    .min_binding_size = @sizeOf(Rect),
                },
            },
            .{
                .binding = 1,
                .visibility = .{ .vertex = true, .fragment = true },
                .buffer = .{
                    .type = .uniform,
                    .has_dynamic_offset = .false,
                    .min_binding_size = @sizeOf(Globals),
                },
            },
        },
    }));
    defer bind_group_layout.release();
    app.bind_group = window.device.createBindGroup(&gpu.BindGroup.Descriptor.init(.{
        .label = "Bind groups",
        .layout = bind_group_layout,
        .entries = &.{
            .{
                .binding = 0,
                .buffer = app.player_buffer,
                .offset = 0,
                .size = @sizeOf(Rect),
            },
            .{
                .binding = 1,
                .buffer = app.globals_buffer,
                .offset = 0,
                .size = @sizeOf(Globals),
            },
        },
    }));

    // blending: final color = (src_color * src_factor) + (dst_color * dst_factor)
    // src_factor is the new color we pass in
    // dst_factor is the color already in the buffer
    // final alpha = (src_alpha * src_factor) + (dst_alpha * dst_factor)
    const blend = gpu.BlendState{
        .color = .{
            .src_factor = .src_alpha,
            .dst_factor = .one_minus_src_alpha,
            .operation = .add,
        },
        .alpha = .{
            .src_factor = .one,
            .dst_factor = .zero,
            .operation = .add,
        },
    };
    const color_target = gpu.ColorTargetState{
        .format = window.framebuffer_format,
        .blend = &blend,
    };
    // targets= &.{location(0),location(1),...}
    const fragment = gpu.FragmentState.init(.{
        .module = shader_module,
        .entry_point = "getFragmentColor",
        .targets = &.{color_target},
    });
    const label = @tagName(mach_module) ++ ".init";
    const pipeline_descriptor = gpu.RenderPipeline.Descriptor{
        .label = label,
        .fragment = &fragment,
        // .layout = pipeline_layout,
        .vertex = gpu.VertexState{
            .module = shader_module,
            .entry_point = "getVertexLocation",
        },
    };
    app.pipeline = window.device.createRenderPipeline(&pipeline_descriptor);
}

// TODO(object): window-title
// try updateWindowTitle(core);

pub fn tick(app: *App, core: *mach.Core) void {
    while (core.nextEvent()) |event| {
        switch (event) {
            .window_open => |ev| {
                try setupPipeline(core, app, ev.window_id);
            },
            .close => core.exit(),
            .key_press => |ev| {
                const speed = 0.012;
                if (ev.key == .left) app.player.velocity[0] = -speed;
                if (ev.key == .right) app.player.velocity[0] = speed;
                if (ev.key == .up) app.player.velocity[1] = speed;
                if (ev.key == .down) app.player.velocity[1] = -speed;
            },
            .key_release => |ev| {
                if (ev.key == .left and app.player.velocity[0] < 0.0) app.player.velocity[0] = 0.0;
                if (ev.key == .right and app.player.velocity[0] > 0.0) app.player.velocity[0] = 0.0;
                if (ev.key == .up and app.player.velocity[1] > 0.0) app.player.velocity[1] = 0.0;
                if (ev.key == .down and app.player.velocity[1] < 0.0) app.player.velocity[1] = 0.0;
            },
            // .key_repeat => |ev| {
            // },
            else => {},
        }
    }
    app.player.shape.pos += app.player.velocity;

    const window = core.windows.getValue(app.window);

    //write everything into buffer so that gpu can read it
    window.queue.writeBuffer(app.player_buffer, 0, &[_]Rect{app.player.shape});
    window.queue.writeBuffer(app.globals_buffer, 0, &[_]Globals{app.globals});

    const back_buffer_view = window.swap_chain.getCurrentTextureView().?;
    defer back_buffer_view.release();
    const label = @tagName(mach_module) ++ ".tick";
    const encoder = window.device.createCommandEncoder(&.{ .label = label });
    defer encoder.release();
    const bgcolor = gpu.Color{ .r = 0, .g = 0, .b = 0, .a = 1 };
    const color_attachments = [_]gpu.RenderPassColorAttachment{.{
        .view = back_buffer_view,
        .clear_value = bgcolor,
        .load_op = .clear,
        .store_op = .store,
    }};
    const render_pass = encoder.beginRenderPass(&gpu.RenderPassDescriptor.init(.{
        .label = label,
        .color_attachments = &color_attachments,
    }));
    defer render_pass.release();
    render_pass.setPipeline(app.pipeline);

    // draw(vertex_count, instance_count, starting_vertex, starting_instance)
    // instance_count: how many times the drawing process should be repeated
    // render_pass.draw(3, 1, 0, 0);
    // Draw 6 vertices (2 triangles forming a quad)
    render_pass.setBindGroup(0, app.bind_group, &.{});
    render_pass.draw(6, 1, 0, 0);

    render_pass.end();
    var command = encoder.finish(&.{ .label = label });
    defer command.release();
    window.queue.submit(&[_]*gpu.CommandBuffer{command});
}

pub fn deinit(app: *App) void {
    app.pipeline.release();
    app.player_buffer.release();
    app.globals_buffer.release();
    app.bind_group.release();
}
