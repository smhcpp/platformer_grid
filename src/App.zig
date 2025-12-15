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
pipeline: *gpu.RenderPipeline,
bind_group: *gpu.BindGroup,
player: T.Player,
globals: T.Globals,
player_buffer: *gpu.Buffer,
globals_buffer: *gpu.Buffer,
map: *T.MapArea = undefined,

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
                .pos = .{ 0.0, 0.0 },
                .size = .{ 0.1, 0.2 },
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
    try app.setup();
}

fn setup(app:*App) !void{
    app.map = try T.MapArea.init(std.heap.c_allocator);
}

fn setupBuffers(app:*App,window:anytype) *gpu.BindGroupLayout{
    app.player_buffer = window.device.createBuffer(&.{
        .label = "player uniform buffer",
        .usage = .{ .uniform = true, .copy_dst = true },
        .size = @sizeOf(T.RectGPU),
        .mapped_at_creation = .false,
    });
    app.globals_buffer = window.device.createBuffer(&.{
        .label = "globals uniform buffer",
        .usage = .{ .uniform = true, .copy_dst = true },
        .size = @sizeOf(T.Globals),
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
    app.bind_group = window.device.createBindGroup(&gpu.BindGroup.Descriptor.init(.{
        .label = "Bind groups",
        .layout = bind_group_layout,
        .entries = &.{
            .{
                .binding = 0,
                .buffer = app.player_buffer,
                .offset = 0,
                .size = @sizeOf(T.RectGPU),
            },
            .{
                .binding = 1,
                .buffer = app.globals_buffer,
                .offset = 0,
                .size = @sizeOf(T.Globals),
            },
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

pub fn updateSystems(app: *App,core: *mach.Core) void {
    const window = core.windows.getValue(app.window);
    app.globals.aspect_ratio = @as(f32, @floatFromInt(window.width)) / @as(f32, @floatFromInt(window.height));
    app.player.shape.pos +=app.player.velocity;
}

pub fn updateBuffers(app: *App,core: *mach.Core) void {
    const window = core.windows.getValue(app.window);
    const rgpu= T.RectGPU{
        .x= app.player.shape.pos[0],
        .y= app.player.shape.pos[1],
        .w= app.player.shape.size[0],
        .h= app.player.shape.size[1],
    };
    window.queue.writeBuffer(app.player_buffer, 0, &[_]T.RectGPU{rgpu});
    window.queue.writeBuffer(app.globals_buffer, 0, &[_]T.Globals{app.globals});
}

pub fn handleEvents(app: *App,core: *mach.Core) void {
    const dl: f32 = 0.02;
    while (core.nextEvent()) |event| {
        switch (event) {
            .window_open => |ev| {
                try setupPipeline(core, app, ev.window_id);
            },
            .close => core.exit(),
            .key_press => |ev|{
                if (ev.key == .right){
                    app.player.velocity[0] = dl;
                } else if (ev.key == .left){
                    app.player.velocity[0] = -dl;
                } else if (ev.key == .up){
                    app.player.velocity[1] = dl;
                } else if (ev.key == .down){
                    app.player.velocity[1] = -dl;
                }
            },
            .key_release => |ev|{
                if (ev.key == .right){
                    app.player.velocity[0] = 0.0;
                } else if (ev.key == .left){
                    app.player.velocity[0] = 0.0;
                } else if (ev.key == .up){
                    app.player.velocity[1] = 0.0;
                } else if (ev.key == .down){
                    app.player.velocity[1] = 0.0;
                }
            },
            else => {},
        }
    }
}

pub fn tick(app: *App, core: *mach.Core) void {
    handleEvents(app,core);
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

    render_pass.setPipeline(app.pipeline);
    render_pass.setBindGroup(0, app.bind_group, &.{});
    render_pass.draw(6, 1, 0, 0);
    render_pass.end();

    var command = encoder.finish(&.{});
    defer command.release();
    window.queue.submit(&[_]*gpu.CommandBuffer{command});
}

pub fn deinit(app: *App) void {
    // 1. Release GPU Resources
    // Order doesn't strictly matter for these, but good practice is reverse creation order
    app.pipeline.release();
    app.bind_group.release();
    // app.objects_buffer.release();
    app.globals_buffer.release();

    // 2. Release CPU Memory
    // The map was allocated with c_allocator, so we free it with c_allocator
    app.map.deinit(std.heap.c_allocator);
}
