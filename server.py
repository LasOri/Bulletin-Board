#!/usr/bin/env python3
"""
Local HTTP server for testing WASM with required headers.
Serves files from Public/ directory with proper MIME types and COOP/COEP headers.
"""
import http.server
import socketserver
import os

PORT = 8888

class WASMHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory="Public", **kwargs)

    def end_headers(self):
        # Add COOP/COEP headers for SharedArrayBuffer support
        self.send_header('Cross-Origin-Opener-Policy', 'same-origin')
        self.send_header('Cross-Origin-Embedder-Policy', 'require-corp')
        self.send_header('Cross-Origin-Resource-Policy', 'cross-origin')
        super().end_headers()

    def guess_type(self, path):
        mimetype = super().guess_type(path)
        if path.endswith('.wasm'):
            return 'application/wasm'
        return mimetype

with socketserver.TCPServer(("", PORT), WASMHandler) as httpd:
    print(f"Server running at http://localhost:{PORT}/")
    print("Press Ctrl+C to stop")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down server...")
