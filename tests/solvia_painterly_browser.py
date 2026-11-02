import sys,threading,json
from functools import partial
from http.server import ThreadingHTTPServer,SimpleHTTPRequestHandler
from playwright.sync_api import sync_playwright
from pathlib import Path
root=Path(__file__).resolve().parents[1]
class Quiet(SimpleHTTPRequestHandler):
 def log_message(self,*a):pass
server=ThreadingHTTPServer(('127.0.0.1',0),partial(Quiet,directory=str(root)));threading.Thread(target=server.serve_forever,daemon=True).start()
try:
 with sync_playwright() as p:
  browser=p.chromium.launch(executable_path='/usr/bin/chromium',headless=True,args=['--no-sandbox','--use-angle=swiftshader','--enable-unsafe-swiftshader','--disable-dev-shm-usage'])
  page=browser.new_page(viewport={'width':1500,'height':1000},device_scale_factor=1);errors=[];page.on('pageerror',lambda e:errors.append(str(e)))
  page.goto(f'http://127.0.0.1:{server.server_port}/reborn/atlante/?planet=432&skin=painterly&isolated=1');page.wait_for_selector('body[data-ready="true"]',timeout=60000);page.click('#pause');page.click('#focus');page.wait_for_timeout(1500)
  snap=page.evaluate('window.__atlas.snapshot()');assert snap['selected']==432 and snap['objects'][0]['buildings']==0 and not snap['objects'][0]['units'];assert not errors,errors
  page.screenshot(path=str(root/'reborn/anteprime/solvia_pittorica.png'));print(json.dumps(snap))
  page.select_option('#skin-select','original');page.wait_for_timeout(1500);assert page.evaluate('window.__atlas.snapshot().objects[0].buildings')>0
  page.select_option('#skin-select','painterly');page.wait_for_timeout(1500);assert page.evaluate('window.__atlas.snapshot().objects[0].buildings')==0;assert not errors,errors
  browser.close()
finally:server.shutdown()
