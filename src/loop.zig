const std = @import("std");
const TaskStack = std.atomic.Stack(Task);
const Thread = std.Thread;
const Allocator = std.mem.Allocator;
const tracy = @import("vendor/tracy.zig");

const Task = struct {
    fnPtr: *const fn (userdata: ?*anyopaque) void,
    userdata: ?*anyopaque,
};

pub fn Job(comptime ResultType: type) type {
    return struct {
        loop: *EventLoop,
        result: ResultType,
        completed: std.atomic.Atomic(bool),
        /// If the call() function was used, this contains the async frame
        //asyncBuffer: ?[]u8 = null,
        toNotify: ?*Self = null,
        node: TaskStack.Node = undefined,
        has_node: bool = false,

        const Self = @This();

        pub fn create(loop: *EventLoop) !*Self {
            const jobPtr = try loop.allocator.create(Self);
            jobPtr.* = .{ .loop = loop, .result = undefined, .completed = std.atomic.Atomic(bool).init(false) };
            return jobPtr;
        }

        pub fn completed(loop: *EventLoop, result: ResultType) !*Self {
            const jobPtr = try loop.allocator.create(Self);
            jobPtr.* = .{ .loop = loop, .result = result, .completed = std.atomic.Atomic(bool).init(true) };
            return jobPtr;
        }

        pub fn call(self: *Self, comptime func: anytype, args: anytype) !void {
            if (self.has_node) {
                @panic("Cannot use Job.call() more than once!");
            }
            const Fn = switch (@typeInfo(@TypeOf(func))) {
                .Fn => |info| info,
                else => @compileError("Type " ++ @typeName(@TypeOf(func)) ++ " is not a function"),
            };
            const ReturnType = Fn.return_type.?;
            if (ReturnType == ResultType) {
                const ArgsType = @TypeOf(args);
                const WrapperArgsType = struct { job: *Self, funcArgs: ArgsType, allocator: std.mem.Allocator };
                const wrapper = struct {
                    pub fn wrapper(userdata: ?*anyopaque) callconv(.Unspecified) void {
                        const wrapperArgs = @ptrCast(*WrapperArgsType, @alignCast(@alignOf(WrapperArgsType), userdata));
                        const job = wrapperArgs.job;
                        const funcArgs = wrapperArgs.funcArgs;
                        const result = @call(.auto, func, funcArgs);
                        job.notify(result);

                        const allocator = wrapperArgs.allocator;
                        allocator.destroy(wrapperArgs);
                    }
                }.wrapper;
                //const buffer = try self.loop.allocator.alignedAlloc(u8, @alignOf(@Frame(wrapper)), @frameSize(wrapper));
                //self.asyncBuffer = buffer;
                //_ = @asyncCall(buffer, undefined, wrapper, .{ self, args });
                const args_ptr = try self.loop.allocator.create(WrapperArgsType);
                args_ptr.* = .{ .job = self, .funcArgs = args, .allocator = self.loop.allocator };
                self.node = .{
                    .data = .{ .fnPtr = wrapper, .userdata = args_ptr },
                    .next = null,
                };
                self.has_node = true;
                self.loop.taskStack.push(&self.node);
            } else {
                @compileError("The function's return type doesn't match the job's result type");
            }
        }

        /// Get result
        pub fn get(self: *const Self) ResultType {
            while (self.completed.load(.Acquire) == false) {
                //self.loop.yield();
                std.time.sleep(1000);
            }
            return self.result;
        }

        pub fn peek(self: *const Self) ?ResultType {
            if (self.completed.load(.Acquire) == true) {
                return self.result;
            } else {
                return null;
            }
        }

        pub fn isCompleted(self: *const Self) bool {
            return self.completed.load(.Acquire);
        }

        pub fn then(self: *Self, next: *Self) void {
            if (self.toNotify != null) {
                @panic("Trying to set a job to notify twice"); // TODO: support multiple notified jobs
            } else {
                self.toNotify = next;
            }
        }

        /// Get result and deinit the job.
        pub fn wait(self: *Self) ResultType {
            const result = self.get();
            self.deinit();

            return result;
        }

        pub fn notify(self: *Self, value: ResultType) void {
            self.result = value;
            defer self.completed.store(true, .Release);

            if (self.toNotify) |job| {
                job.notify(value);
            }
        }

        pub fn deinit(self: *Self) void {
            self.loop.allocator.destroy(self);
        }
    };
}

// TODO: launch new threads if none available
pub const EventLoop = struct {
    allocator: Allocator,
    taskStack: TaskStack,
    //numTasks: std.atomic.Atomic(u32) = std.atomic.Atomic(u32).init(0),
    /// The number of 'events', when it hits 0 the run loop is stopped
    events: usize = 0,
    threads: []Thread,

    pub fn init() EventLoop {
        return EventLoop{
            .allocator = undefined,
            .taskStack = TaskStack.init(),
            .threads = undefined,
        };
    }

    /// This function assumes that the EventLoop pointer will stay
    /// valid during the entire loop's lifetime
    pub fn start(self: *EventLoop, allocator: Allocator) !void {
        const cpuCount = try Thread.getCpuCount();
        const threads = try allocator.alloc(Thread, cpuCount);
        self.threads = threads;
        self.allocator = allocator;

        for (threads, 0..) |*thread, threadId| {
            thread.* = try Thread.spawn(.{}, workerLoop, .{ self, threadId });
        }
    }

    pub fn workerLoop(self: *EventLoop, threadId: usize) void {
        _ = threadId;
        //tracy.InitThread();
        //var buf: [64]u8 = undefined;
        //tracy.SetThreadName(std.fmt.bufPrintZ(&buf, "Worker-{d}", .{threadId}) catch unreachable);

        while (self.events > 0) {
            if (self.taskStack.pop()) |node| {
                //std.log.debug("taking task on thread {}", .{threadId});
                node.data.fnPtr(node.data.userdata);
                //std.log.debug("task ended on thread {}", .{threadId});
            } else {
                // wait until a task is available
                std.time.sleep(8 * std.time.ns_per_ms);
            }
        }
    }

    pub fn beginEvent(self: *EventLoop) void {
        self.events += 1;
    }

    /// End an event. If the loop now has 0 events,
    /// it will be deinit.
    pub fn endEvent(self: *EventLoop) void {
        self.events -= 1;
        if (self.events == 0) {
            for (self.threads) |thread| {
                thread.join();
            }
            self.allocator.free(self.threads);
            self.* = undefined;
        }
    }

    /// The number of frames a task should ideally divide itself into
    pub fn getParallelCount(self: *const EventLoop) usize {
        return self.threads.len;
    }
};
