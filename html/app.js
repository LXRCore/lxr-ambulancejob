/* LXR-DOCTOR — the death card | © 2026 iBoss21 / LXRCore */
(function () {
  const $ = (id) => document.getElementById(id);
  const card = $('card');
  let L = {}, total = 1;
  const t = (k, vars) => { let s = L[k] || k.split('.').pop().replace(/_/g, ' '); if (vars) for (const v in vars) s = s.replace('%{' + v + '}', vars[v]); return s; };
  const mmss = (s) => `${Math.floor(s / 60)}:${String(s % 60).padStart(2, '0')}`;
  function applyLocale() { document.querySelectorAll('[data-l]').forEach(el => { const k = 'ui.' + el.dataset.l; if (L[k]) el.textContent = L[k]; }); }
  function tick(left) {
    $('left').textContent = mmss(left);
    $('fill').style.width = Math.max(0, Math.min(100, (left / total) * 100)) + '%';
    const hint = $('hint'); hint.textContent = '';
    if (left <= 0) { const k = document.createElement('span'); k.className = 'lxr-key'; k.textContent = 'E'; hint.appendChild(k); hint.appendChild(document.createTextNode(t('ui.give_up'))); $('sub').textContent = t('ui.sub_can_give_up'); }
    else { hint.textContent = t('ui.wait_hint'); $('sub').textContent = t('ui.sub_wait'); }
  }
  window.addEventListener('message', e => {
    const m = e.data || {};
    if (m.brand && m.brand.theme) document.documentElement.dataset.theme = m.brand.theme;
    if (m.locale) { L = m.locale; applyLocale(); }
    if (m.lang) document.body.classList.toggle('lang-ka', m.lang === 'ka');
    if (m.action === 'down') { total = Math.max(1, (m.payload && m.payload.seconds) || 1); tick(total); card.classList.remove('lxr-hidden'); }
    if (m.action === 'tick') tick((m.payload && m.payload.left) || 0);
    if (m.action === 'hide') card.classList.add('lxr-hidden');
  });
  if (window.__LXR_MOCK__) { for (const m of [].concat(window.__LXR_MOCK__)) window.postMessage(m, '*'); }
})();
