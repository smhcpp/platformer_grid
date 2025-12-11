const std = @import("std");
const mach = @import("mach");
const gpu = mach.gpu;
pub const Vec2 = @Vector(2, f32);
pub const Player = struct{
    pos:Vec2,
    radius:f32,
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
pub fn init(core: *mach.Core, app: *App, app_mod: mach.Mod(App)) !void {
    core.on_tick = app_mod.id.tick;
    core.on_exit = app_mod.id.deinit;
    const window = try core.windows.new(.{
        .title = "testing mach!",
    });
    app.* = .{
        .window = window,
        .title_timer = try mach.time.Timer.start(),
        .pipeline = undefined,
    };
}

fn setupPipeline(core: *mach.Core, app: *App, window_id: mach.ObjectID) !void {
    var window = core.windows.getValue(window_id);
    defer core.windows.setValueRaw(window_id, window);

    // wgpu stuff:
    const shader_module = window.device.createShaderModuleWGSL("shader.wgsl", @embedFile("shader.wgsl"));
    defer shader_module.release();
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
            else => {},
        }
    }

    const window = core.windows.getValue(app.window);

    // Grab the back buffer of the swapchain
    // TODO(Core)
    const back_buffer_view = window.swap_chain.getCurrentTextureView().?;
    defer back_buffer_view.release();

    // Create a command encoder
    const label = @tagName(mach_module) ++ ".tick";

    const encoder = window.device.createCommandEncoder(&.{ .label = label });
    defer encoder.release();

    // Begin render pass
    const sky_blue_background = gpu.Color{ .r = 0.776, .g = 0.988, .b = 1, .a = 1 };
    const color_attachments = [_]gpu.RenderPassColorAttachment{.{
        .view = back_buffer_view,
        .clear_value = sky_blue_background,
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
    render_pass.draw(3, 1, 0, 0);

    render_pass.end();

    var command = encoder.finish(&.{ .label = label });
    defer command.release();
    window.queue.submit(&[_]*gpu.CommandBuffer{command});

    // update the window title every second
    // if (app.title_timer.read() >= 1.0) {
    //     app.title_timer.reset();
    //     // TODO(object): window-title
    //     // try updateWindowTitle(core);
    // }
}

pub fn deinit(app: *App) void {
    app.pipeline.release();
}

// TODO(object): window-title
// fn updateWindowTitle(core: *mach.Core) !void {
//     try core.printTitle(
//         core.main_window,
//         "core-custom-entrypoint [ {d}fps ] [ Input {d}hz ]",
//         .{
//             // TODO(Core)
//             core.frameRate(),
//             core.inputRate(),
//         },
//     );
//     core.schedule(.update);
// }
