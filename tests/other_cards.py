"""Verify every rule, mission letter, ship statistic and province route before export."""
from functools import partial
from http.server import SimpleHTTPRequestHandler,ThreadingHTTPServer
from pathlib import Path
import json,sys,threading
from playwright.sync_api import sync_playwright
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'reborn/carte'
class Quiet(SimpleHTTPRequestHandler):
    def log_message(self,*_):pass
server=ThreadingHTTPServer(('127.0.0.1',0),partial(Quiet,directory=str(ROOT)))
threading.Thread(target=server.serve_forever,daemon=True).start()
try:
    original=json.loads((ROOT/'data/carte.json').read_text());data=json.loads((OUT/'mazzi/data.json').read_text())
    for k,records in data['decks'].items():assert records==original[k]
    all_cards=[c for records in data['decks'].values() for c in records]+original['personaggi']
    assert len(all_cards)==140 and {c['nr'] for c in all_cards}==set(range(1,141))
    lookup={c['file']:(kind,c) for kind,records in data['decks'].items() for c in records}
    def value(c,path):
        for key in path.split('.'):c=c[key]
        return c
    with sync_playwright() as pw:
        browser=pw.chromium.launch(executable_path='/usr/bin/chromium',headless=True,args=['--no-sandbox','--disable-dev-shm-usage'])
        page=browser.new_page(viewport={'width':1360,'height':1260},device_scale_factor=2)
        errors=[];page.on('pageerror',lambda e:errors.append(str(e)))
        def load(path):
            page.goto(f'http://127.0.0.1:{server.server_port}/reborn/carte/'+path)
            page.wait_for_function('window.__decksReady===true',timeout=60000)
        def inspect(card):
            kind,c=lookup[card.get_attribute('data-file')];card.scroll_into_view_if_needed()
            for img in card.locator('img').all():
                if img.is_visible():img.evaluate('(im)=>im.decode()')
            metrics=card.evaluate('el=>({fits:el.dataset.fits,font:getComputedStyle(el).getPropertyValue("--rule-size"),scroll:el.querySelector(".rule-content").scrollHeight,available:el.querySelector(".rule-content").clientHeight})')
            assert metrics['fits']=='true',(c['file'],metrics)
            for element in card.locator('[data-field]').all():
                path=element.get_attribute('data-field');assert element.text_content()==str(value(c,path)),(c['file'],path)
            for path in (['it.descrizione','it.restrizioni','it.risultato','it.bonus'] if kind=='missione' else (['it.urbano.evento','it.speciale.evento','it.selvaggio.evento'] if kind=='azione' else ['it'])):
                if value(c,path):assert card.locator('[data-field="'+path+'"]').count()==1,(c['file'],path)
            if kind=='azione':
                for zone in ['urbano','speciale','selvaggio']:assert card.locator('[data-zone="'+zone+'"] .letter-chip text').all_text_contents()==c['en'][zone]['lettere']
            for token in card.locator('.letter-chip,.mission-letter').all():
                assert token.evaluate('el=>{const t=el.querySelector("text").getBoundingClientRect(),r=el.getBoundingClientRect();return Math.abs(t.x+t.width/2-r.x-r.width/2)<1&&Math.abs(t.y+t.height/2-r.y-r.height/2)<1}')
            if kind=='possessi' and c['tipo']=='astronave':
                assert card.locator('.ship-metric').count()==4
                for metric in card.locator('.ship-metric').all():
                    assert metric.bounding_box()['y']+metric.bounding_box()['height']<=card.locator('.ship-art').bounding_box()['y']+card.locator('.ship-art').bounding_box()['height']+1
            assert card.locator('.card-number').evaluate('el=>{const t=el.querySelector("text").getBoundingClientRect(),c=el.getBoundingClientRect();return Math.abs(t.x+t.width/2-c.x-c.width/2)<1&&Math.abs(t.y+t.height/2-c.y-c.height/2)<1}')
            return c
        load('prova-mazzi.html')
        for card in page.locator('.deck-card').all():inspect(card)
        print('Casi più lunghi dei cinque mazzi: testi completi e statistiche leggibili.',flush=True)
        style=page.add_style_tag(content='.card-download{display:none!important}')
        page.locator('.pair').screenshot(path=str(OUT/'esempi-mazzi.png'));style.evaluate('el=>el.remove()')
        load('mazzi.html');assert page.locator('.deck-card').count()==108
        for i,card in enumerate(page.locator('.deck-card').all(),1):
            c=inspect(card)
            if not sys.argv[1:] or card.get_attribute('data-kind') in sys.argv[1:]:card.screenshot(path=str(OUT/'mazzi'/(c['file']+'.png')))
            if i%20==0:print(f'{i}/108 carte verificate ed esportate',flush=True)
        for kind,records in data['decks'].items():
            page.select_option('#deck-filter',kind);assert page.locator('.card-item:visible').count()==len(records)
        page.select_option('#deck-filter','');page.locator('#deck-search').fill('Explorer');assert page.locator('.card-item:visible').count()==1
        for width in [1290,650,390,320]:
            page.set_viewport_size({'width':width,'height':844});load('prova-mazzi.html')
            assert page.evaluate('document.documentElement.scrollWidth<=innerWidth')
            for card in page.locator('.deck-card').all():assert card.get_attribute('data-fits')=='true'
        assert not errors,errors
        browser.close()
        print('108 carte: tutte le regole, lettere, valori, rotte, filtri, esportazioni e layout mobile OK.')
finally:server.shutdown()
