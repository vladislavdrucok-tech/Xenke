class_name Content
extends RefCounted
## Static game content: routes, riddles, collectibles, characters.
## Text is stored as {"uk": ..., "en": ...}; I18n.pick() chooses the language.

const D_PAST := 0
const D_PRESENT := 1
const D_FUTURE := 2

## Postal routes: year ranges that appear on labels and a reward multiplier.
const ROUTES := {
	"town": {"past": [1950, 2037], "future": [2039, 2099], "mult": 1.0, "cost": 0, "shards": 0,
		"name": {"uk": "Старе місто", "en": "Old Town"},
		"desc": {"uk": "Роки 1950–2099. Звичайні люди, звичайні дива.", "en": "Years 1950–2099. Ordinary people, ordinary miracles."}},
	"steam": {"past": [1820, 1949], "future": [], "mult": 1.15, "cost": 2500, "shards": 0, "level": 4,
		"name": {"uk": "Доба пари", "en": "Steam Age"},
		"desc": {"uk": "Роки 1820–1949. Телеграми, паровози, капелюхи.", "en": "Years 1820–1949. Telegrams, locomotives, hats."}},
	"orbit": {"past": [], "future": [2100, 2299], "mult": 1.25, "cost": 5000, "shards": 2, "level": 7,
		"name": {"uk": "Орбітальне кільце", "en": "Orbital Ring"},
		"desc": {"uk": "Роки 2100–2299. Станції, колонії, космічні бабусі.", "en": "Years 2100–2299. Stations, colonies, space grannies."}},
	"medieval": {"past": [1100, 1819], "future": [], "mult": 1.35, "cost": 9000, "shards": 4, "level": 10,
		"name": {"uk": "Лицарський тракт", "en": "Knights' Road"},
		"desc": {"uk": "Роки 1100–1819. Сургуч, пергамент, дракони (майже).", "en": "Years 1100–1819. Wax, parchment, dragons (almost)."}},
	"deep": {"past": [], "future": [2300, 2999], "mult": 1.45, "cost": 15000, "shards": 8, "level": 13,
		"name": {"uk": "Глибоке майбутнє", "en": "Deep Future"},
		"desc": {"uk": "Роки 2300–2999. Ніхто не знає, що там. Окрім пошти.", "en": "Years 2300–2999. Nobody knows what's there. Except the post."}},
}

const ROUTE_ORDER := ["town", "steam", "orbit", "medieval", "deep"]

## Mystery parcels: the label is replaced by a clue about the era.
const RIDDLES := {
	"r_coach": {"dest": D_PAST, "uk": "Привезли кінним диліжансом", "en": "Arrived by horse-drawn coach"},
	"r_floppy": {"dest": D_PAST, "uk": "Усередині дискета й записка «не губи»", "en": "A floppy disk and a note: \"don't lose it\""},
	"r_steam": {"dest": D_PAST, "uk": "Пахне вугіллям і паровозами", "en": "Smells of coal and steam trains"},
	"r_wax": {"dest": D_PAST, "uk": "Запечатано сургучем, писано пером", "en": "Sealed with wax, written with a quill"},
	"r_moon": {"dest": D_PAST, "uk": "Штемпель: «до першої висадки на Місяць»", "en": "Postmark: \"before the first Moon landing\""},
	"r_knight": {"dest": D_PAST, "uk": "Для лицаря з замку на пагорбі", "en": "For the knight in the castle on the hill"},
	"r_grandpa": {"dest": D_PAST, "uk": "Дідусеві, коли він був ще школярем", "en": "To grandpa, back when he was a schoolboy"},
	"r_today": {"dest": D_PRESENT, "uk": "Замовлено сьогодні о 9:00", "en": "Ordered today at 9:00"},
	"r_neighbor": {"dest": D_PRESENT, "uk": "Сусідові через дорогу. Просто зараз", "en": "To the neighbour across the road. Right now"},
	"r_cake": {"dest": D_PRESENT, "uk": "Торт на сьогоднішній день народження", "en": "A cake for today's birthday party"},
	"r_news": {"dest": D_PRESENT, "uk": "Свіжа ранкова газета — цього ранку", "en": "This morning's fresh newspaper"},
	"r_mars": {"dest": D_FUTURE, "uk": "Першому мерові Марса", "en": "To the first mayor of Mars"},
	"r_hover": {"dest": D_FUTURE, "uk": "Доставляти лише на ховерборді", "en": "Deliver by hoverboard only"},
	"r_quantum": {"dest": D_FUTURE, "uk": "Оплачено квантовими кредитами", "en": "Postage paid in quantum credits"},
	"r_orbit": {"dest": D_FUTURE, "uk": "Орбітальна станція 9, кільце 3", "en": "Orbital Station 9, ring 3"},
	"r_grandkids": {"dest": D_FUTURE, "uk": "Відкрити, коли онуки виростуть", "en": "Open when the grandchildren grow up"},
	"r_seeds": {"dest": D_FUTURE, "uk": "Насіння для місячних городів", "en": "Seeds for the Moon gardens"},
}

## Characters that send parcels and appear in the story.
const CHARACTERS := {
	"bit": {"uk": "БІТ", "en": "BIT", "color": Color("8fd3ff")},
	"olena": {"uk": "Бабуся Олена", "en": "Granny Olena", "color": Color("f2c48d")},
	"kai": {"uk": "Кай", "en": "Kai", "color": Color("7cf0c6")},
	"vera": {"uk": "Інспекторка Віра", "en": "Inspector Vera", "color": Color("ff8aa8")},
	"future": {"uk": "Ти (2057)", "en": "You (2057)", "color": Color("d6b8ff")},
	"oracle": {"uk": "ОРАКУЛ", "en": "ORACLE", "color": Color("ff5f6d")},
	"quant": {"uk": "Квант", "en": "Quant", "color": Color("ffd166")},
	"hero": {"uk": "Ти", "en": "You", "color": Color("ffffff")},
}

## Rare collectibles. rarity: 1 common, 2 rare, 3 legendary (story only).
const COLLECTIBLES := {
	"pocket_watch": {"era": D_PAST, "rarity": 1, "name": {"uk": "Кишеньковий годинник", "en": "Pocket Watch"},
		"desc": {"uk": "Відстає рівно на сто років. Стабільно.", "en": "Runs exactly one hundred years late. Reliably."}},
	"wax_seal": {"era": D_PAST, "rarity": 1, "name": {"uk": "Сургучна печатка", "en": "Wax Seal"},
		"desc": {"uk": "Із гербом пошти, якої ще не існує.", "en": "Bears the crest of a post office that doesn't exist yet."}},
	"floppy": {"era": D_PAST, "rarity": 1, "name": {"uk": "Дискета «БІТ-1»", "en": "Floppy \"BIT-1\""},
		"desc": {"uk": "Підпис: «резервна копія душі». БІТ ніяковіє.", "en": "Labelled \"soul backup\". BIT gets flustered."}},
	"cassette": {"era": D_PAST, "rarity": 1, "name": {"uk": "Касета з піснями", "en": "Mixtape"},
		"desc": {"uk": "Сторона Б: «для того, хто сортує».", "en": "Side B: \"for whoever is sorting\"."}},
	"rotary_phone": {"era": D_PAST, "rarity": 2, "name": {"uk": "Дисковий телефон", "en": "Rotary Phone"},
		"desc": {"uk": "Іноді дзвонить. Слухавка мовчить і дихає.", "en": "Sometimes it rings. The receiver just breathes."}},
	"steam_gear": {"era": D_PAST, "rarity": 1, "name": {"uk": "Парова шестерня", "en": "Steam Gear"},
		"desc": {"uk": "Тепла на дотик через двісті років.", "en": "Still warm after two hundred years."}},
	"quill": {"era": D_PAST, "rarity": 2, "name": {"uk": "Перо літописця", "en": "Chronicler's Quill"},
		"desc": {"uk": "Пише лише правду. Тому пише дуже повільно.", "en": "Writes only the truth. So it writes very slowly."}},
	"tin_robot": {"era": D_PAST, "rarity": 2, "name": {"uk": "Бляшаний робот", "en": "Tin Robot"},
		"desc": {"uk": "Іграшка 1956 року. БІТ називає його «дідом».", "en": "A 1956 toy. BIT calls it \"grandpa\"."}},
	"vinyl": {"era": D_PAST, "rarity": 1, "name": {"uk": "Платівка", "en": "Vinyl Record"},
		"desc": {"uk": "Якщо крутити назад — чути прогноз погоди.", "en": "Played backwards it gives the weather forecast."}},
	"postcard": {"era": D_PRESENT, "rarity": 1, "name": {"uk": "Листівка 404", "en": "Postcard 404"},
		"desc": {"uk": "«Вітання з пошти, якої немає в мапах».", "en": "\"Greetings from a post office no map shows.\""}},
	"stamp_404": {"era": D_PRESENT, "rarity": 2, "name": {"uk": "Марка №404", "en": "Stamp No. 404"},
		"desc": {"uk": "Надрукована з помилкою. Помилка — це ти.", "en": "Misprinted. The misprint is you."}},
	"umbrella": {"era": D_PRESENT, "rarity": 1, "name": {"uk": "Парасоля від Олени", "en": "Olena's Umbrella"},
		"desc": {"uk": "Розкривається, щойно хтось засмутиться.", "en": "Opens whenever someone is sad."}},
	"holo_cube": {"era": D_FUTURE, "rarity": 1, "name": {"uk": "Голокуб", "en": "Holo Cube"},
		"desc": {"uk": "Показує кімнату, у якій ти ще не був.", "en": "Shows a room you haven't been to yet."}},
	"mars_rock": {"era": D_FUTURE, "rarity": 1, "name": {"uk": "Марсіанський камінь", "en": "Mars Pebble"},
		"desc": {"uk": "Сувенір. На звороті: «звідти, де ти будеш».", "en": "A souvenir. On the back: \"from where you'll be\"."}},
	"hover_skate": {"era": D_FUTURE, "rarity": 2, "name": {"uk": "Ховерскейт Кая", "en": "Kai's Hover Skate"},
		"desc": {"uk": "Запасний. Кай казав, що віддасть «колись».", "en": "The spare one. Kai said you'd get it \"someday\"."}},
	"neural_chip": {"era": D_FUTURE, "rarity": 2, "name": {"uk": "Нейрочип", "en": "Neural Chip"},
		"desc": {"uk": "Пам'ятає сни людей, яких ще не народилося.", "en": "Remembers dreams of people not yet born."}},
	"plasma_stamp": {"era": D_FUTURE, "rarity": 1, "name": {"uk": "Плазмовий штемпель", "en": "Plasma Stamp"},
		"desc": {"uk": "Ставить відбиток просто на повітрі.", "en": "Stamps straight onto thin air."}},
	"robo_pet": {"era": D_FUTURE, "rarity": 1, "name": {"uk": "Робопесик", "en": "Robo Puppy"},
		"desc": {"uk": "Гавкає двійковим кодом. БІТ перекладає: «люблю».", "en": "Barks in binary. BIT translates: \"love\"."}},
	"star_map": {"era": D_FUTURE, "rarity": 2, "name": {"uk": "Зоряна мапа", "en": "Star Map"},
		"desc": {"uk": "Маршрути пошти між зорями. Відділення №404 — у центрі.", "en": "Postal routes between stars. Office 404 is in the middle."}},
	"time_crystal": {"era": D_FUTURE, "rarity": 2, "name": {"uk": "Кристал часу", "en": "Time Crystal"},
		"desc": {"uk": "Завжди трохи старший, ніж учора.", "en": "Always a little older than yesterday."}},
	"paradox_cup": {"era": -1, "rarity": 2, "name": {"uk": "Парадоксальна чашка", "en": "Paradox Cup"},
		"desc": {"uk": "Розбита й ціла водночас. Кава не витікає.", "en": "Broken and whole at once. The coffee stays in."}},
	"mobius_letter": {"era": -1, "rarity": 2, "name": {"uk": "Лист Мебіуса", "en": "Möbius Letter"},
		"desc": {"uk": "Відповідає сам собі. Розмова триває роками.", "en": "It replies to itself. The chat has lasted years."}},
	"quant_whisker": {"era": -1, "rarity": 1, "name": {"uk": "Вус Кванта", "en": "Quant's Whisker"},
		"desc": {"uk": "Кіт загубив його в трьох епохах одночасно.", "en": "The cat lost it in three eras at once."}},
	"erased_photo": {"era": -1, "rarity": 3, "name": {"uk": "Стерта світлина", "en": "Erased Photo"},
		"desc": {"uk": "Свято, якого ніколи не було. Усі на ній щасливі.", "en": "A festival that never happened. Everyone is happy in it."}},
	"oracle_shard": {"era": -1, "rarity": 3, "name": {"uk": "Уламок Оракула", "en": "Oracle Shard"},
		"desc": {"uk": "Тихо рахує ймовірності. Ти в них — 0,404%.", "en": "Quietly counts probabilities. You are 0.404%."}},
	"future_key": {"era": -1, "rarity": 3, "name": {"uk": "Ключ 2057", "en": "Key of 2057"},
		"desc": {"uk": "Від поштової скриньки, яку ти відкриєш через 19 років.", "en": "For a mailbox you'll open in 19 years."}},
}

const COLLECTIBLE_ORDER := ["pocket_watch", "wax_seal", "floppy", "cassette", "rotary_phone", "steam_gear",
	"quill", "tin_robot", "vinyl", "postcard", "stamp_404", "umbrella", "holo_cube", "mars_rock",
	"hover_skate", "neural_chip", "plasma_stamp", "robo_pet", "star_map", "time_crystal",
	"paradox_cup", "mobius_letter", "quant_whisker", "erased_photo", "oracle_shard", "future_key"]

## Box styles; purely visual, independent of the destination (no shortcut).
const BOX_STYLES := ["cardboard", "paper", "crate", "envelope", "tube", "metal"]


static func riddle_ids_for(dest: int) -> Array:
	var out := []
	for k in RIDDLES:
		if int(RIDDLES[k]["dest"]) == dest:
			out.append(k)
	return out


## Seasonal look of the daily anomaly, by month.
static func season(month: int) -> String:
	if month == 12 or month <= 2:
		return "winter"
	if month <= 5:
		return "spring"
	if month <= 8:
		return "summer"
	return "autumn"
