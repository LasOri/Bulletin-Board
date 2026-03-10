/**
 * WASM Loader for Bulletin Board
 * Loads and initializes the Swift WebAssembly binary
 *
 * Includes embedded JavaScriptKit 0.46.5 SwiftRuntime
 * (from runtime.mjs — inlined for GitHub Pages compatibility)
 */

let wasmInstance = null;
let wasmMemory = null;

// ============================================================
// JavaScriptKit SwiftRuntime (embedded from runtime.mjs v708)
// ============================================================

class SwiftClosureDeallocator {
    constructor(exports) {
        if (typeof FinalizationRegistry === "undefined") {
            throw new Error("The Swift part of JavaScriptKit was configured to require " +
                "the availability of JavaScript WeakRefs. Please build " +
                "with `-Xswiftc -DJAVASCRIPTKIT_WITHOUT_WEAKREFS` to " +
                "disable features that use WeakRefs.");
        }
        this.functionRegistry = new FinalizationRegistry((id) => {
            exports.swjs_free_host_function(id);
        });
    }
    track(func, func_ref) {
        this.functionRegistry.register(func, func_ref);
    }
}

function assertNever(x, message) {
    throw new Error(message);
}

const MAIN_THREAD_TID = -1;

const decode = (kind, payload1, payload2, objectSpace) => {
    switch (kind) {
        case 0 /* Boolean */:
            switch (payload1) {
                case 0: return false;
                case 1: return true;
            }
        // falls through
        case 2 /* Number */:
            return payload2;
        case 1 /* String */:
        case 3 /* Object */:
        case 7 /* Symbol */:
        case 8 /* BigInt */:
            return objectSpace.getObject(payload1);
        case 4 /* Null */:
            return null;
        case 5 /* Undefined */:
            return undefined;
        default:
            assertNever(kind, `JSValue Type kind "${kind}" is not supported`);
    }
};

const decodeArray = (ptr, length, memory, objectSpace) => {
    if (length === 0) return [];
    let result = [];
    for (let index = 0; index < length; index++) {
        const base = ptr + 16 * index;
        const kind = memory.getUint32(base, true);
        const payload1 = memory.getUint32(base + 4, true);
        const payload2 = memory.getFloat64(base + 8, true);
        result.push(decode(kind, payload1, payload2, objectSpace));
    }
    return result;
};

const write = (value, kind_ptr, payload1_ptr, payload2_ptr, is_exception, memory, objectSpace) => {
    const kind = writeAndReturnKindBits(value, payload1_ptr, payload2_ptr, is_exception, memory, objectSpace);
    memory.setUint32(kind_ptr, kind, true);
};

const writeAndReturnKindBits = (value, payload1_ptr, payload2_ptr, is_exception, memory, objectSpace) => {
    const exceptionBit = (is_exception ? 1 : 0) << 31;
    if (value === null) {
        return exceptionBit | 4 /* Null */;
    }
    const writeRef = (kind) => {
        memory.setUint32(payload1_ptr, objectSpace.retain(value), true);
        return exceptionBit | kind;
    };
    const type = typeof value;
    switch (type) {
        case "boolean":
            memory.setUint32(payload1_ptr, value ? 1 : 0, true);
            return exceptionBit | 0 /* Boolean */;
        case "number":
            memory.setFloat64(payload2_ptr, value, true);
            return exceptionBit | 2 /* Number */;
        case "string":
            return writeRef(1 /* String */);
        case "undefined":
            return exceptionBit | 5 /* Undefined */;
        case "object":
            return writeRef(3 /* Object */);
        case "function":
            return writeRef(3 /* Object */);
        case "symbol":
            return writeRef(7 /* Symbol */);
        case "bigint":
            return writeRef(8 /* BigInt */);
        default:
            assertNever(type, `Type "${type}" is not supported yet`);
    }
    throw new Error("Unreachable");
};

function decodeObjectRefs(ptr, length, memory) {
    const result = new Array(length);
    for (let i = 0; i < length; i++) {
        result[i] = memory.getUint32(ptr + 4 * i, true);
    }
    return result;
}

class ITCInterface {
    constructor(memory) { this.memory = memory; }
    send(sendingObject, transferringObjects, sendingContext) {
        const object = this.memory.getObject(sendingObject);
        const transfer = transferringObjects.map((ref) => this.memory.getObject(ref));
        return { object, sendingContext, transfer };
    }
    sendObjects(sendingObjects, transferringObjects, sendingContext) {
        const objects = sendingObjects.map((ref) => this.memory.getObject(ref));
        const transfer = transferringObjects.map((ref) => this.memory.getObject(ref));
        return { object: objects, sendingContext, transfer };
    }
    release(objectRef) {
        this.memory.release(objectRef);
        return { object: undefined, transfer: [] };
    }
}

class MessageBroker {
    constructor(selfTid, threadChannel, handlers) {
        this.selfTid = selfTid;
        this.threadChannel = threadChannel;
        this.handlers = handlers;
    }
    request(message) {
        if (message.data.targetTid == this.selfTid) {
            this.handlers.onRequest(message);
        } else if ("postMessageToWorkerThread" in this.threadChannel) {
            this.threadChannel.postMessageToWorkerThread(message.data.targetTid, message, []);
        } else if ("postMessageToMainThread" in this.threadChannel) {
            this.threadChannel.postMessageToMainThread(message, []);
        } else {
            throw new Error("unreachable");
        }
    }
    reply(message) {
        if (message.data.sourceTid == this.selfTid) {
            this.handlers.onResponse(message);
            return;
        }
        const transfer = message.data.response.ok ? message.data.response.value.transfer : [];
        if ("postMessageToWorkerThread" in this.threadChannel) {
            this.threadChannel.postMessageToWorkerThread(message.data.sourceTid, message, transfer);
        } else if ("postMessageToMainThread" in this.threadChannel) {
            this.threadChannel.postMessageToMainThread(message, transfer);
        } else {
            throw new Error("unreachable");
        }
    }
    onReceivingRequest(message) {
        if (message.data.targetTid == this.selfTid) {
            this.handlers.onRequest(message);
        } else if ("postMessageToWorkerThread" in this.threadChannel) {
            this.threadChannel.postMessageToWorkerThread(message.data.targetTid, message, []);
        } else if ("postMessageToMainThread" in this.threadChannel) {
            throw new Error("unreachable");
        }
    }
    onReceivingResponse(message) {
        if (message.data.sourceTid == this.selfTid) {
            this.handlers.onResponse(message);
        } else if ("postMessageToWorkerThread" in this.threadChannel) {
            const transfer = message.data.response.ok ? message.data.response.value.transfer : [];
            this.threadChannel.postMessageToWorkerThread(message.data.sourceTid, message, transfer);
        } else if ("postMessageToMainThread" in this.threadChannel) {
            throw new Error("unreachable");
        }
    }
}

function serializeError(error) {
    if (error instanceof Error) {
        return { isError: true, value: { message: error.message, name: error.name, stack: error.stack } };
    }
    return { isError: false, value: error };
}

function deserializeError(error) {
    if (error.isError) {
        return Object.assign(new Error(error.value.message), error.value);
    }
    return error.value;
}

const globalVariable = globalThis;

class JSObjectSpace {
    constructor() {
        this._heapValueById = new Map();
        this._heapValueById.set(1, globalVariable);
        this._heapEntryByValue = new Map();
        this._heapEntryByValue.set(globalVariable, { id: 1, rc: 1 });
        this._heapNextKey = 2;
    }
    retain(value) {
        const entry = this._heapEntryByValue.get(value);
        if (entry) { entry.rc++; return entry.id; }
        const id = this._heapNextKey++;
        this._heapValueById.set(id, value);
        this._heapEntryByValue.set(value, { id: id, rc: 1 });
        return id;
    }
    retainByRef(ref) { return this.retain(this.getObject(ref)); }
    release(ref) {
        const value = this._heapValueById.get(ref);
        const entry = this._heapEntryByValue.get(value);
        entry.rc--;
        if (entry.rc != 0) return;
        this._heapEntryByValue.delete(value);
        this._heapValueById.delete(ref);
    }
    getObject(ref) {
        const value = this._heapValueById.get(ref);
        if (value === undefined) {
            throw new ReferenceError("Attempted to read invalid reference " + ref);
        }
        return value;
    }
}

class UnsafeEventLoopYield extends Error {}

class SwiftRuntime {
    constructor(options) {
        this.version = 708;
        this.textDecoder = new TextDecoder("utf-8");
        this.textEncoder = new TextEncoder();
        this.UnsafeEventLoopYield = UnsafeEventLoopYield;
        this.importObjects = () => this.wasmImports;
        this._instance = null;
        this.memory = new JSObjectSpace();
        this._closureDeallocator = null;
        this.tid = null;
        this.options = options || {};
        this.getDataView = () => { throw new Error("Please call setInstance() before using any JavaScriptKit APIs from Swift."); };
        this.getUint8Array = () => { throw new Error("Please call setInstance() before using any JavaScriptKit APIs from Swift."); };
        this.wasmMemory = null;
    }
    setInstance(instance) {
        this._instance = instance;
        const wasmMemory = instance.exports.memory;
        if (wasmMemory instanceof WebAssembly.Memory) {
            let cachedDataView = new DataView(wasmMemory.buffer);
            let cachedUint8Array = new Uint8Array(wasmMemory.buffer);
            if (Object.getPrototypeOf(wasmMemory.buffer).constructor.name === "SharedArrayBuffer") {
                this.getDataView = () => {
                    if (cachedDataView.buffer !== wasmMemory.buffer) cachedDataView = new DataView(wasmMemory.buffer);
                    return cachedDataView;
                };
                this.getUint8Array = () => {
                    if (cachedUint8Array.buffer !== wasmMemory.buffer) cachedUint8Array = new Uint8Array(wasmMemory.buffer);
                    return cachedUint8Array;
                };
            } else {
                this.getDataView = () => {
                    if (cachedDataView.buffer.byteLength === 0) cachedDataView = new DataView(wasmMemory.buffer);
                    return cachedDataView;
                };
                this.getUint8Array = () => {
                    if (cachedUint8Array.byteLength === 0) cachedUint8Array = new Uint8Array(wasmMemory.buffer);
                    return cachedUint8Array;
                };
            }
            this.wasmMemory = wasmMemory;
        } else {
            throw new Error("instance.exports.memory is not a WebAssembly.Memory!?");
        }
        if (this.exports.swjs_library_version() != this.version) {
            throw new Error(`The versions of JavaScriptKit are incompatible. WebAssembly runtime ${this.exports.swjs_library_version()} != JS runtime ${this.version}`);
        }
    }
    main() {
        const instance = this.instance;
        try {
            if (typeof instance.exports.main === "function") {
                console.log('[swift.main] calling exports.main()');
                instance.exports.main();
                console.log('[swift.main] exports.main() returned normally');
            } else if (typeof instance.exports.__main_argc_argv === "function") {
                console.log('[swift.main] calling exports.__main_argc_argv(0, 0)');
                instance.exports.__main_argc_argv(0, 0);
                console.log('[swift.main] exports.__main_argc_argv returned normally');
            } else {
                console.log('[swift.main] no main export found');
            }
        } catch (error) {
            if (error instanceof UnsafeEventLoopYield) {
                console.log('[swift.main] caught UnsafeEventLoopYield (expected for async main)');
                return;
            }
            console.error('[swift.main] caught unexpected error:', error);
            throw error;
        }
    }
    startThread(tid, startArg) {
        this.tid = tid;
        const instance = this.instance;
        try {
            if (typeof instance.exports.wasi_thread_start === "function") {
                instance.exports.wasi_thread_start(tid, startArg);
            } else {
                throw new Error("The WebAssembly module is not built for wasm32-unknown-wasip1-threads target.");
            }
        } catch (error) {
            if (error instanceof UnsafeEventLoopYield) return;
            throw error;
        }
    }
    get instance() {
        if (!this._instance) throw new Error("WebAssembly instance is not set yet");
        return this._instance;
    }
    get exports() { return this.instance.exports; }
    get closureDeallocator() {
        if (this._closureDeallocator) return this._closureDeallocator;
        const features = this.exports.swjs_library_features();
        const librarySupportsWeakRef = (features & 1) != 0;
        if (librarySupportsWeakRef) {
            this._closureDeallocator = new SwiftClosureDeallocator(this.exports);
        }
        return this._closureDeallocator;
    }
    callHostFunction(host_func_id, line, file, args) {
        console.log(`[callHostFunction] id=${host_func_id} file=${file} line=${line} argc=${args.length}`);
        const argc = args.length;
        const argv = this.exports.swjs_prepare_host_function_call(argc);
        const memory = this.memory;
        const dataView = this.getDataView();
        for (let index = 0; index < args.length; index++) {
            const argument = args[index];
            const base = argv + 16 * index;
            write(argument, base, base + 4, base + 8, false, dataView, memory);
        }
        let output;
        const callback_func_ref = memory.retain((result) => { output = result; });
        const alreadyReleased = this.exports.swjs_call_host_function(host_func_id, argv, argc, callback_func_ref);
        if (alreadyReleased) {
            throw new Error(`The JSClosure has been already released by Swift side. The closure is created at ${file}:${line} @${host_func_id}`);
        }
        this.exports.swjs_cleanup_host_function_call(argv);
        return output;
    }
    get wasmImports() {
        let broker = null;
        const getMessageBroker = (threadChannel) => {
            if (broker) return broker;
            const itcInterface = new ITCInterface(this.memory);
            const newBroker = new MessageBroker(this.tid ?? -1, threadChannel, {
                onRequest: (message) => {
                    let returnValue;
                    try {
                        const result = itcInterface[message.data.request.method](...message.data.request.parameters);
                        returnValue = { ok: true, value: result };
                    } catch (error) {
                        returnValue = { ok: false, error: serializeError(error) };
                    }
                    const responseMessage = {
                        type: "response",
                        data: { sourceTid: message.data.sourceTid, context: message.data.context, response: returnValue }
                    };
                    try { newBroker.reply(responseMessage); }
                    catch (error) {
                        responseMessage.data.response = { ok: false, error: serializeError(new TypeError(`Failed to serialize message: ${error}`)) };
                        newBroker.reply(responseMessage);
                    }
                },
                onResponse: (message) => {
                    if (message.data.response.ok) {
                        const object = this.memory.retain(message.data.response.value.object);
                        this.exports.swjs_receive_response(object, message.data.context);
                    } else {
                        const error = deserializeError(message.data.response.error);
                        const errorObject = this.memory.retain(error);
                        this.exports.swjs_receive_error(errorObject, message.data.context);
                    }
                },
            });
            broker = newBroker;
            return newBroker;
        };
        return {
            swjs_set_prop: (ref, name, kind, payload1, payload2) => {
                const memory = this.memory;
                const obj = memory.getObject(ref);
                const key = memory.getObject(name);
                const value = decode(kind, payload1, payload2, memory);
                obj[key] = value;
            },
            swjs_get_prop: (ref, name, payload1_ptr, payload2_ptr) => {
                const memory = this.memory;
                const obj = memory.getObject(ref);
                const key = memory.getObject(name);
                const result = obj[key];
                return writeAndReturnKindBits(result, payload1_ptr, payload2_ptr, false, this.getDataView(), this.memory);
            },
            swjs_set_subscript: (ref, index, kind, payload1, payload2) => {
                const memory = this.memory;
                const obj = memory.getObject(ref);
                const value = decode(kind, payload1, payload2, memory);
                obj[index] = value;
            },
            swjs_get_subscript: (ref, index, payload1_ptr, payload2_ptr) => {
                const obj = this.memory.getObject(ref);
                const result = obj[index];
                return writeAndReturnKindBits(result, payload1_ptr, payload2_ptr, false, this.getDataView(), this.memory);
            },
            swjs_encode_string: (ref, bytes_ptr_result) => {
                const memory = this.memory;
                const bytes = this.textEncoder.encode(memory.getObject(ref));
                const bytes_ptr = memory.retain(bytes);
                this.getDataView().setUint32(bytes_ptr_result, bytes_ptr, true);
                return bytes.length;
            },
            swjs_decode_string: (bytes_ptr, length) => {
                const bytes = this.getUint8Array().subarray(bytes_ptr, bytes_ptr + length);
                const string = this.textDecoder.decode(bytes);
                return this.memory.retain(string);
            },
            swjs_load_string: (ref, buffer) => {
                const bytes = this.memory.getObject(ref);
                this.getUint8Array().set(bytes, buffer);
            },
            swjs_call_function: (ref, argv, argc, payload1_ptr, payload2_ptr) => {
                const memory = this.memory;
                const func = memory.getObject(ref);
                let result;
                try {
                    const args = decodeArray(argv, argc, this.getDataView(), memory);
                    result = func(...args);
                } catch (error) {
                    return writeAndReturnKindBits(error, payload1_ptr, payload2_ptr, true, this.getDataView(), this.memory);
                }
                return writeAndReturnKindBits(result, payload1_ptr, payload2_ptr, false, this.getDataView(), this.memory);
            },
            swjs_call_function_no_catch: (ref, argv, argc, payload1_ptr, payload2_ptr) => {
                const memory = this.memory;
                const func = memory.getObject(ref);
                const args = decodeArray(argv, argc, this.getDataView(), memory);
                const result = func(...args);
                return writeAndReturnKindBits(result, payload1_ptr, payload2_ptr, false, this.getDataView(), this.memory);
            },
            swjs_call_function_with_this: (obj_ref, func_ref, argv, argc, payload1_ptr, payload2_ptr) => {
                const memory = this.memory;
                const obj = memory.getObject(obj_ref);
                const func = memory.getObject(func_ref);
                let result;
                try {
                    const args = decodeArray(argv, argc, this.getDataView(), memory);
                    result = func.apply(obj, args);
                } catch (error) {
                    return writeAndReturnKindBits(error, payload1_ptr, payload2_ptr, true, this.getDataView(), this.memory);
                }
                return writeAndReturnKindBits(result, payload1_ptr, payload2_ptr, false, this.getDataView(), this.memory);
            },
            swjs_call_function_with_this_no_catch: (obj_ref, func_ref, argv, argc, payload1_ptr, payload2_ptr) => {
                const memory = this.memory;
                const obj = memory.getObject(obj_ref);
                const func = memory.getObject(func_ref);
                const args = decodeArray(argv, argc, this.getDataView(), memory);
                const result = func.apply(obj, args);
                return writeAndReturnKindBits(result, payload1_ptr, payload2_ptr, false, this.getDataView(), this.memory);
            },
            swjs_call_new: (ref, argv, argc) => {
                const memory = this.memory;
                const constructor = memory.getObject(ref);
                const args = decodeArray(argv, argc, this.getDataView(), memory);
                const instance = new constructor(...args);
                return this.memory.retain(instance);
            },
            swjs_call_throwing_new: (ref, argv, argc, exception_kind_ptr, exception_payload1_ptr, exception_payload2_ptr) => {
                let memory = this.memory;
                const constructor = memory.getObject(ref);
                let result;
                try {
                    const args = decodeArray(argv, argc, this.getDataView(), memory);
                    result = new constructor(...args);
                } catch (error) {
                    write(error, exception_kind_ptr, exception_payload1_ptr, exception_payload2_ptr, true, this.getDataView(), this.memory);
                    return -1;
                }
                memory = this.memory;
                write(null, exception_kind_ptr, exception_payload1_ptr, exception_payload2_ptr, false, this.getDataView(), memory);
                return memory.retain(result);
            },
            swjs_instanceof: (obj_ref, constructor_ref) => {
                const memory = this.memory;
                const obj = memory.getObject(obj_ref);
                const constructor = memory.getObject(constructor_ref);
                return obj instanceof constructor;
            },
            swjs_value_equals: (lhs_ref, rhs_ref) => {
                const memory = this.memory;
                const lhs = memory.getObject(lhs_ref);
                const rhs = memory.getObject(rhs_ref);
                return lhs == rhs;
            },
            swjs_create_function: (host_func_id, line, file) => {
                const fileString = this.memory.getObject(file);
                const func = (...args) => this.callHostFunction(host_func_id, line, fileString, args);
                const func_ref = this.memory.retain(func);
                this.closureDeallocator?.track(func, host_func_id);
                return func_ref;
            },
            swjs_create_oneshot_function: (host_func_id, line, file) => {
                const fileString = this.memory.getObject(file);
                const func = (...args) => this.callHostFunction(host_func_id, line, fileString, args);
                const func_ref = this.memory.retain(func);
                return func_ref;
            },
            swjs_create_typed_array: (constructor_ref, elementsPtr, length) => {
                const ArrayType = this.memory.getObject(constructor_ref);
                if (length == 0) return this.memory.retain(new ArrayType());
                const array = new ArrayType(this.wasmMemory.buffer, elementsPtr, length);
                return this.memory.retain(array.slice());
            },
            swjs_create_object: () => {
                return this.memory.retain({});
            },
            swjs_load_typed_array: (ref, buffer) => {
                const memory = this.memory;
                const typedArray = memory.getObject(ref);
                const bytes = new Uint8Array(typedArray.buffer);
                this.getUint8Array().set(bytes, buffer);
            },
            swjs_release: (ref) => { this.memory.release(ref); },
            swjs_release_remote: (tid, ref) => {
                if (!this.options.threadChannel) {
                    throw new Error("threadChannel is not set in options given to SwiftRuntime.");
                }
                const broker = getMessageBroker(this.options.threadChannel);
                broker.request({
                    type: "request",
                    data: {
                        sourceTid: this.tid ?? MAIN_THREAD_TID,
                        targetTid: tid, context: 0,
                        request: { method: "release", parameters: [ref] },
                    },
                });
            },
            swjs_i64_to_bigint: (value, signed) => {
                return this.memory.retain(signed ? value : BigInt.asUintN(64, value));
            },
            swjs_bigint_to_i64: (ref, signed) => {
                const object = this.memory.getObject(ref);
                if (typeof object !== "bigint") throw new Error(`Expected a BigInt, but got ${typeof object}`);
                if (signed) return object;
                if (object < BigInt(0)) return BigInt(0);
                return BigInt.asIntN(64, object);
            },
            swjs_i64_to_bigint_slow: (lower, upper, signed) => {
                const value = BigInt.asUintN(32, BigInt(lower)) + (BigInt.asUintN(32, BigInt(upper)) << BigInt(32));
                return this.memory.retain(signed ? BigInt.asIntN(64, value) : BigInt.asUintN(64, value));
            },
            swjs_unsafe_event_loop_yield: () => { console.log('[swjs] unsafe_event_loop_yield called!'); throw new UnsafeEventLoopYield(); },
            swjs_send_job_to_main_thread: (unowned_job) => {
                this.postMessageToMainThread({ type: "job", data: unowned_job });
            },
            swjs_listen_message_from_main_thread: () => {
                const threadChannel = this.options.threadChannel;
                if (!(threadChannel && "listenMessageFromMainThread" in threadChannel)) {
                    throw new Error("listenMessageFromMainThread is not set in options.");
                }
                const broker = getMessageBroker(threadChannel);
                threadChannel.listenMessageFromMainThread((message) => {
                    switch (message.type) {
                        case "wake": this.exports.swjs_wake_worker_thread(); break;
                        case "request": broker.onReceivingRequest(message); break;
                        case "response": broker.onReceivingResponse(message); break;
                        default: throw new Error(`Unknown message type: ${message}`);
                    }
                });
            },
            swjs_wake_up_worker_thread: (tid) => {
                this.postMessageToWorkerThread(tid, { type: "wake" });
            },
            swjs_listen_message_from_worker_thread: (tid) => {
                const threadChannel = this.options.threadChannel;
                if (!(threadChannel && "listenMessageFromWorkerThread" in threadChannel)) {
                    throw new Error("listenMessageFromWorkerThread is not set in options.");
                }
                const broker = getMessageBroker(threadChannel);
                threadChannel.listenMessageFromWorkerThread(tid, (message) => {
                    switch (message.type) {
                        case "job": this.exports.swjs_enqueue_main_job_from_worker(message.data); break;
                        case "request": broker.onReceivingRequest(message); break;
                        case "response": broker.onReceivingResponse(message); break;
                        default: throw new Error(`Unknown message type: ${message}`);
                    }
                });
            },
            swjs_terminate_worker_thread: (tid) => {
                const threadChannel = this.options.threadChannel;
                if (threadChannel && "terminateWorkerThread" in threadChannel) {
                    threadChannel.terminateWorkerThread?.(tid);
                }
            },
            swjs_get_worker_thread_id: () => { return this.tid || -1; },
            swjs_request_sending_object: (sending_object, transferring_objects, transferring_objects_count, object_source_tid, sending_context) => {
                if (!this.options.threadChannel) throw new Error("threadChannel is not set.");
                const broker = getMessageBroker(this.options.threadChannel);
                const transferringObjects = decodeObjectRefs(transferring_objects, transferring_objects_count, this.getDataView());
                broker.request({
                    type: "request",
                    data: {
                        sourceTid: this.tid ?? MAIN_THREAD_TID,
                        targetTid: object_source_tid,
                        context: sending_context,
                        request: { method: "send", parameters: [sending_object, transferringObjects, sending_context] },
                    },
                });
            },
            swjs_request_sending_objects: (sending_objects, sending_objects_count, transferring_objects, transferring_objects_count, object_source_tid, sending_context) => {
                if (!this.options.threadChannel) throw new Error("threadChannel is not set.");
                const broker = getMessageBroker(this.options.threadChannel);
                const dataView = this.getDataView();
                const sendingObjects = decodeObjectRefs(sending_objects, sending_objects_count, dataView);
                const transferringObjects = decodeObjectRefs(transferring_objects, transferring_objects_count, dataView);
                broker.request({
                    type: "request",
                    data: {
                        sourceTid: this.tid ?? MAIN_THREAD_TID,
                        targetTid: object_source_tid,
                        context: sending_context,
                        request: { method: "sendObjects", parameters: [sendingObjects, transferringObjects, sending_context] },
                    },
                });
            },
        };
    }
    postMessageToMainThread(message, transfer = []) {
        const threadChannel = this.options.threadChannel;
        if (!(threadChannel && "postMessageToMainThread" in threadChannel)) {
            throw new Error("postMessageToMainThread is not set.");
        }
        threadChannel.postMessageToMainThread(message, transfer);
    }
    postMessageToWorkerThread(tid, message, transfer = []) {
        const threadChannel = this.options.threadChannel;
        if (!(threadChannel && "postMessageToWorkerThread" in threadChannel)) {
            throw new Error("postMessageToWorkerThread is not set.");
        }
        threadChannel.postMessageToWorkerThread(tid, message, transfer);
    }
}

// ============================================================
// BridgeJS runtime (stack-based ABI from JavaScriptKit 0.46.5)
// ============================================================

function createBJSRuntime(swift) {
    // Variable declarations matching BridgeJSLink generated code
    let memory;        // bound later via setInstance()
    const textDecoder = new TextDecoder("utf-8");
    const textEncoder = new TextEncoder("utf-8");
    let tmpRetString;
    let tmpRetBytes;
    let tmpRetException;
    let tmpRetOptionalBool;
    let tmpRetOptionalInt;
    let tmpRetOptionalFloat;
    let tmpRetOptionalDouble;
    let tmpRetOptionalHeapObject;
    let strStack = [];
    let i32Stack = [];
    let f32Stack = [];
    let f64Stack = [];
    let ptrStack = [];

    const bjs = {};

    // --- String / memory operations ---
    bjs["swift_js_return_string"] = function(ptr, len) {
        const bytes = new Uint8Array(memory.buffer, ptr, len);
        tmpRetString = textDecoder.decode(bytes);
    };
    bjs["swift_js_init_memory"] = function(sourceId, bytesPtr) {
        const source = swift.memory.getObject(sourceId);
        swift.memory.release(sourceId);
        const bytes = new Uint8Array(memory.buffer, bytesPtr);
        bytes.set(source);
    };
    bjs["swift_js_make_js_string"] = function(ptr, len) {
        const bytes = new Uint8Array(memory.buffer, ptr, len);
        return swift.memory.retain(textDecoder.decode(bytes));
    };
    bjs["swift_js_init_memory_with_result"] = function(ptr, len) {
        const target = new Uint8Array(memory.buffer, ptr, len);
        target.set(tmpRetBytes);
        tmpRetBytes = undefined;
    };

    // --- Exception / reference management ---
    bjs["swift_js_throw"] = function(id) {
        tmpRetException = swift.memory.retainByRef(id);
    };
    bjs["swift_js_retain"] = function(id) {
        return swift.memory.retainByRef(id);
    };
    bjs["swift_js_release"] = function(id) {
        swift.memory.release(id);
    };

    // --- Stack push operations ---
    bjs["swift_js_push_i32"] = function(v) {
        i32Stack.push(v | 0);
    };
    bjs["swift_js_push_f32"] = function(v) {
        f32Stack.push(Math.fround(v));
    };
    bjs["swift_js_push_f64"] = function(v) {
        f64Stack.push(v);
    };
    bjs["swift_js_push_string"] = function(ptr, len) {
        const bytes = new Uint8Array(memory.buffer, ptr, len);
        const value = textDecoder.decode(bytes);
        strStack.push(value);
    };
    bjs["swift_js_push_pointer"] = function(pointer) {
        ptrStack.push(pointer);
    };

    // --- Stack pop operations ---
    bjs["swift_js_pop_i32"] = function() {
        return i32Stack.pop();
    };
    bjs["swift_js_pop_f32"] = function() {
        return f32Stack.pop();
    };
    bjs["swift_js_pop_f64"] = function() {
        return f64Stack.pop();
    };
    bjs["swift_js_pop_pointer"] = function() {
        return ptrStack.pop();
    };

    // --- Optional return helpers ---
    bjs["swift_js_return_optional_bool"] = function(isSome, value) {
        if (isSome === 0) {
            tmpRetOptionalBool = null;
        } else {
            tmpRetOptionalBool = value !== 0;
        }
    };
    bjs["swift_js_return_optional_int"] = function(isSome, value) {
        if (isSome === 0) {
            tmpRetOptionalInt = null;
        } else {
            tmpRetOptionalInt = value | 0;
        }
    };
    bjs["swift_js_return_optional_float"] = function(isSome, value) {
        if (isSome === 0) {
            tmpRetOptionalFloat = null;
        } else {
            tmpRetOptionalFloat = Math.fround(value);
        }
    };
    bjs["swift_js_return_optional_double"] = function(isSome, value) {
        if (isSome === 0) {
            tmpRetOptionalDouble = null;
        } else {
            tmpRetOptionalDouble = value;
        }
    };
    bjs["swift_js_return_optional_string"] = function(isSome, ptr, len) {
        if (isSome === 0) {
            tmpRetString = null;
        } else {
            const bytes = new Uint8Array(memory.buffer, ptr, len);
            tmpRetString = textDecoder.decode(bytes);
        }
    };
    bjs["swift_js_return_optional_object"] = function(isSome, objectId) {
        if (isSome === 0) {
            tmpRetString = null;
        } else {
            tmpRetString = swift.memory.getObject(objectId);
        }
    };
    bjs["swift_js_return_optional_heap_object"] = function(isSome, pointer) {
        if (isSome === 0) {
            tmpRetOptionalHeapObject = null;
        } else {
            tmpRetOptionalHeapObject = pointer;
        }
    };

    // --- Optional getter helpers ---
    bjs["swift_js_get_optional_int_presence"] = function() {
        return tmpRetOptionalInt != null ? 1 : 0;
    };
    bjs["swift_js_get_optional_int_value"] = function() {
        const value = tmpRetOptionalInt;
        tmpRetOptionalInt = undefined;
        return value;
    };
    bjs["swift_js_get_optional_string"] = function() {
        const str = tmpRetString;
        tmpRetString = undefined;
        if (str == null) {
            return -1;
        } else {
            const bytes = textEncoder.encode(str);
            tmpRetBytes = bytes;
            return bytes.length;
        }
    };
    bjs["swift_js_get_optional_float_presence"] = function() {
        return tmpRetOptionalFloat != null ? 1 : 0;
    };
    bjs["swift_js_get_optional_float_value"] = function() {
        const value = tmpRetOptionalFloat;
        tmpRetOptionalFloat = undefined;
        return value;
    };
    bjs["swift_js_get_optional_double_presence"] = function() {
        return tmpRetOptionalDouble != null ? 1 : 0;
    };
    bjs["swift_js_get_optional_double_value"] = function() {
        const value = tmpRetOptionalDouble;
        tmpRetOptionalDouble = undefined;
        return value;
    };
    bjs["swift_js_get_optional_heap_object_pointer"] = function() {
        const pointer = tmpRetOptionalHeapObject;
        tmpRetOptionalHeapObject = undefined;
        return pointer || 0;
    };

    // --- Closure management (no-op default) ---
    bjs["swift_js_closure_unregister"] = function(funcRef) {};

    return {
        imports: bjs,
        setInstance: (instance) => {
            memory = instance.exports.memory;
        },
    };
}

// ============================================================
// WASI implementation
// ============================================================

function createWASI(getMemory) {
    // ENOSYS=52, EBADF=8
    return {
        // Arguments
        args_get: () => 0,
        args_sizes_get: (argc, argvBufSize) => {
            const view = new DataView(getMemory().buffer);
            view.setUint32(argc, 0, true);
            view.setUint32(argvBufSize, 0, true);
            return 0;
        },

        // Environment
        environ_get: () => 0,
        environ_sizes_get: (environc, environBufSize) => {
            const view = new DataView(getMemory().buffer);
            view.setUint32(environc, 0, true);
            view.setUint32(environBufSize, 0, true);
            return 0;
        },

        // Clock
        clock_res_get: (clockId, resolution) => {
            const view = new DataView(getMemory().buffer);
            view.setBigUint64(resolution, 1000000n, true);
            return 0;
        },
        clock_time_get: (clockId, precision, timestamp) => {
            const view = new DataView(getMemory().buffer);
            const now = BigInt(Date.now()) * 1000000n;
            view.setBigUint64(timestamp, now, true);
            return 0;
        },

        // File descriptor operations
        fd_close: () => 0,
        fd_fdstat_get: (fd, statBuf) => {
            // Write fdstat struct: filetype(u8) + flags(u16) + rights_base(u64) + rights_inheriting(u64)
            const view = new DataView(getMemory().buffer);
            // filetype: 2 = character device (stdout/stderr)
            view.setUint8(statBuf, fd <= 2 ? 2 : 4);
            // fdflags: 1 = append for stdout/stderr
            view.setUint16(statBuf + 2, fd <= 2 ? 1 : 0, true);
            // rights_base: all rights
            view.setBigUint64(statBuf + 8, BigInt("0xFFFFFFFFFFFFFFFF"), true);
            // rights_inheriting: all rights
            view.setBigUint64(statBuf + 16, BigInt("0xFFFFFFFFFFFFFFFF"), true);
            return 0;
        },
        fd_filestat_get: () => 8,
        fd_filestat_set_size: () => 8,
        fd_pread: () => 8,
        fd_prestat_get: () => 8,
        fd_prestat_dir_name: () => 8,
        fd_read: () => 0,
        fd_readdir: () => 8,
        fd_seek: () => 0,
        fd_sync: () => 0,
        fd_tell: () => 8,
        fd_write: (fd, iovs, iovsLen, nwritten) => {
            const memory = getMemory();
            if (fd === 1 || fd === 2) {
                let text = '';
                let totalBytes = 0;
                const view = new DataView(memory.buffer);
                for (let i = 0; i < iovsLen; i++) {
                    const offset = iovs + i * 8;
                    const buf = view.getUint32(offset, true);
                    const bufLen = view.getUint32(offset + 4, true);
                    totalBytes += bufLen;
                    const bytes = new Uint8Array(memory.buffer, buf, bufLen);
                    text += new TextDecoder().decode(bytes);
                }
                console.log(`[fd_write] fd=${fd} iovsLen=${iovsLen} totalBytes=${totalBytes} text=${JSON.stringify(text)}`);
                if (fd === 1) { console.log(text); } else { console.error(text); }
                view.setUint32(nwritten, totalBytes, true);
                return 0;
            }
            return 8;
        },

        // Path operations
        path_create_directory: () => 8,
        path_filestat_get: () => 8,
        path_filestat_set_times: () => 8,
        path_link: () => 8,
        path_open: () => 8,
        path_readlink: () => 8,
        path_remove_directory: () => 8,
        path_rename: () => 8,
        path_symlink: () => 8,
        path_unlink_file: () => 8,

        // Poll
        poll_oneoff: () => 0,

        // Process
        proc_exit: (code) => {
            console.log(`Process exited with code: ${code}`);
            throw new Error(`WASM process exited: ${code}`);
        },

        // Random
        random_get: (buf, bufLen) => {
            const bytes = new Uint8Array(getMemory().buffer, buf, bufLen);
            crypto.getRandomValues(bytes);
            return 0;
        },
    };
}

// ============================================================
// Main loader
// ============================================================

/**
 * Start the WASM application
 * @returns {Promise<void>}
 */
export async function startWasmApp() {
    console.log('Loading WASM binary...');

    // Catch unhandled promise rejections from microtask callbacks
    // (e.g. promise.then inside JavaScriptEventLoop's job queue)
    window.addEventListener('unhandledrejection', (event) => {
        if (event.reason instanceof UnsafeEventLoopYield) {
            // Expected: async main yielding control to JS event loop
            console.log('[event-loop] UnsafeEventLoopYield caught in promise — this is expected');
            event.preventDefault();
            return;
        }
        console.error('[unhandledrejection] Promise rejected:', event.reason);
    });

    try {
        // Create SwiftRuntime instance
        const swift = new SwiftRuntime();

        // Create BridgeJS runtime (memory bound after instantiation)
        const bjsRuntime = createBJSRuntime(swift);

        // Memory accessor — resolved after instantiation from WASM exports
        let resolvedMemory = null;
        const getMemory = () => resolvedMemory;

        // Build import object with all required namespaces
        const importObject = {
            javascript_kit: swift.wasmImports,
            bjs: bjsRuntime.imports,
            wasi_snapshot_preview1: createWASI(getMemory),
        };

        // Use streaming instantiation — compiles while downloading (much faster for large binaries)
        console.log('Fetching & compiling WASM module (streaming)...');
        const response = fetch('BulletinBoard.wasm');
        const wasmModule = await WebAssembly.instantiateStreaming(response, importObject);
        wasmInstance = wasmModule.instance;

        // Get memory exported by WASM (not manually created)
        resolvedMemory = wasmInstance.exports.memory;
        wasmMemory = resolvedMemory;

        console.log('WASM module instantiated');

        // Wire up JavaScriptKit runtime and BridgeJS runtime
        console.log('[startup] calling setInstance...');
        swift.setInstance(wasmInstance);
        console.log('[startup] setInstance done');
        bjsRuntime.setInstance(wasmInstance);
        console.log('[startup] bjsRuntime.setInstance done');

        // Start the application
        if (typeof wasmInstance.exports._start === 'function') {
            // Command ABI: _start calls _initialize + main
            console.log('[startup] using command ABI (_start)');
            try {
                wasmInstance.exports._start();
            } catch (e) {
                if (e instanceof swift.UnsafeEventLoopYield) { console.log('[startup] _start threw UnsafeEventLoopYield (expected)'); }
                else if (e.message && e.message.includes('WASM process exited: 0')) { console.log('[startup] _start threw proc_exit(0)'); }
                else throw e;
            }
        } else {
            // Reactor ABI: call _initialize, then main
            console.log('[startup] using reactor ABI (_initialize + main)');
            if (typeof wasmInstance.exports._initialize === 'function') {
                console.log('[startup] calling _initialize...');
                wasmInstance.exports._initialize();
                console.log('[startup] _initialize done');
            }
            console.log('[startup] calling swift.main()...');
            swift.main();
            console.log('[startup] swift.main() done');
        }

        console.log('Bulletin Board started successfully');

        // Diagnostic: Check if JS microtasks and event loop work after WASM startup
        Promise.resolve().then(() => {
            console.log('[diag] Promise microtask fired — JS event loop is working');
        });
        queueMicrotask(() => {
            console.log('[diag] queueMicrotask fired — microtask queue is working');
        });
        setTimeout(() => {
            console.log('[diag] setTimeout(0) fired — macro task queue is working');
            console.log('[diag] Checking if #app still has loading class...');
            const app = document.getElementById('app');
            if (app) {
                console.log('[diag] #app innerHTML:', app.innerHTML.substring(0, 200));
            }
        }, 100);

    } catch (error) {
        console.error('Failed to load WASM:', error);
        throw error;
    }
}

/**
 * Get the WASM instance (for debugging)
 * @returns {WebAssembly.Instance|null}
 */
export function getWasmInstance() {
    return wasmInstance;
}

/**
 * Get the WASM memory (for debugging)
 * @returns {WebAssembly.Memory|null}
 */
export function getWasmMemory() {
    return wasmMemory;
}
