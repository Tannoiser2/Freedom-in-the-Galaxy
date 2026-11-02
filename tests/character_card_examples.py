"""Prove the longest cases first, then validate and export all character cards."""
from functools import partial
from http.server import SimpleHTTPRequestHandler,ThreadingHTTPServer
from pathlib import Path
import json,threading
from playwright.sync_api import sync_playwright
ROOT=Path(__file__).resolve().parents[1]
class Quiet(SimpleHTTPRequestHandler):
    def log_message(self,*_):pass
server=ThreadingHTTPServer(('127.0.0.1',0),partial(Quiet,directory=str(ROOT)))
threading.Thread(target=server.serve_forever,daemon=True).start()
try:
    records=json.loads((ROOT/'reborn/carte/data.json').read_text())
    assert records==json.loads((ROOT/'data/carte.json').read_text())['personaggi']
    with sync_playwright() as pw:
        browser=pw.chromium.launch(executable_path='/usr/bin/chromium',headless=True,args=['--no-sandbox','--disable-dev-shm-usage'])
        page=browser.new_page(viewport={'width':1360,'height':1260},device_scale_factor=2)
        errors=[];page.on('pageerror',lambda e:errors.append(str(e)))
        def load(path):
            page.goto(f'http://127.0.0.1:{server.server_port}/reborn/carte/'+path)
            page.wait_for_function('window.__cardsReady===true')
        def inspect(card,record):
            card.scroll_into_view_if_needed()
            card.locator('.figure').evaluate('(im)=>im.decode()')
            name=card.locator('.card-name').bounding_box();title=card.locator('.card-title').bounding_box();hero=card.locator('.hero').bounding_box()
            assert name['x']+name['width']<=card.bounding_box()['x']+375,record['nome']
            assert title['y']+title['height']<hero['y']-8,record['nome']
            figure=card.locator('.figure').bounding_box();ability=card.locator('.ability').bounding_box()
            assert figure['y']<hero['y']
            assert abs(figure['y']+figure['height']-ability['y'])<4
            assert card.locator('.card-number').evaluate('el=>{const t=el.querySelector("text").getBoundingClientRect(),c=el.getBoundingClientRect();return Math.abs(t.x+t.width/2-c.x-c.width/2)<1 && Math.abs(t.y+t.height/2-c.y-c.height/2)<1}')
            assert card.locator('.stat-icon svg').count()==6
            for stat in ['combattimento','resistenza','intelligenza','comando','diplomazia','navigazione']:
                assert card.locator('[data-stat="'+stat+'"] .stat-value').inner_text().split()[0]==str(record[stat])
            expected=record['speciale_it'] or 'Nessuna abilità speciale.'
            assert card.locator('.ability-text').inner_text()==expected
            role='Personaggio ribelle' if record['fazione']=='ribelli' else ('Cavaliere imperiale' if record['cavaliere_imperiale'] else 'Personaggio imperiale')
            assert card.locator('.card-meta span').first.inner_text()==role.upper()
            text=card.locator('.ability-text').bounding_box();meta=card.locator('.card-meta').bounding_box()
            assert text['y']+text['height']<=meta['y']-13,record['nome']
            assert card.locator('.ability-text').evaluate('(el)=>parseFloat(getComputedStyle(el).fontSize)')>=27
            assert card.locator('.card-name').inner_text()==record['nome'].upper()
        load('prova-limiti.html')
        proof=[max(records,key=lambda c:len(c['nome'])),max(records,key=lambda c:len(c['speciale_it'] or ''))]
        for card,record in zip(page.locator('.card').all(),proof):inspect(card,record)
        style=page.add_style_tag(content='.card-download{display:none!important}')
        page.locator('.pair').screenshot(path=str(ROOT/'reborn/carte/prova-limiti.png'));style.evaluate('el=>el.remove()')
        print('Prova superata: nome e abilità più lunghi, figure adattate, nessuna riga tagliata.',flush=True)
        load('')
        assert page.locator('.card').count()==32
        for card,record in zip(page.locator('.card').all(),records):
            inspect(card,record)
            slug=card.get_attribute('id')
            card.screenshot(path=str(ROOT/f'reborn/carte/{slug}.png'))
        page.locator('#card-search').fill('Zina');assert page.locator('.card-item:visible').count()==1
        page.locator('#card-search').fill('');page.select_option('#faction-filter','imperiali');assert page.locator('.card-item:visible').count()==12
        page.select_option('#faction-filter','ribelli');assert page.locator('.card-item:visible').count()==20
        page.select_option('#faction-filter','')
        page.evaluate("document.querySelectorAll('.card-item').forEach(el=>el.hidden=!['redjac','zina-adora'].includes(el.dataset.slug))")
        style=page.add_style_tag(content='.card-download{display:none!important}')
        page.locator('.pair').screenshot(path=str(ROOT/'reborn/carte/esempi-carte.png'));style.evaluate('el=>el.remove()')
        for width in [1360,1290,900,650,390]:
            page.set_viewport_size({'width':width,'height':844});page.wait_for_timeout(150)
            assert page.evaluate('document.documentElement.scrollWidth<=window.innerWidth'),width
        for width in [390,320]:
            page.set_viewport_size({'width':width,'height':844})
            load('prova-limiti.html')
            assert page.locator('.card').first.evaluate('el=>el.classList.contains("long-name")')
            for card in page.locator('.card').all():
                assert card.evaluate('el=>{const title=el.querySelector(".card-title"),head=el.querySelector(".card-top"),text=el.querySelector(".ability-text"),meta=el.querySelector(".card-meta");return title.offsetTop+title.offsetHeight<head.clientHeight-8 && text.offsetTop+text.offsetHeight<=meta.offsetTop-13}')
            assert page.evaluate('document.documentElement.scrollWidth<=window.innerWidth')
        assert not errors,errors
        browser.close()
        print('32 carte: dati esatti, sei icone, testi completi, numeri centrati, filtri e layout mobile OK.')
finally:server.shutdown()
