/* CoachFlow Mobile Home 4.6 — Agenda de hoje
   Fonte de verdade: `horarios` (agenda recorrente do dia da semana) cruzada com `aulas` (exceções do dia)
   + movimentações financeiras do dia. Lê pelo MESMO cliente autenticado e pela MESMA verificação de sessão
   do desktop (adcSupabase / adcEnsureSessionV2), então mobile e desktop enxergam as mesmas linhas.
   Estados explícitos: carregando / ok / vazio / erro. Erro NUNCA vira "nenhuma aula hoje". */
(function(){
'use strict';
if(window.__cfm4Started)return;window.__cfm4Started=true;
const MQ='(max-width:760px)';
const mobile=()=>matchMedia(MQ).matches;
const money=v=>new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL'}).format(Number(v)||0);
const esc=v=>String(v??'').replace(/[&<>"']/g,m=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#039;'}[m]));
const pad=n=>String(n).padStart(2,'0');
const hh=v=>String(v||'').slice(0,5);
// Data e dia da semana SEMPRE no fuso local do aparelho (nunca toISOString/UTC): quinta no Brasil continua quinta.
const isoOf=d=>d.getFullYear()+'-'+pad(d.getMonth()+1)+'-'+pad(d.getDate());
const dayCode=d=>['DOM','SEG','TER','QUA','QUI','SEX','SAB'][d.getDay()];
const dateFromIso=s=>{const p=String(s).split('-').map(Number);return new Date(p[0],p[1]-1,p[2])};
const brShort=s=>{const m=/^(\d{4})-(\d{2})-(\d{2})/.exec(String(s||''));return m?m[3]+'/'+m[2]:''};
const home=()=>document.getElementById('inicio')||document.querySelector('[data-page="inicio"]');

function css(){if(document.getElementById('cfm4Style'))return;const s=document.createElement('style');s.id='cfm4Style';s.textContent=`
#cfm4Today,#cfm4DayModal{display:none}
@media(max-width:760px){
.cfHome2Grid{display:none!important}
.cfHome2Kpis{grid-template-columns:1fr 1fr!important}
.cfHome2Kpis .cfHCard.expenses{display:none!important}
.cfHome2Kpis .cfHCard{grid-column:auto!important;min-height:78px!important}
.cfHome2Kpis .cfHSub{display:none!important}
.cfHome2Kpis .cfHValue{font-size:18px!important}
.cfHome2Kpis .cfHLabel{font-size:9px!important}
.cfHome2Head{margin-bottom:9px!important}
.cfHome2Head h2{font-size:18px!important}
#cfm4Today{display:block;margin-top:9px;background:#fff;border:1px solid #e7ded7;border-radius:15px;overflow:hidden}
.cfm4TodayHead{display:flex;align-items:center;justify-content:space-between;padding:13px 14px;border-bottom:1px solid #eee7e2;cursor:pointer}
.cfm4TodayHead h3{margin:0;color:#241a15;font-size:15px}
.cfm4TodayHead p{margin:3px 0 0;color:#877970;font-size:10.5px}
.cfm4OpenDay{border:0!important;background:#f6f2ef!important;color:#55473f!important;border-radius:10px!important;padding:8px 10px!important;font-size:11px!important;font-weight:800!important}
.cfm4List{padding:4px 12px}
.cfm4Item{display:grid;grid-template-columns:48px minmax(0,1fr) auto;align-items:center;gap:9px;padding:10px 1px;border-bottom:1px solid #f0ebe7}
.cfm4Item:last-child{border-bottom:0}
.cfm4Time{font-size:11px;font-weight:850;color:#8a7b72}
.cfm4Main{min-width:0}
.cfm4Title{font-size:13px;font-weight:800;color:#2a211c;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.cfm4Meta{font-size:10px;color:#8b7e76;margin-top:3px}
.cfm4Tag{font-size:9px;font-weight:850;text-transform:uppercase;border-radius:999px;padding:5px 7px;white-space:nowrap}
.cfm4Tag.app{background:#edf4ff;color:#315f9b}
.cfm4Tag.cancel{background:#f5f1ef;color:#8a7b72}
.cfm4Tag.in{background:#edf8f1;color:#237a4b}
.cfm4Tag.out{background:#fff4df;color:#8a5a00}
.cfm4Empty{padding:24px 14px;text-align:center;color:#887b73;font-size:12px}
.cfm4Empty b{display:block;color:#332821;font-size:14px;margin-bottom:4px}
.cfm4Err{padding:18px 14px;text-align:center;color:#8a3b1f;font-size:12px;line-height:1.4}
.cfm4Err b{display:block;color:#5c2410;font-size:14px;margin-bottom:4px}
.cfm4Err span{display:block;color:#8b7e76;font-size:11px;overflow-wrap:anywhere}
.cfm4Retry{margin-top:10px;border:1px solid #ded5cf!important;background:#fff!important;border-radius:10px!important;padding:8px 14px!important;font-size:12px!important;font-weight:800!important;color:#51443c!important}
.cfm4Mov{display:grid;grid-template-columns:1fr 1fr;gap:8px;padding:10px 12px 12px;border-top:1px solid #eee7e2;background:#fcfbfa;cursor:pointer}
.cfm4MovTitle{grid-column:1/-1;font-size:10px;font-weight:850;text-transform:uppercase;letter-spacing:.05em;color:#8a7d75}
.cfm4MovBox{background:#fff;border:1px solid #ece4de;border-radius:11px;padding:9px 10px}
.cfm4MovBox span{display:block;font-size:9px;font-weight:850;text-transform:uppercase;color:#8a7d75}
.cfm4MovBox b{display:block;margin-top:3px;font-size:14px;color:#2a211c}
.cfm4MovBox.in b{color:#237a4b}
.cfm4MovBox.out b{color:#8a5a00}
.cfm4MovErr{grid-column:1/-1;font-size:11px;color:#8a3b1f;overflow-wrap:anywhere}
#cfm4DayModal.open{display:flex;position:fixed;z-index:10050;inset:0;background:rgba(30,20,15,.4);align-items:flex-end}
.cfm4DayCard{width:100%;max-height:88vh;overflow:auto;background:#f8f6f4;border-radius:24px 24px 0 0;padding:10px 14px calc(20px + env(safe-area-inset-bottom));box-sizing:border-box}
.cfm4Grab{width:42px;height:5px;background:#d9d1cb;border-radius:99px;margin:2px auto 13px}
.cfm4DayHead{display:flex;justify-content:space-between;padding:0 2px 14px}
.cfm4DayHead h2{margin:0;font-size:21px;color:#241a15}
.cfm4DayHead p{margin:4px 0 0;font-size:11px;color:#83766e}
.cfm4Close{width:40px;height:40px;border:0!important;background:#fff!important;border-radius:12px!important;font-size:20px!important}
.cfm4Summary{display:grid;grid-template-columns:repeat(3,1fr);gap:7px;margin-bottom:12px}
.cfm4Summary div{background:#fff;border:1px solid #e9e1db;border-radius:12px;padding:10px 8px;text-align:center}
.cfm4Summary b{display:block;font-size:17px;color:#2c221d}
.cfm4Summary span{font-size:9px;color:#8a7d75;text-transform:uppercase;font-weight:800}
.cfm4Group{background:#fff;border:1px solid #e9e1db;border-radius:15px;margin-bottom:9px;overflow:hidden}
.cfm4GroupTitle{padding:11px 13px;background:#fcfbfa;border-bottom:1px solid #eee8e3;font-size:11px;text-transform:uppercase;font-weight:850;color:#75675f}
.cfm4Group .cfm4Item{margin:0 12px}
.cfm4CalFull{width:100%;margin-top:4px;min-height:44px;border:1px solid #ded5cf!important;background:#fff!important;border-radius:12px!important;color:#51443c!important;font-size:12px!important;font-weight:800!important}
}`;document.head.appendChild(s)}

/* ---------- acesso ao banco: o mesmo cliente/sessão do desktop ---------- */
// `adcSupabase` é um `let` global do index.html: NÃO existe como window.adcSupabase, mas é visível por nome
// para os demais scripts clássicos da página.
function client(){try{return typeof adcSupabase!=='undefined'&&adcSupabase?adcSupabase:null}catch(_){return null}}
async function db(){
  const c=client();
  if(!c)throw new Error('Cliente Supabase indisponível. Entre no sistema e aguarde a sincronização.');
  if(typeof adcEnsureSessionV2==='function'&&!(await adcEnsureSessionV2()))throw new Error('Sessão expirada ou sem conexão. Toque em "Sair" e entre novamente.');
  const r=await c.auth.getSession();
  if(r.error)throw r.error;
  const owner=r.data&&r.data.session&&r.data.session.user&&r.data.session.user.id;
  if(!owner)throw new Error('Usuário autenticado não encontrado.');
  return {c,owner};
}
async function q(c,table,build){
  const r=await build(c.from(table));
  if(r.error){const e=new Error(table+': '+(r.error.message||String(r.error)));e.cause=r.error;throw e}
  return r.data||[];
}

/* ---------- regra da agenda ---------- */
function statusInfo(a){
  const s=String(a&&a.status||'agendada').toLowerCase();
  if(s.includes('cancel'))return {kind:'cancel',done:true,meta:'Cancelada'+(a.observacao?' · '+a.observacao:'')};
  if(s.includes('remarc'))return {kind:'cancel',done:true,label:'Remarcada',meta:'Remarcada'+(a.nova_data?' para '+brShort(a.nova_data):'')};
  if(s.includes('realiz'))return {kind:'app',done:true,label:'Realizada',meta:'Aula realizada'};
  return {kind:'app',done:false,meta:'Aula programada'};
}
function buildAgenda(slots,aulas,names){
  const nome=id=>names.get(String(id))||'Aluno';
  // Pode haver mais de uma linha em "aulas" para o mesmo aluno+horário (resquício de sincronizações antigas,
  // ex.: "agendada" e "cancelada" juntas). Vale a mais recente (maior id), a mesma regra do desktop em adcPullAllV2.
  const latest=new Map();
  (aulas||[]).forEach(a=>{const k=a.aluno_id+'|'+hh(a.hora_inicio),p=latest.get(k);if(!p||Number(a.id)>Number(p.id))latest.set(k,a)});
  const out=[],seen=new Set();
  // 1) agenda recorrente do dia da semana, já com a exceção do dia (cancelada, remarcada...) quando existir
  (slots||[]).forEach(s=>{
    const t=hh(s.hora_inicio),k=s.aluno_id+'|'+t;
    if(seen.has(k))return;seen.add(k);
    out.push(Object.assign({time:t,title:nome(s.aluno_id)},statusInfo(latest.get(k))));
  });
  // 2) aulas extraordinárias: registradas só em "aulas", sem horário recorrente correspondente
  latest.forEach((a,k)=>{
    if(seen.has(k))return;
    const t=hh(a.hora_inicio);
    if(t==='00:00')return; // 00:00 é o "sem horário" do app, não um atendimento real
    const info=statusInfo(a);
    out.push(Object.assign({time:t,title:nome(a.aluno_id)},info,{meta:info.meta==='Aula programada'?'Aula avulsa':info.meta}));
  });
  return out.sort((x,y)=>x.time.localeCompare(y.time));
}

/* ---------- carga (loading / ok / erro) ---------- */
const S={date:'',appsStatus:'loading',appsError:'',apps:[],finStatus:'loading',finError:'',ins:[],outs:[]};
async function loadApps(c,owner,date,dc,names){
  const [slots,aulas]=await Promise.all([
    q(c,'horarios',t=>t.select('id,aluno_id,dia_semana,hora_inicio,ativo').eq('owner_id',owner).eq('dia_semana',dc).eq('ativo',true).order('hora_inicio',{ascending:true})),
    q(c,'aulas',t=>t.select('id,aluno_id,data_aula,hora_inicio,status,observacao,nova_data').eq('owner_id',owner).eq('data_aula',date).order('hora_inicio',{ascending:true}))]);
  const items=buildAgenda(slots,aulas,names);
  console.info('CoachFlow agenda',{data:date,dia:dc,horarios:slots.length,aulas:aulas.length,alunos:names.size,itens:items.length});
  return items;
}
async function loadFin(c,owner,date,names){
  const gcols='id,data,descricao,valor,status_recebimento,recebido_em';
  const [desp,gData,gRec,pag]=await Promise.all([
    q(c,'despesas',t=>t.select('id,data,descricao,valor,omitida').eq('owner_id',owner).eq('data',date)),
    q(c,'ganhos_extras',t=>t.select(gcols).eq('owner_id',owner).eq('data',date)),
    q(c,'ganhos_extras',t=>t.select(gcols).eq('owner_id',owner).eq('recebido_em',date)),
    q(c,'pagamentos',t=>t.select('id,aluno_id,valor,data_pagamento,forma_pagamento').eq('owner_id',owner).eq('data_pagamento',date))]);
  const outs=desp.filter(x=>!x.omitida).map(x=>({time:'Hoje',title:x.descricao||'Despesa',meta:money(x.valor),kind:'out',done:false,amount:Number(x.valor)||0}));
  const gains=new Map();gData.concat(gRec).forEach(x=>gains.set(String(x.id),x));
  const ins=[];
  gains.forEach(x=>{const r=x.status_recebimento==='recebido';ins.push({time:'Hoje',title:x.descricao||'Ganho extra',meta:money(x.valor)+(r?' · Recebido':''),kind:'in',done:r,amount:Number(x.valor)||0})});
  pag.forEach(x=>ins.push({time:'Hoje',title:names.get(String(x.aluno_id))||'Recebimento',meta:money(x.valor)+' · Recebido'+(x.forma_pagamento?' · '+x.forma_pagamento:''),kind:'in',done:true,amount:Number(x.valor)||0}));
  console.info('CoachFlow financeiro hoje',{despesas:desp.length,despesasOmitidas:desp.length-outs.length,ganhos:gains.size,pagamentos:pag.length});
  return {ins,outs};
}
let inflight=null;
function load(why){
  if(!mobile())return Promise.resolve();
  if(inflight)return inflight;
  const now=new Date(),date=isoOf(now),dc=dayCode(now);
  if(S.date!==date)Object.assign(S,{date,appsStatus:'loading',appsError:'',apps:[],finStatus:'loading',finError:'',ins:[],outs:[]});
  paint();
  inflight=(async()=>{
    let c,owner,names;
    try{
      ({c,owner}=await db());
      names=new Map((await q(c,'Alunos',t=>t.select('id,nome,ativo').eq('owner_id',owner))).map(x=>[String(x.id),x.nome||'Aluno']));
    }catch(e){
      console.error('CoachFlow agenda: sem acesso ao banco ['+why+']',e);
      S.appsStatus=S.finStatus='error';S.appsError=S.finError=e.message||String(e);return;
    }
    const r=await Promise.allSettled([loadApps(c,owner,date,dc,names),loadFin(c,owner,date,names)]);
    if(r[0].status==='fulfilled'){S.apps=r[0].value;S.appsStatus='ok';S.appsError=''}
    else{console.error('CoachFlow agenda: falha ao ler horarios/aulas',r[0].reason);S.appsStatus='error';S.appsError=r[0].reason.message||String(r[0].reason)}
    if(r[1].status==='fulfilled'){S.ins=r[1].value.ins;S.outs=r[1].value.outs;S.finStatus='ok';S.finError=''}
    else{console.error('CoachFlow agenda: falha ao ler o financeiro do dia',r[1].reason);S.finStatus='error';S.finError=r[1].reason.message||String(r[1].reason)}
  })().finally(()=>{inflight=null;paint()});
  return inflight;
}

/* ---------- renderização (a partir do estado; não consulta nada) ---------- */
function itemHtml(x){
  const label=x.label||(x.kind==='app'?'Atendimento':x.kind==='cancel'?'Cancelada':x.kind==='in'?(x.done?'Recebido':'Receber'):(x.done?'Pago':'Pagar'));
  return '<div class="cfm4Item"'+(x.done?' style="opacity:.58"':'')+'><div class="cfm4Time">'+esc(x.time)+'</div><div class="cfm4Main"><div class="cfm4Title">'+esc(x.title)+'</div><div class="cfm4Meta">'+esc(x.meta)+'</div></div><span class="cfm4Tag '+x.kind+'">'+esc(label)+'</span></div>';
}
const errHtml=(title,msg)=>'<div class="cfm4Err"><b>'+esc(title)+'</b><span>'+esc(msg)+'</span><button class="cfm4Retry" onclick="cfm4Reload()">Tentar de novo</button></div>';
const dayLabel=()=>{const l=dateFromIso(S.date||isoOf(new Date())).toLocaleDateString('pt-BR',{weekday:'long',day:'2-digit',month:'long'});return l.charAt(0).toUpperCase()+l.slice(1)};
const plural=(n,a,b)=>n+' '+(n===1?a:b);
function listHtml(){
  if(S.appsStatus==='loading')return '<div class="cfm4Empty">Carregando agenda…</div>';
  if(S.appsStatus==='error')return errHtml('Não foi possível carregar a agenda',S.appsError);
  if(!S.apps.length)return '<div class="cfm4Empty"><b>Nenhuma aula hoje</b>Não há atendimentos agendados para este dia.</div>';
  return S.apps.map(itemHtml).join('');
}
function movHtml(){
  if(S.finStatus==='loading')return '';
  if(S.finStatus==='error')return '<div class="cfm4Mov" onclick="cfm4Reload()"><div class="cfm4MovTitle">Movimentações do dia</div><div class="cfm4MovErr">Não foi possível carregar: '+esc(S.finError)+' · toque para tentar de novo</div></div>';
  if(!S.ins.length&&!S.outs.length)return '';
  const sum=l=>l.reduce((t,x)=>t+(x.amount||0),0);
  return '<div class="cfm4Mov" onclick="cfm4OpenDay()"><div class="cfm4MovTitle">Movimentações do dia</div><div class="cfm4MovBox in"><span>Entradas · '+S.ins.length+'</span><b>'+money(sum(S.ins))+'</b></div><div class="cfm4MovBox out"><span>Saídas · '+S.outs.length+'</span><b>'+money(sum(S.outs))+'</b></div></div>';
}
function cardHtml(){
  const canc=S.apps.filter(x=>x.kind==='cancel').length;
  const sub=dayLabel()+(S.appsStatus==='ok'?' · '+plural(S.apps.length,'aula','aulas')+(canc?' · '+plural(canc,'cancelada','canceladas'):''):'');
  return '<div class="cfm4TodayHead" onclick="cfm4OpenDay()"><div><h3>Agenda de hoje</h3><p>'+esc(sub)+'</p></div><button class="cfm4OpenDay" onclick="event.stopPropagation();cfm4OpenDay()">Ver hoje</button></div><div class="cfm4List">'+listHtml()+'</div>'+movHtml();
}
function dayHtml(){
  const grp=(title,list,st,err)=>'<section class="cfm4Group"><div class="cfm4GroupTitle">'+title+'</div>'+(st==='loading'?'<div class="cfm4Empty">Carregando…</div>':st==='error'?errHtml('Não foi possível carregar',err):list.length?list.map(itemHtml).join(''):'<div class="cfm4Empty">Nada para hoje.</div>')+'</section>';
  const n=(st,l)=>st==='ok'?l.length:'–';
  return '<div class="cfm4DayCard"><div class="cfm4Grab"></div><div class="cfm4DayHead"><div><h2>Hoje</h2><p>'+esc(dayLabel())+'</p></div><button class="cfm4Close" onclick="cfm4CloseDay()">×</button></div><div class="cfm4Summary"><div><b>'+n(S.appsStatus,S.apps)+'</b><span>Aulas</span></div><div><b>'+n(S.finStatus,S.ins)+'</b><span>Entradas</span></div><div><b>'+n(S.finStatus,S.outs)+'</b><span>Saídas</span></div></div>'
    +grp('Agenda de aulas',S.apps,S.appsStatus,S.appsError)+grp('Recebimentos de hoje',S.ins,S.finStatus,S.finError)+grp('Contas de hoje',S.outs,S.finStatus,S.finError)
    +'<button class="cfm4CalFull" onclick="cfm4FullCalendar()">Ver calendário completo</button></div>';
}
// Garante o cartão logo depois de #cfHome2. Devolve {box,fresh}; fresh=true quando precisou criar/mover.
function mount(){
  const h=home(),root=document.getElementById('cfHome2');if(!h||!root)return null;
  let box=document.getElementById('cfm4Today');
  if(box&&box.previousElementSibling===root)return {box,fresh:false};
  if(!box){box=document.createElement('section');box.id='cfm4Today'}
  root.insertAdjacentElement('afterend',box);
  return {box,fresh:true};
}
function hideLegacy(){
  const h=home();if(!h)return;
  [...h.children].forEach(el=>{if(el.id==='cfHome2'||el.id==='cfm4Today'||el.classList.contains('cfm3LegacyCollapsed'))return;el.classList.add('cfm3LegacyCollapsed')});
}
function paint(){
  if(!mobile())return;
  const m=mount();
  if(m){m.box.innerHTML=cardHtml();hideLegacy()}
  const modal=document.getElementById('cfm4DayModal');
  if(modal&&modal.classList.contains('open'))modal.innerHTML=dayHtml();
}
function openDay(){
  let modal=document.getElementById('cfm4DayModal');
  if(!modal){modal=document.createElement('div');modal.id='cfm4DayModal';modal.onclick=e=>{if(e.target===modal)closeDay()};document.body.appendChild(modal)}
  modal.innerHTML=dayHtml();modal.classList.add('open');
}
function closeDay(){const m=document.getElementById('cfm4DayModal');if(m)m.classList.remove('open')}
function fullCalendar(){closeDay();if(typeof cfm3Go==='function')cfm3Go('calendar')}
window.cfm4OpenDay=openDay;window.cfm4CloseDay=closeDay;window.cfm4FullCalendar=fullCalendar;
window.cfm4Reload=()=>{S.appsStatus=S.finStatus='loading';return load('retry')};

/* ---------- gatilhos ---------- */
// O index.html avisa quando a sincronização terminou (data-ready) ou falhou (data-error). Nos dois casos a Agenda
// faz a PRÓPRIA consulta e mostra o resultado real dela (dados ou erro), sem depender do resultado da sincronização.
window.addEventListener('coachflow:data-ready',()=>load('data-ready'));
window.addEventListener('coachflow:data-error',e=>{console.warn('CoachFlow: a sincronização falhou — '+((e.detail&&e.detail.message)||'sem detalhe'));load('data-error')});
document.addEventListener('visibilitychange',()=>{if(!document.hidden&&client())load('visible')});
if(matchMedia(MQ).addEventListener)matchMedia(MQ).addEventListener('change',()=>{if(mobile())load('viewport')});
// Único observer: só recoloca o cartão se outro script o removeu/moveu. Não consulta o banco (antes cada render
// disparava o próprio observer e a Agenda consultava o banco em laço).
new MutationObserver(()=>{if(!mobile())return;const m=mount();if(m&&m.fresh){m.box.innerHTML=cardHtml();hideLegacy()}}).observe(document.documentElement,{subtree:true,childList:true});
css();paint();
if(client())load('start');
})();
