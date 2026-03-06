/**
 * WASM Loader for Bulletin Board
 * Loads and initializes the Swift WebAssembly binary
 */

let wasmInstance = null;
let wasmMemory = null;

/**
 * Start the WASM application
 * @returns {Promise<void>}
 */
export async function startWasmApp() {
    console.log('📦 Loading WASM binary...');

    try {
        // Fetch and instantiate WASM
        const response = await fetch('BulletinBoard.wasm');
        if (!response.ok) {
            throw new Error(`Failed to fetch WASM: ${response.status} ${response.statusText}`);
        }

        const wasmBytes = await response.arrayBuffer();
        console.log(`✅ WASM binary loaded (${(wasmBytes.byteLength / 1024 / 1024).toFixed(2)} MB)`);

        // Create memory instance for WASM
        wasmMemory = new WebAssembly.Memory({
            initial: 256,  // 16 MB
            maximum: 16384 // 1 GB
        });

        // Import objects for WASM
        const importObject = {
            env: {
                memory: wasmMemory
            },
            wasi_snapshot_preview1: createWASI()
        };

        console.log('🔧 Instantiating WASM module...');
        const wasmModule = await WebAssembly.instantiate(wasmBytes, importObject);
        wasmInstance = wasmModule.instance;

        console.log('✅ WASM module instantiated');

        // Initialize WASI and start the application
        if (wasmInstance.exports._start) {
            wasmInstance.exports._start();
            console.log('🚀 Bulletin Board started successfully');
        } else if (wasmInstance.exports._initialize) {
            wasmInstance.exports._initialize();
            console.log('🚀 Bulletin Board initialized');
        } else {
            console.warn('⚠️ No _start or _initialize export found, WASM loaded but not executed');
        }

    } catch (error) {
        console.error('❌ Failed to load WASM:', error);
        throw error;
    }
}

/**
 * Create minimal WASI implementation
 * @returns {Object} WASI import object
 */
function createWASI() {
    return {
        // File descriptor operations
        fd_write: (fd, iovs, iovsLen, nwritten) => {
            if (fd === 1 || fd === 2) { // stdout or stderr
                let text = '';
                const view = new DataView(wasmMemory.buffer);
                for (let i = 0; i < iovsLen; i++) {
                    const offset = iovs + i * 8;
                    const buf = view.getUint32(offset, true);
                    const bufLen = view.getUint32(offset + 4, true);
                    const bytes = new Uint8Array(wasmMemory.buffer, buf, bufLen);
                    text += new TextDecoder().decode(bytes);
                }
                if (fd === 1) {
                    console.log(text);
                } else {
                    console.error(text);
                }
                view.setUint32(nwritten, text.length, true);
                return 0; // Success
            }
            return 8; // EBADF
        },

        fd_read: () => 0,
        fd_close: () => 0,
        fd_seek: () => 0,
        fd_fdstat_get: () => 0,
        fd_fdstat_set_flags: () => 0,
        fd_prestat_get: () => 8, // EBADF
        fd_prestat_dir_name: () => 8,

        // Path operations
        path_open: () => 8,
        path_filestat_get: () => 8,
        path_create_directory: () => 8,
        path_remove_directory: () => 8,
        path_unlink_file: () => 8,

        // Process operations
        proc_exit: (code) => {
            console.log(`Process exited with code: ${code}`);
            throw new Error(`WASM process exited: ${code}`);
        },

        // Environment
        environ_sizes_get: (environc, environBufSize) => {
            const view = new DataView(wasmMemory.buffer);
            view.setUint32(environc, 0, true);
            view.setUint32(environBufSize, 0, true);
            return 0;
        },
        environ_get: () => 0,

        // Clock
        clock_time_get: (clockId, precision, timestamp) => {
            const view = new DataView(wasmMemory.buffer);
            const now = BigInt(Date.now()) * 1000000n; // Convert to nanoseconds
            view.setBigUint64(timestamp, now, true);
            return 0;
        },

        // Random
        random_get: (buf, bufLen) => {
            const bytes = new Uint8Array(wasmMemory.buffer, buf, bufLen);
            crypto.getRandomValues(bytes);
            return 0;
        },

        // Arguments
        args_sizes_get: (argc, argvBufSize) => {
            const view = new DataView(wasmMemory.buffer);
            view.setUint32(argc, 0, true);
            view.setUint32(argvBufSize, 0, true);
            return 0;
        },
        args_get: () => 0,

        // Polling (stub)
        poll_oneoff: () => 0,

        // Socket operations (stubs)
        sock_accept: () => 58, // ENOSYS
        sock_recv: () => 58,
        sock_send: () => 58,
        sock_shutdown: () => 58,
    };
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
