const fit=()=>document.querySelectorAll('.card-shell').forEach(el=>{if(el.clientWidth)el.style.setProperty('--card-scale',Math.min(1,el.clientWidth/600));});
new ResizeObserver(fit).observe(document.body);
fit();
document.fonts.ready.then(()=>{
  for(const card of document.querySelectorAll('.card')){
    const longName=card.querySelector('.card-name').offsetHeight>65;
    if(longName)card.classList.add('long-name');
    const text=card.querySelector('.ability-text'),meta=card.querySelector('.card-meta');
    for(let size=29;size>=27;size--){
      text.style.fontSize=size+'px';
      if(text.offsetTop+text.offsetHeight<=meta.offsetTop-14)break;
    }
    const t=card.querySelector('.card-number text'),b=t.getBBox();
    t.setAttribute('transform',`translate(${50-b.x-b.width/2} ${50-b.y-b.height/2})`);
  }
  const search=document.getElementById('card-search'),faction=document.getElementById('faction-filter');
  const params=new URLSearchParams(location.search);
  if(search)search.value=params.get('nome')||'';
  const applyFilter=()=>{
    let count=0;
    for(const item of document.querySelectorAll('.card-item')){
      const visible=(!search||item.dataset.name.includes(search.value.toLocaleLowerCase('it').trim()))&&(!faction||!faction.value||item.dataset.faction===faction.value)&&(!params.get('personaggio')||item.dataset.slug===params.get('personaggio'));
      item.hidden=!visible;if(visible)count++;
    }
    const label=document.getElementById('visible-count');if(label)label.textContent=count+(count===1?' carta':' carte');
    fit();
  };
  if(search)search.addEventListener('input',applyFilter);
  if(faction)faction.addEventListener('change',applyFilter);
  applyFilter();window.__cardsReady=true;
});
