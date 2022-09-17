const std = @import("std");
const TaskStack = std.atomic.Stack(Task);
const Thread = std.Thread;
const Allocator = std.mem.Allocator;
const tracy = @import("vendor/tracy.zig");

const Task = struct {
	frame: anyframe,
};

pub fn Job(comptime ResultType: type) type {
	return struct {
		loop: *EventLoop,
		result: ResultType,
		completed: std.atomic.Atomic(bool),
		/// If the call() function was used, this contains the async frame
		asyncBuffer: ?[]u8 = null,
		toNotify: ?*Self = null,

		const Self = @This();

		pub fn create(loop: *EventLoop) !*Self {
			const jobPtr = try loop.allocator.create(Self);
			jobPtr.* = .{
				.loop = loop,
				.result = undefined,
				.completed = std.atomic.Atomic(bool).init(false)
			};
			return jobPtr;
		}

		pub fn completed(loop: *EventLoop, result: ResultType) !*Self {
			const jobPtr = try loop.allocator.create(Self);
			jobPtr.* = .{
				.loop = loop,
				.result = result,
				.completed = std.atomic.Atomic(bool).init(true)
			};
			return jobPtr;
		}

		pub fn call(self: *Self, comptime func: anytype, args: anytype) !void {
			if (self.asyncBuffer != null) {
				// Attempted to use call() function twice!
				return error.AlreadyCalled;
			}

			const Fn = switch (@typeInfo(@TypeOf(func))) {
				.Fn => |info| info,
				.BoundFn => |info| info,
				else => @compileError("Type " ++ @typeName(@TypeOf(func)) ++ " is not a function")
			};
			const ReturnType = Fn.return_type.?;
			if (ReturnType == ResultType) {
				const ArgsType = @TypeOf(args);
				const wrapper = struct {
					pub fn wrapper(job: *Self, funcArgs: ArgsType) callconv(.Async) void {
						const result = @call(.{}, func, funcArgs);
						job.notify(result);
					}
				}.wrapper;
				const buffer = try self.loop.allocator.alignedAlloc(u8, @alignOf(@Frame(wrapper)), @frameSize(wrapper));
				self.asyncBuffer = buffer;
				_ = @asyncCall(buffer, undefined, wrapper, .{ self, args });
			} else {
				@compileError("The function's return type doesn't match the job's result type");
			}
		}

		/// Get result
		pub fn get(self: *const Self) ResultType {
			while (self.completed.load(.Acquire) == false) {
				self.loop.yield();
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
			self.completed.store(true, .Release);

			if (self.toNotify) |job| {
				job.notify(value);
			}
		}

		pub fn deinit(self: *Self) void {
			if (self.asyncBuffer) |buf| {
				self.loop.allocator.free(buf);
			}
			self.loop.allocator.destroy(self);
		}
	};
}

pub const EventLoop = struct {
	allocator: Allocator,
	taskStack: TaskStack,
	//numTasks: std.atomic.Atomic(u32) = std.atomic.Atomic(u32).init(0),
	/// The number of 'events', when it hits 0 the run loop is stopped
	events: usize = 0,
	threads: []Thread,

	pub fn init() EventLoop {
		return EventLoop {
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

		for (threads) |*thread, threadId| {
			thread.* = try Thread.spawn(.{}, workerLoop, .{ self, threadId });
		}
	}

	pub fn workerLoop(self: *EventLoop, threadId: usize) void {
		_ = threadId;
		//tracy.InitThread();
		//tracy.SetThreadName(std.fmt.bufPrintZ(&buf, "Worker-{d}", .{ threadId }) catch unreachable);

		while (self.events > 0) {
			if (self.taskStack.pop()) |node| {
				resume node.data.frame;
			} else {
				// wait until a task is available
				std.time.sleep(16 * std.time.ns_per_ms);
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

	pub fn yield(self: *EventLoop) void {
		suspend {
			var node = TaskStack.Node {
				.next = undefined,
				.data = .{
					.frame = @frame(),
				}
			};
			self.taskStack.push(&node);
		}
	}

};
