/* CoachFlow loader v24 — UX mobile estável + agenda diária lida pelo cliente Supabase do sistema */
(function(){
  function load(src,done){var s=document.createElement('script');s.src=src;s.defer=true;s.onload=done||function(){};s.onerror=function(){console.error('CoachFlow: falha ao carregar '+src)};document.head.appendChild(s)}
  load('coachflow-api-client-v10.js?v=10',function(){
    load('coachflow-mobile-data-bridge.js?v=1',function(){
      load('coachflow-home2.js?v=2',function(){
        load('coachflow-mobile2.js?v=1',function(){
          load('coachflow-collapsible.js?v=1',function(){
            load('coachflow-mobile3.js?v=3',function(){
              load('coachflow-mobile-home4.js?v=11');
            });
          });
        });
      });
    });
  });
})();