// Patched for Swift 6.3-dev (nightly-main) WASM compatibility
// Removed @available annotations — WASM has no OS versioning, and they cause
// runtime availability checks to fail (asSchedulingExecutor returns nil)

#if compiler(>=6.3)
@_spi(ExperimentalCustomExecutors) import _Concurrency
#else
import _Concurrency
#endif
import _CJavaScriptKit

#if compiler(>=6.3)

@_spi(ExperimentalCustomExecutors)
extension JavaScriptEventLoop: MainExecutor {
    public func run() throws {
        swjs_unsafe_event_loop_yield()
    }
    public func stop() {}
}

extension JavaScriptEventLoop: TaskExecutor {}

@_spi(ExperimentalCustomExecutors)
extension JavaScriptEventLoop: SchedulingExecutor {
    public func enqueue<C: Clock>(
        _ job: consuming ExecutorJob,
        after delay: C.Duration,
        tolerance: C.Duration?,
        clock: C
    ) {
        let duration: Duration
        if let _ = clock as? ContinuousClock {
            duration = delay as! ContinuousClock.Duration
        } else if let _ = clock as? SuspendingClock {
            duration = delay as! SuspendingClock.Duration
        } else {
            // Unknown clock — enqueue immediately as fallback
            let unowned = UnownedJob(job)
            JavaScriptEventLoop.shared.enqueue(unowned)
            return
        }
        let (seconds, attoseconds) = duration.components
        let milliseconds = Double(seconds) * 1_000 + (Double(attoseconds) / 1_000_000_000_000_000)
        self.enqueue(
            UnownedJob(job),
            withDelay: milliseconds
        )
    }
}

// MARK: - ExecutorFactory Implementation
@_spi(ExperimentalCustomExecutors)
extension JavaScriptEventLoop: ExecutorFactory {
    final class CurrentThread: TaskExecutor, SchedulingExecutor, MainExecutor, SerialExecutor {
        func checkIsolated() {}

        func enqueue(_ job: consuming ExecutorJob) {
            JavaScriptEventLoop.shared.enqueue(job)
        }

        func enqueue<C: Clock>(
            _ job: consuming ExecutorJob,
            after delay: C.Duration,
            tolerance: C.Duration?,
            clock: C
        ) {
            JavaScriptEventLoop.shared.enqueue(
                job,
                after: delay,
                tolerance: tolerance,
                clock: clock
            )
        }

        func run() throws {
            try JavaScriptEventLoop.shared.run()
        }
        func stop() {
            JavaScriptEventLoop.shared.stop()
        }
    }

    public static var mainExecutor: any MainExecutor {
        CurrentThread()
    }

    public static var defaultExecutor: any TaskExecutor {
        CurrentThread()
    }
}

#endif  // compiler(>=6.3)
