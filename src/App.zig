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
    aspect_ratio: f32,
};
pub const Rect = packed struct {
    x:f32,
    y:f32,
    w:f32,
    h:f32,
    // pos: Vec2,
    // size: Vec2,
};
pub const Player = struct {
    shape: Rect,
    velocity: Vec2,
};
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
pipeline: *gpu.RenderPipeline,
bind_group: *gpu.BindGroup,
player: Player,
globals: Globals,
player_buffer: *gpu.Buffer,
globals_buffer: *gpu.Buffer,

pub fn init(core: *mach.Core, app: *App, app_mod: mach.Mod(App)) !void {
    core.on_tick = app_mod.id.tick;
    core.on_exit = app_mod.id.deinit;

    const window = try core.windows.new(.{
        .title = "Some Platformer",
    });

    app.* = .{
        .window = window,
        .pipeline = undefined,
        // new stuff added:
        .player = .{
            .shape = .{
                .x = 0.0,
                .y = 0.0,
                .w = 0.1,
                .h = 0.2,
            },
            .velocity = .{ 0.0, 0.0 },
        },
        .globals=.{
            .aspect_ratio=1.0,
        },
        .player_buffer = undefined,
        .globals_buffer = undefined,
        .bind_group = undefined,
    };
}

fn setupPipeline(core: *mach.Core, app: *App, window_id: mach.ObjectID) !void {
    var window = core.windows.getValue(window_id);
    defer core.windows.setValueRaw(window_id, window);
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

    const fragment = gpu.FragmentState.init(.{
        .module = shader_module,
        .entry_point = "frag_main",
        .targets = &.{color_target},
    });

    const pipeline_descriptor = gpu.RenderPipeline.Descriptor{
        .fragment = &fragment,
        .layout = pipeline_layout,  // ADD THIS LINE!
        .vertex = gpu.VertexState{
            .module = shader_module,
            .entry_point = "vertex_main",
        },
    };
    app.pipeline = window.device.createRenderPipeline(&pipeline_descriptor);
}

pub fn tick(app: *App, core: *mach.Core) void {
    while (core.nextEvent()) |event| {
        switch (event) {
            .window_open => |ev| {
                try setupPipeline(core, app, ev.window_id);
            },
            .close => core.exit(),
            else => {},
        }
    }

    const window = core.windows.getValue(app.window);
    app.globals.aspect_ratio = @as(f32, @floatFromInt(window.width)) / @as(f32, @floatFromInt(window.height));
    window.queue.writeBuffer(app.player_buffer, 0, &[_]Rect{app.player.shape});
    window.queue.writeBuffer(app.globals_buffer, 0, &[_]Globals{app.globals});
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

    render_pass.setPipeline(app.pipeline);
    render_pass.setBindGroup(0, app.bind_group, &.{});
    render_pass.draw(6, 1, 0, 0);
    render_pass.end();

    var command = encoder.finish(&.{});
    defer command.release();
    window.queue.submit(&[_]*gpu.CommandBuffer{command});
}

pub fn deinit(app: *App) void {
    app.pipeline.release();
}
