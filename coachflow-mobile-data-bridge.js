/* CoachFlow Mobile Data Bridge — garante leitura autenticada no mobile */
(function(global){
'use strict';
if(global.__coachflowMobileBridgeStarted)return;
global.__coachflowMobileBridgeStarted=true;
function unwrap(result){
  if(result&&result.error)throw result.error;
  return result&&Object.prototype.hasOwnProperty.call(result,'data')?result.data:result;
}
async function nativeSelect(table,options){
  options=options||{};
  const sb=global.adcSupabase;
  if(!sb||typeof sb.from!=='function')throw new Error('Supabase ainda não inicializado');
  let q=sb.from(table).select(options.columns||'*');
  (options.filters||[]).forEach(f=>{
    const op=f.op||'eq';
    if(typeof q[op]==='function')q=q[op](f.column,f.value);
  });
  if(options.order&&typeof q.order==='function')q=q.order(options.order.column,{ascending:options.order.ascending!==false});
  if(options.limit!=null&&typeof q.limit==='function')q=q.limit(options.limit);
  return unwrap(await q);
}
function install(){
  if(global.coachflowApi&&typeof global.coachflowApi.select==='function'){
    global.dispatchEvent(new CustomEvent('coachflow:data-ready'));
    return true;
  }
  if(!global.adcSupabase||typeof global.adcSupabase.from!=='function')return false;
  global.coachflowApi={select:nativeSelect};
  global.dispatchEvent(new CustomEvent('coachflow:data-ready'));
  return true;
}
if(!install()){
  let tries=0;
  const timer=setInterval(()=>{
    tries++;
    if(install()||tries>=80)clearInterval(timer);
  },100);
}
})(window);
