const fitDecks=()=>document.querySelectorAll('.card-shell').forEach(el=>{if(el.clientWidth)el.style.setProperty('--card-scale',Math.min(1,el.clientWidth/600));});
new ResizeObserver(fitDecks).observe(document.body);fitDecks();
document.fonts.ready.then(()=>{
 for(const card of document.querySelectorAll('.deck-card')){
  const content=card.querySelector('.rule-content'),art=card.querySelector('.deck-art');
  const start=card.dataset.kind==='evento'||card.dataset.kind==='possessi'?28:26;
  const min=Number(card.dataset.minFont);
  const initialArt=art?Number(art.dataset.artHeight):0,minArt=art?Number(art.dataset.artMin):0;
  if(art)art.style.height=initialArt+'px';
  let fits=false;
  for(let size=start;size>=min&&!fits;size--){
   card.style.setProperty('--rule-size',size+'px');
   for(let height=initialArt;height>=minArt;height-=10){
    if(art){art.style.height=height+'px';art.style.display=height===0?'none':'';}
    if(content.scrollHeight<=content.clientHeight+1){fits=true;break;}
    if(!art)break;
   }
  }
  card.dataset.fits=String(fits);
  const t=card.querySelector('.card-number text');let b=t.getBBox();
  if(b.width>72){t.style.fontSize=(50*72/b.width)+'px';b=t.getBBox();}
  t.setAttribute('transform',`translate(${50-b.x-b.width/2} ${50-b.y-b.height/2})`);
  for(const text of card.querySelectorAll('.letter-chip text,.mission-letter text')){const box=text.getBBox();text.setAttribute('transform',`translate(${24-box.x-box.width/2} ${24-box.y-box.height/2})`);}
 }
 const search=document.getElementById('deck-search'),select=document.getElementById('deck-filter');
 const params=new URLSearchParams(location.search);if(search)search.value=params.get('nome')||'';if(select)select.value=params.get('mazzo')||'';
 const apply=()=>{let count=0;for(const item of document.querySelectorAll('.card-item')){const nr=item.querySelector('.card-number text').textContent;item.hidden=!!((search&&!item.dataset.name.includes(search.value.toLowerCase().trim())&&!nr.includes(search.value.trim()))||(select&&select.value&&item.dataset.deck!==select.value)||(params.get('carta')&&params.get('carta')!==item.dataset.slug));if(!item.hidden)count++;}const label=document.getElementById('deck-count');if(label)label.textContent=count+' carte';fitDecks();};
 if(search)search.addEventListener('input',apply);if(select)select.addEventListener('change',apply);apply();window.__decksReady=true;
});
