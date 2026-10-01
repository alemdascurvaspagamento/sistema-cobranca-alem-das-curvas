/* CoachFlow loader v14 — core + Home 2.0 + Mobile 2.0 + retráteis + Mobile 3.0 */
(function(){
  function load(src,done){var s=document.createElement('script');s.src=src;s.defer=true;s.onload=done||function(){};s.onerror=function(){console.error('CoachFlow: falha ao carregar '+src)};document.head.appendChild(s)}
  load('coachflow-api-client-v10.js?v=10',function(){
    load('coachflow-home2.js?v=2',function(){
      load('coachflow-mobile2.js?v=1',function(){
        load('coachflow-collapsible.js?v=1',function(){
          load('coachflow-mobile3.js?v=1');
        });
      });
    });
  });
})();
