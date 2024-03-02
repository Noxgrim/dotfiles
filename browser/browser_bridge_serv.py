#!/usr/bin/env python3
from http.server import BaseHTTPRequestHandler, HTTPServer
import re
from urllib.parse import urlparse

USER_SCRIPTS="{script_root}/browser/user-scripts/{file}"

class Handler(BaseHTTPRequestHandler):

    def do_OPTIONS(self):
        self.send_response(200)
        parsed = urlparse(self.path)
        parts = parsed.path.split("/")[1:]
        if len(parts) == 2 and parts[0] == 'user-scripts':
            self.send_header("Allow", "OPTIONS, GET")
            self.send_header("Access-Control-Allow-Methods", "OPTIONS, GET")
        else:
            self.send_header("Allow", "OPTIONS")
            self.send_header("Access-Control-Allow-Methods", "OPTIONS")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Max-Age", "86400")
        self.end_headers()
        self.wfile.write(bytes("", "utf-8"))

        return False


    def do_GET(self):
        import mimetypes, os
        parsed = urlparse(self.path)
        if not re.match(r'^[0-9A-Za-z-_/]*\.[0-9A-Za-z-_]+$', parsed.path):
            print(f"invalid path: ({self.path})")
            return self.error(message="Invalid path.")

        parts = parsed.path.split("/")[1:]
        if len(parts) == 2 and parts[0] == 'user-scripts':
            file = USER_SCRIPTS.format(script_root=os.environ["SCRIPT_ROOT"],
                                       file=parts[1])
            if not os.path.exists(file):
                return self.error(404)

            mime = mimetypes.guess_type(file)[0]
            with open(file, 'rb') as f:
                self.send_response(200)
                self.send_header("Content-Type", mime if mime is not None else "octet-stream")
                r = f.read()
                self.send_header("Content-Length", str(len(r)))
                self.send_header("Cache-Control", "no-cache")
                self.end_headers()
                self.wfile.write(r)
        else:
            return self.send_error(404)


    def error(self, status:int=400, ctype:str="text/plain", message:str=""):
        self.send_error(status)
        self.send_header("Content-type", ctype)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(bytes(message, "utf-8"))
        return False


    def process(self, status:int=400, ctype:str="text/plain", message:str=""):
        self.send_response(status)
        self.send_header("Content-type", ctype)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(bytes(message, "utf-8"))
        return False

if __name__ == "__main__":
    server = HTTPServer(("localhost", 8023), Handler)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass

    server.server_close()

