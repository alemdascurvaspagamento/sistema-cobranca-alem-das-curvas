/* CoachFlow loader v12 — preserva v10, Home 2.0 e adiciona Mobile 2.0 */
(function(){
  function load(src,done){var s=document.createElement('script');s.src=src;s.defer=true;s.onload=done||function(){};s.onerror=function(){console.error('CoachFlow: falha ao carregar '+src)};document.head.appendChild(s)}
  load('coachflow-api-client-v10.js?v=10',function(){
    load('coachflow-home2.js?v=2',function(){
      load('coachflow-mobile2.js?v=1');
    });
  });
})();
