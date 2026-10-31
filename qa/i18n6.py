import json,re
p='/home/user/Xenke/dist/i18n.mjs';s=open(p).read()
UK={'qp10.t':'Візьми насіння в Міри','qp10.d':'Міра зберігала мамине насіння до дня, коли з’явиться чиста вода. Підійди до неї біля дверей укриття.',
'qp11.t':'Зроби набір для посадки','qp11.d':'На верстаку: 2 деревини, 1 насінина й 1 чиста вода. Воду набери з бака біля фільтра.',
'qp12.t':'Посади насіння','qp12.d':'Перша грядка біля теплиці. Встав набір у ґрунт.',
'qp13.t':'Полий грядку','qp13.d':'Потрібна 1 чиста вода з бака біля фільтра.',
'qp14.t':'Чекай на паросток','qp14.d':'Земля вологa. Ще мить…',
'q4t.t':'Набери чистої води','q4t.d':'Фільтр Станції сам наповнює бак. Набери з нього 3 води для наборів посадки.',
'dlg.seeds0':'Зачекай… Я берегла дещо саме для цього дня. Ходи до мене.','dlg.seeds1':'Мамине насіння. Вона казала: посадиш, коли буде чиста вода.','dlg.seeds2':'Тоді не гаймо часу. Набір для посадки, вода й грядка.',
'dlg.kit':'Набір готовий. Перша грядка біля теплиці — найкраща.','dlg.planted':'Тепер полий. Не шкодуй води, бак наповниться.','dlg.watered':'Чекаймо. Ґрунт тут ще живий, я певна.',
'dlg.sprout1':'Дивись! Паросток!','dlg.sprout2':'Перше зелене на Станції за сорок років.','dlg.sprout3':'Мама б усміхнулась. Тепер — до інституту, по решту насіння.',
'target.miraSeeds':'Міра · мамине насіння','target.tank':'Бак із чистою водою · {n}/{max}','target.tankEmpty':'Бак порожній · наповниться за {s} с','target.pour':'Фільтр · залити сиру воду','target.bedSow':'Грядка · посадити насіння','target.bedNoKit':'Грядка · потрібен набір для посадки','target.bedWater':'Посіяна грядка · полити','target.bedDry':'Посіяна грядка · потрібна чиста вода',
'verb.water':'Полити','verb.pour':'Залити воду','verb.sow':'Посадити',
'toast.tankEmpty':'Бак порожній: фільтр наповнить його за {s} с. Сиру воду зі струмка можна залити у фільтр.','toast.needKit2':'Спершу зроби набір для посадки на верстаку.','toast.needWater':'Потрібна чиста вода: набери її з бака біля фільтра.','toast.seedsGot':'+2 насіння від Міри','toast.sown':'Насіння в ґрунті','toast.watered':'Грядку полито','toast.sprout':'Перший паросток!',
'win5.eyebrow':'КІНЕЦЬ ПЕРШОГО ЕПІЗОДУ','win5.title':'Перший паросток.','win5.text':'Станція знову має чисту воду, а на першій грядці проклюнувся паросток із маминого насіння Міри. Радіо кличе до ботанічного інституту: у сховищі «Ковчега» аварія.','win5.stat':'час епізоду','win5.note':'Далі: живлення Станції, шахта, пробудження Кюрі й кришталевий олень. «Продовжити» відкриває чернетку наступних місій.'}
EN={'qp10.t':'Take the seeds from Mira','qp10.d':'Mira kept her mother’s seeds for the day clean water returns. Meet her by the shelter door.',
'qp11.t':'Make a planting kit','qp11.d':'At the workbench: 2 wood, 1 seed and 1 clean water. Fill water from the tank by the filter.',
'qp12.t':'Plant the seeds','qp12.d':'The first bed by the greenhouse. Set the kit into the soil.',
'qp13.t':'Water the bed','qp13.d':'You need 1 clean water from the tank by the filter.',
'qp14.t':'Wait for the sprout','qp14.d':'The soil is wet. Just a moment…',
'q4t.t':'Fill clean water','q4t.d':'The Station’s filter fills its tank by itself. Take 3 water from it for planting kits.',
'dlg.seeds0':'Wait… I kept something for exactly this day. Come here.','dlg.seeds1':'My mother’s seeds. She said: plant them when there is clean water.','dlg.seeds2':'Then let’s not waste time. A planting kit, water and a bed.',
'dlg.kit':'The kit is ready. The first bed by the greenhouse is the best.','dlg.planted':'Now water it. Don’t spare it, the tank will refill.','dlg.watered':'Let’s wait. The soil here is still alive, I’m sure.',
'dlg.sprout1':'Look! A sprout!','dlg.sprout2':'The first green at the Station in forty years.','dlg.sprout3':'Mum would smile. Now, the institute, for the rest of the seeds.',
'target.miraSeeds':'Mira · her mother’s seeds','target.tank':'Clean water tank · {n}/{max}','target.tankEmpty':'Tank empty · refills in {s} s','target.pour':'Filter · pour in raw water','target.bedSow':'Bed · plant the seeds','target.bedNoKit':'Bed · needs a planting kit','target.bedWater':'Sown bed · water it','target.bedDry':'Sown bed · needs clean water',
'verb.water':'Water','verb.pour':'Pour water','verb.sow':'Plant',
'toast.tankEmpty':'The tank is empty: the filter refills it in {s} s. Raw stream water can be poured into the filter.','toast.needKit2':'Make a planting kit at the workbench first.','toast.needWater':'You need clean water: fill it from the tank by the filter.','toast.seedsGot':'+2 seeds from Mira','toast.sown':'Seeds in the soil','toast.watered':'Bed watered','toast.sprout':'The first sprout!',
'win5.eyebrow':'END OF THE FIRST EPISODE','win5.title':'The first sprout.','win5.text':'The Station has clean water again, and a sprout from Mira’s mother’s seeds broke through in the first bed. The radio calls to the botanical institute: an accident in the Ark vault.','win5.stat':'episode time','win5.note':'Next: power for the Station, the mine, Curie’s awakening and the crystal stag. Continue opens a draft of the next missions.'}
m=re.search(r'const STORY_TEXT=(\{.*?\});\n',s,re.S);st=json.loads(m.group(1));st['uk'].update(UK);st['en'].update(EN)
s=s[:m.start(1)]+json.dumps(st,ensure_ascii=False)+s[m.end(1):]
# Settings: frame-rate limit separate from picture quality (UI text: all five languages).
E6={'uk':{'set.fpsCap':'Ліміт кадрів','fps.30':'30','fps.60':'60','fps.120':'120','set.qualityNote':'Якість — це чіткість картинки. Частоту кадрів задає окремий ліміт, а світло й тряску — «Ефекти».','set.fpsCapNote':'30 — економить батарею на слабких телефонах. 120 — лише для екранів із такою частотою.'},
'en':{'set.fpsCap':'Frame limit','fps.30':'30','fps.60':'60','fps.120':'120','set.qualityNote':'Quality is picture sharpness. The frame rate has its own limit; light and shake are under “Effects”.','set.fpsCapNote':'30 saves battery on weak phones. 120 only for screens that refresh that fast.'},
'pl':{'set.fpsCap':'Limit klatek','fps.30':'30','fps.60':'60','fps.120':'120','set.fpsCapNote':'30 oszczędza baterię na słabych telefonach. 120 tylko dla takich ekranów.'},
'de':{'set.fpsCap':'Bildratenlimit','fps.30':'30','fps.60':'60','fps.120':'120','set.fpsCapNote':'30 spart Akku auf schwachen Handys. 120 nur für solche Bildschirme.'},
'es':{'set.fpsCap':'Límite de FPS','fps.30':'30','fps.60':'60','fps.120':'120','set.fpsCapNote':'30 ahorra batería en móviles lentos. 120 solo para pantallas que lo admiten.'}}
anchor="// Prologue story text:"
assert s.count(anchor)==1
s=s.replace(anchor,"const EXTRA6="+json.dumps(E6,ensure_ascii=False)+";\nfor(const l of Object.keys(EXTRA6))Object.assign(S[l],EXTRA6[l]);\n"+anchor)
open(p,'w').write(s);print('ok')
