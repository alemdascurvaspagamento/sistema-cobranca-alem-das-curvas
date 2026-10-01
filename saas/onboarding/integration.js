(()=>{'use strict';
const URL='https://yjpxjzgvshaabjpdpbsc.supabase.co';
const KEY='sb_publishable_cfk3k9kcgmbvUp-oUmoNfw_rYLUzIge';
const saasSb=window.supabase.createClient(URL,KEY,{auth:{persistSession:true,autoRefreshToken:true}});
function numberBR(v){if(v==null||v==='')return null;const s=String(v).trim().replace(/\s/g,'').replace(/R\$/gi,'');let normalized=s;if(s.includes(','))normalized=s.replace(/\./g,'').replace(',','.');const n=Number(normalized);return Number.isFinite(n)?n:null}
function showIntegrationError(message){const old=document.getElementById('cfOnboardingError');if(old)old.remove();const el=document.createElement('div');el.id='cfOnboardingError';el.className='preview show';el.style.cssText='border:1px solid #e6b8b8;background:#fff4f4;color:#8a2929;margin-bottom:14px';el.textContent=message;view.prepend(el)}
async function requireSession(){const {data,error}=await saasSb.auth.getSession();if(error)throw error;if(!data.session){location.replace('../../saas.html');return false}return true}
const originalFinish=finish;
finish=async function(){
  try{
    if(!(await requireSession()))return;
    const pr=p();
    const servicePrice=numberBR(state.service.price)??0;
    const annualGoal=numberBR(state.goal);
    view.innerHTML='<div class="done"><div class="eyebrow">Criando seu espaço</div><h2>Estamos preparando seu CoachFlow.</h2><p class="lead">Perfil, linguagem, serviço, cliente e meta estão sendo configurados com segurança.</p><div class="doneCard"><h3>Aguarde alguns segundos…</h3><div class="summary"><span>Validando sua conta</span><span>Criando o ambiente de '+esc(pr[1])+'</span><span>Aplicando suas preferências</span></div></div></div>';
    const {data,error}=await saasSb.rpc('complete_coachflow_onboarding',{
      p_profession_code:state.profession,
      p_display_name:state.profile.name.trim(),
      p_phone:state.profile.phone.trim()||null,
      p_registration_number:state.profile.registration.trim()||null,
      p_billing_models:state.billing,
      p_service_name:(state.service.name||pr[7]).trim(),
      p_service_duration:Number(state.service.duration||pr[8]||60),
      p_service_price:servicePrice,
      p_client_name:state.client.name.trim()||null,
      p_client_phone:state.client.phone.trim()||null,
      p_annual_goal:annualGoal
    });
    if(error)throw error;
    sessionStorage.setItem('coachflow_new_workspace',String(data||''));
    location.replace('../../saas.html?onboarding=completed');
  }catch(err){
    console.error('CoachFlow onboarding',err);
    render();
    showIntegrationError(err?.message||'Não foi possível concluir a configuração. Tente novamente.');
  }
};
requireSession().catch(err=>{console.error(err);showIntegrationError('Não foi possível validar sua sessão. Volte ao login e tente novamente.')});
})();