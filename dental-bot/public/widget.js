/* AI-адміністратор клініки — вбудовуваний віджет чату.
   Підключення на сайті клініки (один рядок перед </body>):
   <script src="https://ВАШ-СЕРВЕР/widget.js" data-clinic="slug" defer></script>
   Необов'язково: data-open="1" — відкрити одразу; data-api="https://..." — інша адреса API. */
(function () {
  'use strict';
  var script = document.currentScript || document.querySelector('script[data-clinic]');
  if (!script || window.__dentalChatLoaded) return;
  window.__dentalChatLoaded = true;
  var slug = script.getAttribute('data-clinic');
  var api = (script.getAttribute('data-api') || new URL(script.src, location.href).origin).replace(/\/+$/, '');
  var autoOpen = script.getAttribute('data-open') === '1';
  var KEY = 'dcw:' + slug + ':';

  function store(k, v) {
    try {
      if (v === undefined) return JSON.parse(localStorage.getItem(KEY + k) || 'null');
      localStorage.setItem(KEY + k, JSON.stringify(v));
    } catch (e) { return null; }
  }
  function esc(s) {
    return String(s).replace(/[&<>"']/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]; });
  }
  // Легке форматування відповіді: посилання, телефони, жирний, переноси рядків.
  function format(text) {
    var s = esc(text);
    s = s.replace(/\*\*([^*]+)\*\*/g, '<b>$1</b>');
    s = s.replace(/(https?:\/\/[^\s<]+[^\s<.,;:!?)])/g, '<a href="$1" target="_blank" rel="noopener">$1</a>');
    s = s.replace(/(\+?38\s?\(?0\d{2}\)?[\s-]?\d{3}[\s-]?\d{2}[\s-]?\d{2})/g, function (m) { return '<a href="tel:' + m.replace(/[^\d+]/g, '') + '">' + m + '</a>'; });
    s = s.replace(/^\s*[-•]\s+/gm, '• ');
    return s.replace(/\n/g, '<br>');
  }
  function textColor(hex) {
    var h = hex.replace('#', '');
    if (h.length === 3) h = h.split('').map(function (c) { return c + c; }).join('');
    var n = parseInt(h, 16), r = (n >> 16) & 255, g = (n >> 8) & 255, b = n & 255;
    return (0.299 * r + 0.587 * g + 0.114 * b) > 170 ? '#13202a' : '#ffffff';
  }

  fetch(api + '/api/clinic/' + encodeURIComponent(slug)).then(function (r) {
    if (!r.ok) throw new Error('clinic ' + r.status);
    return r.json();
  }).then(init).catch(function (e) { if (window.console) console.warn('[чат клініки] не завантажився:', e.message); });

  function init(cfg) {
    var brand = /^#[0-9a-f]{3,6}$/i.test(cfg.brandColor || '') ? cfg.brandColor : '#0f7c8a';
    var onBrand = textColor(brand);
    var host = document.createElement('div');
    host.setAttribute('data-dental-chat', slug);
    document.body.appendChild(host);
    var root = host.attachShadow ? host.attachShadow({ mode: 'open' }) : host;

    var css = ':host{all:initial}*{box-sizing:border-box;font-family:system-ui,-apple-system,"Segoe UI",Roboto,sans-serif}' +
      '.wrap{position:fixed;right:20px;bottom:20px;z-index:2147483000;color:#13202a;font-size:15px;line-height:1.45}' +
      '.launch{width:60px;height:60px;border-radius:50%;border:0;background:' + brand + ';color:' + onBrand + ';cursor:pointer;box-shadow:0 8px 24px rgba(0,0,0,.25);display:grid;place-items:center;transition:transform .15s}' +
      '.launch:hover{transform:scale(1.06)}.launch svg{width:28px;height:28px}' +
      '.teaser{position:absolute;right:72px;bottom:10px;background:#fff;border-radius:14px;padding:10px 32px 10px 14px;box-shadow:0 8px 24px rgba(0,0,0,.18);width:max-content;max-width:240px;font-size:14px;cursor:pointer}' +
      '.teaser button{position:absolute;top:4px;right:6px;border:0;background:none;color:#6b7a86;font-size:16px;cursor:pointer}' +
      '.panel{position:absolute;right:0;bottom:76px;width:380px;height:min(600px,calc(100vh - 110px));background:#fff;border-radius:18px;box-shadow:0 16px 48px rgba(0,0,0,.28);display:none;flex-direction:column;overflow:hidden}' +
      '.panel.on{display:flex}' +
      '.head{background:' + brand + ';color:' + onBrand + ';padding:14px 14px 14px 16px;display:flex;align-items:center;gap:12px}' +
      '.ava{width:40px;height:40px;border-radius:50%;background:rgba(255,255,255,.22);display:grid;place-items:center;flex:none}.ava svg{width:24px;height:24px}' +
      '.title{flex:1;min-width:0}.title b{display:block;font-size:15px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.title span{font-size:12px;opacity:.85}' +
      '.title span:before{content:"";display:inline-block;width:7px;height:7px;border-radius:50%;background:#3ddc84;margin-right:6px;vertical-align:1px}' +
      '.x{border:0;background:none;color:inherit;font-size:24px;line-height:1;cursor:pointer;padding:4px 6px;opacity:.85}' +
      '.log{flex:1;overflow-y:auto;padding:14px;background:#f4f7f9;display:flex;flex-direction:column;gap:8px}' +
      '.m{max-width:85%;padding:9px 12px;border-radius:16px;white-space:normal;word-wrap:break-word;animation:in .18s ease-out}' +
      '@keyframes in{from{opacity:0;transform:translateY(4px)}to{opacity:1}}' +
      '.bot{background:#fff;align-self:flex-start;border-bottom-left-radius:5px;box-shadow:0 1px 2px rgba(0,0,0,.06)}' +
      '.me{background:' + brand + ';color:' + onBrand + ';align-self:flex-end;border-bottom-right-radius:5px}' +
      '.m a{color:inherit;text-decoration:underline}' +
      '.dots{display:inline-flex;gap:4px}.dots i{width:7px;height:7px;border-radius:50%;background:#9aa8b3;animation:b 1s infinite}.dots i:nth-child(2){animation-delay:.15s}.dots i:nth-child(3){animation-delay:.3s}' +
      '@keyframes b{0%,80%,100%{opacity:.3}40%{opacity:1}}' +
      '.chips{display:flex;flex-wrap:wrap;gap:6px;padding:0 0 4px}.chip{border:1px solid ' + brand + ';color:' + brand + ';background:#fff;border-radius:999px;padding:6px 11px;font-size:13px;cursor:pointer}' +
      '.chip:hover{background:' + brand + ';color:' + onBrand + '}' +
      '.form{background:#fff;border-radius:14px;padding:12px;display:flex;flex-direction:column;gap:8px;box-shadow:0 1px 3px rgba(0,0,0,.08)}' +
      '.form input{border:1px solid #d5dde3;border-radius:10px;padding:9px 10px;font-size:14px;width:100%}' +
      '.form button{border:0;border-radius:10px;padding:10px;background:' + brand + ';color:' + onBrand + ';font-weight:600;cursor:pointer;font-size:14px}' +
      '.form small{color:#6b7a86;font-size:11px}' +
      '.foot{border-top:1px solid #e6ebef;padding:10px;display:flex;gap:8px;align-items:flex-end;background:#fff}' +
      'textarea{flex:1;resize:none;border:1px solid #d5dde3;border-radius:12px;padding:9px 11px;font-size:15px;max-height:110px;min-height:40px;outline:none}' +
      'textarea:focus{border-color:' + brand + '}' +
      '.send{width:40px;height:40px;border-radius:50%;border:0;background:' + brand + ';color:' + onBrand + ';cursor:pointer;display:grid;place-items:center;flex:none}.send svg{width:18px;height:18px}' +
      '.send:disabled{opacity:.5;cursor:default}' +
      '.legal{font-size:11px;color:#7d8b96;text-align:center;padding:0 10px 8px;background:#fff}' +
      '.legal button{border:0;background:none;color:' + brand + ';font-size:11px;cursor:pointer;text-decoration:underline;padding:0}' +
      '@media (max-width:520px){.wrap{right:12px;bottom:12px}.panel{position:fixed;inset:0;width:auto;height:auto;border-radius:0}.teaser{right:68px}}';

    var ICON_CHAT = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M21 12a8 8 0 0 1-11.6 7.1L4 20l1-4.6A8 8 0 1 1 21 12z"/></svg>';
    var ICON_TOOTH = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linejoin="round" aria-hidden="true"><path d="M7.5 3C4.6 3 3 5.3 3 8c0 2.2.9 3.6 1.6 5.4.6 1.7.9 3.7 1.4 5.6.4 1.4 1 2 1.8 2 1 0 1.4-1.1 1.7-2.6.3-1.6.7-3.4 2.5-3.4s2.2 1.8 2.5 3.4c.3 1.5.7 2.6 1.7 2.6.8 0 1.4-.6 1.8-2 .5-1.9.8-3.9 1.4-5.6C20.1 11.6 21 10.2 21 8c0-2.7-1.6-5-4.5-5-1.8 0-2.8 1-4.5 1S9.3 3 7.5 3z"/></svg>';
    var ICON_SEND = '<svg viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="M3.4 20.4 21 12 3.4 3.6l-.1 6.5L15 12 3.3 13.9z"/></svg>';

    root.innerHTML = '<style>' + css + '</style><div class="wrap">' +
      '<div class="panel" role="dialog" aria-label="Чат з клінікою ' + esc(cfg.name) + '">' +
      '<div class="head"><div class="ava">' + ICON_TOOTH + '</div><div class="title"><b>' + esc(cfg.name) + '</b><span>Онлайн · відповідаємо одразу</span></div><button class="x" aria-label="Закрити чат">×</button></div>' +
      '<div class="log" aria-live="polite"></div>' +
      '<div class="foot"><textarea rows="1" placeholder="Напишіть питання…" aria-label="Повідомлення"></textarea><button class="send" aria-label="Надіслати">' + ICON_SEND + '</button></div>' +
      '<div class="legal">Відповіді формує віртуальний помічник за даними сайту клініки · <button class="book">Записатися</button></div>' +
      '</div><button class="launch" aria-label="Відкрити чат з клінікою">' + ICON_CHAT + '</button></div>';

    var $ = function (s) { return root.querySelector(s); };
    var panel = $('.panel'), log = $('.log'), input = $('textarea'), sendBtn = $('.send'), launch = $('.launch');
    var history = store('log') || [];
    var convId = store('id');
    var busy = false, chips = null, teaser = null;

    function scroll() { log.scrollTop = log.scrollHeight; }
    function bubble(role, text, persist) {
      var d = document.createElement('div');
      d.className = 'm ' + (role === 'user' ? 'me' : 'bot');
      d.innerHTML = role === 'user' ? esc(text).replace(/\n/g, '<br>') : format(text);
      log.appendChild(d);
      if (persist !== false) { history.push({ r: role, t: text }); history = history.slice(-40); store('log', history); }
      scroll();
      return d;
    }
    function showChips() {
      if (!cfg.quickReplies || !cfg.quickReplies.length) return;
      chips = document.createElement('div');
      chips.className = 'chips';
      cfg.quickReplies.forEach(function (q) {
        var b = document.createElement('button');
        b.className = 'chip'; b.textContent = q;
        b.onclick = function () { send(q); };
        chips.appendChild(b);
      });
      log.appendChild(chips);
      scroll();
    }
    function hideChips() { if (chips) { chips.remove(); chips = null; } }

    function typing() {
      var d = document.createElement('div');
      d.className = 'm bot';
      d.innerHTML = '<span class="dots" aria-label="Друкує"><i></i><i></i><i></i></span>';
      log.appendChild(d); scroll();
      return d;
    }

    function post(path, body) {
      return fetch(api + path, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) })
        .then(function (r) { return r.json().catch(function () { return {}; }).then(function (j) { j._status = r.status; return j; }); });
    }

    function send(text) {
      text = String(text || '').trim();
      if (!text || busy) return;
      busy = true; sendBtn.disabled = true; hideChips();
      bubble('user', text);
      input.value = ''; resize();
      var t = typing();
      post('/api/chat', { clinic: slug, conversationId: convId, message: text, page: location.href })
        .then(function (j) {
          t.remove();
          if (j.conversationId) { convId = j.conversationId; store('id', convId); }
          bubble('bot', j.reply || ('Не вдалося отримати відповідь. ' + (cfg.phone ? 'Зателефонуйте, будь ласка: ' + cfg.phone : 'Спробуйте ще раз.')));
        })
        .catch(function () {
          t.remove();
          bubble('bot', 'Немає з\'єднання. ' + (cfg.phone ? 'Зателефонуйте, будь ласка: ' + cfg.phone : 'Спробуйте ще раз трохи пізніше.'), false);
        })
        .then(function () { busy = false; sendBtn.disabled = false; input.focus(); });
    }

    function showForm() {
      hideChips();
      var f = document.createElement('form');
      f.className = 'form';
      f.innerHTML = '<b>Запис на консультацію</b><input name="name" placeholder="Ваше ім\'я" required autocomplete="name">' +
        '<input name="phone" type="tel" placeholder="Телефон, напр. 067 123 45 67" required autocomplete="tel">' +
        '<input name="time" placeholder="Зручний час (необов\'язково)"><button type="submit">Надіслати заявку</button>' +
        '<small>Телефон потрібен лише для того, щоб адміністратор передзвонив і підтвердив запис.</small>';
      f.onsubmit = function (e) {
        e.preventDefault();
        var btn = f.querySelector('button'); btn.disabled = true; btn.textContent = 'Надсилаю…';
        var el = f.elements;
        post('/api/lead', { clinic: slug, conversationId: convId, name: el.namedItem('name').value, phone: el.namedItem('phone').value, preferredTime: el.namedItem('time').value })
          .then(function (j) {
            if (j.ok) { f.remove(); bubble('bot', j.reply); }
            else { btn.disabled = false; btn.textContent = 'Надіслати заявку'; f.querySelector('small').textContent = j.error === 'rate' ? 'Забагато спроб, спробуйте за кілька хвилин.' : 'Перевірте ім\'я та номер телефону.'; }
          })
          .catch(function () { btn.disabled = false; btn.textContent = 'Надіслати заявку'; });
      };
      log.appendChild(f); scroll();
      f.elements.namedItem('name').focus();
    }

    function resize() { input.style.height = 'auto'; input.style.height = Math.min(input.scrollHeight, 110) + 'px'; }
    function open() {
      panel.classList.add('on');
      if (teaser) { teaser.remove(); teaser = null; }
      try { sessionStorage.setItem(KEY + 'seen', '1'); } catch (e) { /* ок */ }
      if (window.matchMedia('(min-width: 521px)').matches) input.focus();
      scroll();
    }
    function close() { panel.classList.remove('on'); launch.focus(); }

    if (history.length) history.forEach(function (x) { bubble(x.r, x.t, false); });
    else { bubble('bot', cfg.greeting, false); showChips(); }

    launch.onclick = function () { panel.classList.contains('on') ? close() : open(); };
    $('.x').onclick = close;
    $('.book').onclick = function () { open(); showForm(); };
    sendBtn.onclick = function () { send(input.value); };
    input.addEventListener('input', resize);
    input.addEventListener('keydown', function (e) { if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); send(input.value); } });
    root.addEventListener('keydown', function (e) { if (e.key === 'Escape' && panel.classList.contains('on')) close(); });

    if (autoOpen) setTimeout(open, 600);
    else {
      var seen = false;
      try { seen = sessionStorage.getItem(KEY + 'seen') === '1'; } catch (e) { /* ок */ }
      if (!seen) setTimeout(function () {
        if (panel.classList.contains('on')) return;
        teaser = document.createElement('div');
        teaser.className = 'teaser';
        teaser.innerHTML = 'Підкажу ціни та запишу на прийом 👋<button aria-label="Сховати">×</button>';
        teaser.onclick = function (e) { if (e.target.tagName === 'BUTTON') { teaser.remove(); teaser = null; try { sessionStorage.setItem(KEY + 'seen', '1'); } catch (x) { /* ок */ } } else open(); };
        $('.wrap').appendChild(teaser);
      }, 7000);
    }
  }
})();
