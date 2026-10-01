/* CoachFlow loader v25 — baixa todos os scripts em paralelo e executa na ordem certa */
(function(){
  var files=[
    'coachflow-api-client-v10.js?v=11',
    'coachflow-mobile-data-bridge.js?v=1',
    'coachflow-home2.js?v=2',
    'coachflow-mobile2.js?v=1',
    'coachflow-collapsible.js?v=1',
    'coachflow-mobile3.js?v=3',
    'coachflow-mobile-home4.js?v=11'
  ];
  files.forEach(function(src){
    var s=document.createElement('script');
    s.src=src;
    s.async=false; /* download simultâneo, execução na ordem da lista */
    s.onerror=function(){console.error('CoachFlow: falha ao carregar '+src)};
    document.head.appendChild(s);
  });
})();
