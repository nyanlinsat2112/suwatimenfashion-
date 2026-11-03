p='/home/claude/miba-yeik/car3d.js';s=open(p).read()
old="  loadGLB(MODEL_URL).then(m => { if (!m) return; scene.remove(car); car = m; scene.add(car); stage.classList.add('real-model') });"
assert old in s
s=s.replace(old,"""  const picks = [...document.querySelectorAll('[data-model]')]; const cache = {}; let want = null;
  async function show(url) {
    want = url; picks.forEach(b => b.setAttribute('aria-pressed', String(b.dataset.model === url)));
    if (!(url in cache)) { stage.classList.add('loading'); cache[url] = await loadGLB(url); stage.classList.remove('loading') }
    if (want !== url || !cache[url]) return;
    scene.remove(car); car = cache[url]; scene.add(car); stage.classList.add('real-model');
  }
  picks.forEach(b => b.addEventListener('click', () => show(b.dataset.model)));
  show(picks.length ? picks[0].dataset.model : MODEL_URL);""")
open(p,'w').write(s)
p='/home/claude/miba-yeik/index.html';s=open(p).read()
a='<span class="stage-hint">↻ ဆွဲလှည့်ကြည့်ပါ</span>';assert a in s
s=s.replace(a,'<div class="carpick" role="group" aria-label="ကား ရွေးရန်"><button data-model="models/alphard.glb" aria-pressed="true">Alphard</button><button data-model="models/gtr.glb" aria-pressed="false">GT-R NISMO</button></div>\n  '+a,1)
a='/* brand marquee */';assert a in s
s=s.replace(a,'''.carpick{position:absolute;z-index:3;left:50%;transform:translateX(-50%);bottom:48px;display:flex;gap:4px;background:rgba(0,0,0,.35);border:1px solid rgba(255,255,255,.22);border-radius:99px;padding:3px}
.carpick button{border:0;background:none;color:#fff;font-family:var(--f-num);font-weight:600;letter-spacing:.06em;font-size:14px;padding:5px 14px;border-radius:99px;opacity:.8;white-space:nowrap}
.carpick button[aria-pressed="true"]{background:var(--accent);color:#141d27;opacity:1}
.stage.loading .carpick::after{content:"";width:14px;height:14px;margin:auto 6px;border:2px solid rgba(255,255,255,.4);border-top-color:#fff;border-radius:50%;animation:spin .8s linear infinite}
@keyframes spin{to{transform:rotate(360deg)}}
'''+a,1)
a='<a href="admin.html">ဝန်ထမ်း Login</a></div>';assert a in s
s=s.replace(a,a+'\n    <div style="opacity:.55;font-size:11px">3D model: Nissan GT-R NISMO by NznCG (CGTrader)</div>',1)
open(p,'w').write(s)
print('ok')
