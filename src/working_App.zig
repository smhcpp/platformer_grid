const std = @import("std");
const mach = @import("mach");
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
pipeline: *gpu.RenderPipeline,

pub fn init(core: *mach.Core, app: *App, app_mod: mach.Mod(App)) !void {
    core.on_tick = app_mod.id.tick;
    core.on_exit = app_mod.id.deinit;

    const window = try core.windows.new(.{
        .title = "Simple Triangle",
    });

    app.* = .{
        .window = window,
        .pipeline = undefined,
    };
}

fn setupPipeline(core: *mach.Core, app: *App, window_id: mach.ObjectID) !void {
    var window = core.windows.getValue(window_id);
    defer core.windows.setValueRaw(window_id, window);

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
        .vertex = gpu.VertexState{
            .module = shader_module,
            .entry_point = "vertex_main",
        },
    };

    app.pipeline = window.device.createRenderPipeline(&pipeline_descriptor);
    std.debug.print("Triangle pipeline created!\n", .{});
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
    render_pass.draw(3, 1, 0, 0);
    render_pass.end();

    var command = encoder.finish(&.{});
    defer command.release();
    window.queue.submit(&[_]*gpu.CommandBuffer{command});
}

pub fn deinit(app: *App) void {
    app.pipeline.release();
}
