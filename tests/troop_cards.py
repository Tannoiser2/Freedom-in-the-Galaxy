"""Check all troop strengths, factions/environs, orbit switching, mobile and exports."""
from functools import partial
from http.server import SimpleHTTPRequestHandler,ThreadingHTTPServer
from pathlib import Path
import json,threading,sys
from playwright.sync_api import sync_playwright
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'reborn/truppe'
class Quiet(SimpleHTTPRequestHandler):
    def log_message(self,*_):pass
def main():
    records=json.loads((OUT/'data.json').read_text());rules=json.loads((ROOT/'data/regole_avanzate.json').read_text())['unita']
    assert len(records)==40 and len({c['key'] for c in records})==40
    assert sum(c['fazione']=='ribelli' for c in records)==30
    for c in records:
        assert c['rules']==rules[c['cat']]
        assert (c['terra'],c['spazio'])==(rules[c['cat']]['f'],rules[c['cat']]['s'])
        for field in ['ground','orbit']:assert (ROOT/'assets_reborn/truppe'/c[field]).is_file()
    server=ThreadingHTTPServer(('127.0.0.1',0),partial(Quiet,directory=str(ROOT)))
    threading.Thread(target=server.serve_forever,daemon=True).start()
    tokens=ROOT/'assets_reborn/truppe/pedine';tokens.mkdir(exist_ok=True)
    try:
        with sync_playwright() as pw:
            browser=pw.chromium.launch(executable_path='/usr/bin/chromium',headless=True,args=['--no-sandbox','--disable-dev-shm-usage'])
            page=browser.new_page(viewport={'width':1360,'height':1260},device_scale_factor=2)
            errors=[];page.on('pageerror',lambda e:errors.append(str(e)))
            url=f'http://127.0.0.1:{server.server_port}/reborn/truppe/'
            def load(suffix=''):
                page.goto(url+suffix);page.wait_for_function('window.__troopsReady===true')
            load()
            for i,c in enumerate(records):
                item=page.locator(f'[data-key="{c["key"]}"]');card=item.locator('.card')
                assert item.get_attribute('data-faction')==c['fazione']
                assert item.get_attribute('data-environ')==c['environ']
                for stat in ['terra','spazio']:assert card.locator(f'[data-stat="{stat}"] .stat-value').inner_text()==str(c[stat])
                for position in ['terra','orbita']:
                    page.evaluate('([key,pos])=>window.__troops.setPosition(document.querySelector(`[data-key="${key}"]`),pos)',[c['key'],position])
                    card.scroll_into_view_if_needed();card.locator('img').evaluate('im=>im.decode()')
                    assert card.get_attribute('data-position')==position
                    assert card.locator('img').get_attribute('src')=='assets/'+c['ground' if position=='terra' else 'orbit']
                    assert card.evaluate('el=>{const t=el.querySelector(".ability-text"),m=el.querySelector(".card-meta");return t.offsetTop+t.offsetHeight<m.offsetTop-8}') ,c['key']
                    if '--orbit-only' not in sys.argv or position=='orbita':
                        card.screenshot(path=str(OUT/'png'/f'{c["key"]}-{position}.png'))
                    if '--orbit-only' not in sys.argv:
                        card.evaluate('el=>el.classList.add("token")')
                        card.screenshot(path=str(tokens/f'{c["key"]}-{position}.png'))
                        card.evaluate('el=>el.classList.remove("token")')
                if (i+1)%10==0:print(f'{i+1}/40 unità: entrambe le posizioni e i valori verificati',flush=True)
            page.select_option('#faction-filter','ribelli');assert page.locator('.card-item:visible').count()==30
            page.select_option('#environ-filter','liquido');assert page.locator('.card-item:visible').count()==5
            page.select_option('#position-filter','orbita');assert page.locator('.card-item:visible .card[data-position="orbita"]').count()==5
            item=page.locator('.card-item:visible').first;item.locator('button').click();assert item.locator('.card').get_attribute('data-position')=='terra'
            page.select_option('#faction-filter','imperiali');page.select_option('#environ-filter','tutti');assert page.locator('.card-item:visible').count()==10
            for width in [650,390,320]:
                page.set_viewport_size({'width':width,'height':844});load('?unita=rib_liquido_10&posizione=orbita')
                assert page.locator('.card-item:visible').count()==1
                assert page.locator('.card-item:visible .card').get_attribute('data-position')=='orbita'
                assert page.evaluate('document.documentElement.scrollWidth<=innerWidth'),width
            load('?unita=imp_linea');page.set_viewport_size({'width':1360,'height':1260})
            # A compact comparison: same unit on the ground and in orbit.
            page.evaluate('''()=>{const item=document.querySelector('[data-key="imp_linea"]');const clone=item.cloneNode(true);clone.dataset.key='comparison';item.after(clone);window.__troops.setPosition(clone,'orbita');}''')
            for img in page.locator('.card-item:visible img').all():img.evaluate('im=>im.decode()')
            page.locator('.pair').screenshot(path=str(OUT/'confronto-terra-orbita.png'))
            assert not errors,errors
            browser.close()
    finally:server.shutdown()
    print('40 unità, 80 schede e 80 pedine: valori, immagini, filtri e layout mobile OK.')
if __name__=='__main__':main()
