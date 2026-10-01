/* CoachFlow loader v11 — preserva v10 e adiciona Home 2.0 */
(function(){
  function load(src,done){var s=document.createElement('script');s.src=src;s.defer=true;s.onload=done||function(){};s.onerror=function(){console.error('CoachFlow: falha ao carregar '+src)};document.head.appendChild(s)}
  load('coachflow-api-client-v10.js?v=10',function(){load('coachflow-home2.js?v=2')});
})();
