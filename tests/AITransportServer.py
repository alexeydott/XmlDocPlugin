import http.server,json,time,sys,pathlib
class Server(http.server.ThreadingHTTPServer):daemon_threads=True
class Handler(http.server.BaseHTTPRequestHandler):
 def log_message(self,*args):pass
 def do_POST(self):
  body=self.rfile.read(int(self.headers.get('Content-Length','0'))).decode('utf-8');data=json.loads(body)
  if self.headers.get('Authorization')!='Bearer test-key' or self.headers.get('Content-Type')!='application/json; charset=utf-8':self.send_error(400);return
  if self.path.endswith('/slow'):time.sleep(20)
  status=int(self.path.rsplit('/',1)[-1]) if self.path.rsplit('/',1)[-1].isdigit() else 200
  payload=json.dumps({'choices':[{'finish_reason':'stop','message':{'content':json.dumps({'summary':'Пример Unicode','uncertainties':[]},ensure_ascii=False)}}]},ensure_ascii=False).encode('utf-8')
  if self.path.endswith('/large'):payload=b'x'*1048576
  self.send_response(status);self.send_header('Content-Type','application/json; charset=utf-8');self.send_header('Content-Length',str(len(payload)));self.end_headers()
  try:self.wfile.write(payload)
  except (BrokenPipeError,ConnectionResetError):pass
server=Server(('127.0.0.1',0),Handler);pathlib.Path(sys.argv[1]).write_text(str(server.server_port));server.serve_forever()
