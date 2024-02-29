#! env python3
from http.server import BaseHTTPRequestHandler, HTTPServer
import re
from urllib.parse import urlparse, parse_qs

VIDEO_NOTIFIER_PATH = '/tmp/{user}/ssuspend/browser.{uuid}'
USER_SCRIPTS="{script_root}/browser/user-scripts/{file}"

def marker(uuid : str, create : bool):
    from getpass import getuser
    import os
    from pathlib import Path
    path = VIDEO_NOTIFIER_PATH.format(user=getuser(), uuid=uuid)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    if create:
        Path(path).touch(exist_ok=True)
    elif os.path.exists(path):
        os.remove(path)



class Handler(BaseHTTPRequestHandler):

    def handle_video_request(self, state: bool|None, status: int):
        parsed = urlparse(self.path)
        parts = parsed.path.split("/")[1:]
        if len(parts) != 2 or parts[0] != 'video-notification':
            print(f"invalid path: {parsed.path} ({self.path})")
            return self.error(404)
        name = parts[1];
        if not re.match(r'^[0-9a-z-_]*$', name):
            print(f"invalid name: {name} ({self.path})")
            return self.error(404)
        sstate:bool = True
        if state == None:
            try:
                query = parse_qs(parsed.query)
                states = query['state'][0]
                if states == 'playing':
                    sstate = True
                elif states == 'stopped':
                    sstate = False
                else:
                    raise ValueError("Unknown value!")
            except KeyError as ke:
                print(f"invalid queries: ({self.path})")
                return self.error(status=404)
            except ValueError:
                print(f"invalid values: ({self.path})")
                return self.error(status=404)
        else:
            sstate=state


        marker(name, sstate)
        return self.process(status)


    def do_PUT(self):
        return self.handle_video_request(True, 201)


    def do_DELETE(self):
        self.handle_video_request(False, 204)

    def do_OPTIONS(self):
        self.send_response(200)
        parsed = urlparse(self.path)
        parts = parsed.path.split("/")[1:]
        if len(parts) == 2 and parts[0] == 'video-notification':
            self.send_header("Allow", "OPTIONS, DELETE, POST, PUT")
            self.send_header("Access-Control-Allow-Methods", "OPTIONS, POST, DELETE, PUT")
        elif len(parts) == 2 and parts[0] == 'user-scripts':
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


    def do_POST(self):
        return self.handle_video_request(None, 200)



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

