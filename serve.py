#!/usr/bin/env python3
"""Simple HTTP server with WASM MIME type and COOP/COEP headers for WebGPU."""
import http.server
import os

class WASMHandler(http.server.SimpleHTTPRequestHandler):
    extensions_map = {
        **http.server.SimpleHTTPRequestHandler.extensions_map,
        '.wasm': 'application/wasm',
        '.js': 'application/javascript',
    }

    def end_headers(self):
        # Required for SharedArrayBuffer / WebGPU
        self.send_header('Cross-Origin-Opener-Policy', 'same-origin')
        # Use 'credentialless' instead of 'require-corp' so cross-origin
        # fetch() for RSS feeds works without CORP headers on the remote server
        self.send_header('Cross-Origin-Embedder-Policy', 'credentialless')
        super().end_headers()

os.chdir(os.path.join(os.path.dirname(__file__), 'Public'))
server = http.server.HTTPServer(('localhost', 8080), WASMHandler)
print('Serving at http://localhost:8080')
server.serve_forever()
