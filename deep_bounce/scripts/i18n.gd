extends RefCounted
## All interface text in English and Ukrainian. The game title "Deep Bounce" is never translated.

const LANGS := ["en", "uk"]

const S := {
	"play": ["Play", "Грати"],
	"continue": ["Continue", "Продовжити"],
	"cosmetics": ["Cosmetics", "Оздоблення"],
	"settings": ["Settings", "Налаштування"],
	"best_depth": ["Best depth: {0} m", "Рекорд глибини: {0} м"],
	"depth": ["Depth {0} m", "Глибина {0} м"],
	"meters": ["{0} m", "{0} м"],
	"new_run_q": ["Start a new run? The saved run will be lost.", "Почати новий забіг? Збережений забіг буде втрачено."],
	"yes": ["Yes", "Так"],
	"no": ["No", "Ні"],
	"back": ["Back", "Назад"],
	"paused": ["Paused", "Пауза"],
	"resume": ["Resume", "Продовжити"],
	"end_run": ["End run", "Завершити забіг"],
	"end_run_q": ["End this run now? Your depth will count for the record.", "Завершити цей забіг? Досягнута глибина піде в рекорд."],
	"main_menu": ["Main menu", "Головне меню"],
	"run_over": ["Run over", "Забіг завершено"],
	"depth_reached": ["Depth reached", "Досягнута глибина"],
	"record": ["Record", "Рекорд"],
	"new_record": ["New record!", "Новий рекорд!"],
	"crystals_earned": ["Crystals earned", "Зароблено кристалів"],
	"stones_broken": ["Stones broken", "Розбито каменів"],
	"play_again": ["Play Again", "Ще забіг"],
	"menu": ["Menu", "Меню"],
	"choose_upgrade": ["Choose an upgrade", "Обери посилення"],
	"up_balls": ["More balls", "Більше кульок"],
	"up_balls_d": ["+2 balls in every volley ({0} → {1}, max 32)", "+2 кульки в кожному залпі ({0} → {1}, максимум 32)"],
	"up_heavy": ["Heavy balls", "Важкі кульки"],
	"up_heavy_d": ["Every 4th ball hits for {0} on a direct hit", "Кожна четверта кулька б'є на {0} при прямому влучанні"],
	"up_electric": ["Electric balls", "Електричні кульки"],
	"up_electric_d": ["Balls 2, 6, 10… : every 4th direct hit sparks {0} damage to the nearest stone", "Кульки 2, 6, 10…: кожне четверте пряме влучання б'є найближчий камінь на {0}"],
	"level": ["Level {0}", "Рівень {0}"],
	"level_to": ["Level {0} → {1}", "Рівень {0} → {1}"],
	"maxed_bonus": ["All upgrades maxed: +{0} crystals", "Усі посилення розвинуто: +{0} кристалів"],
	"language": ["Language", "Мова"],
	"sound": ["Sound", "Звук"],
	"music": ["Music", "Музика"],
	"vibration": ["Vibration", "Вібрація"],
	"shake": ["Screen shake", "Тремтіння екрана"],
	"shake_0": ["Off", "Вимк."],
	"shake_1": ["Low", "Слабке"],
	"shake_2": ["Medium", "Середнє"],
	"shake_3": ["Strong", "Сильне"],
	"on": ["On", "Увімк."],
	"off": ["Off", "Вимк."],
	"replay_tutorial": ["Replay tutorial", "Повторити навчання"],
	"tutorial_reset": ["Hints will show again in your next volley.", "Підказки з'являться знову в наступному залпі."],
	"lang_name": ["English", "Українська"],
	"owned": ["Owned", "Придбано"],
	"buy": ["Buy", "Купити"],
	"select": ["Select", "Обрати"],
	"selected": ["Selected", "Обрано"],
	"not_enough": ["Not enough crystals", "Бракує кристалів"],
	"bought": ["Purchased!", "Придбано!"],
	"cos_hint": ["Your cannon finish appears in the next volley.", "Оздоблення гармати з'явиться в наступному залпі."],
	"skin_classic": ["Teal & Copper", "Бірюза й мідь"],
	"skin_classic_d": ["The trusty mine cannon.", "Надійна шахтарська гармата."],
	"skin_ember": ["Ember Iron", "Жарове залізо"],
	"skin_ember_d": ["Blackened iron with a glowing core.", "Чорнене залізо з жаринним серцем."],
	"skin_brass": ["Royal Brass", "Королівська латунь"],
	"skin_brass_d": ["Polished brass and teal enamel.", "Полірована латунь і бірюзова емаль."],
	"skin_crystal": ["Crystal Core", "Кристальне серце"],
	"skin_crystal_d": ["Deep-mine steel grown with crystals.", "Глибинна сталь, проросла кристалами."],
	"tut_aim": ["Swipe anywhere to aim, release to fire", "Проведи пальцем будь-де, щоб прицілитись, і відпусти"],
	"tut_strength": ["The number is the stone's strength: each hit takes 1", "Число — міцність каменю: кожне влучання знімає 1"],
	"tut_ricochet": ["Bounce off the walls: the line shows the first rebound", "Відбивай від стін: лінія показує перший рикошет"],
	"tut_danger": ["If stone crosses this line, the run ends", "Якщо камінь перетне цю лінію, забіг закінчиться"],
	"tut_upgrade": ["Every 4 volleys: pick an upgrade", "Кожні 4 залпи — вибір посилення"],
	"next_upgrade": ["Upgrade in {0}", "Посилення через {0}"],
	"heavy_short": ["Heavy {0}", "Важкі {0}"],
	"electric_short": ["Electric {0}", "Електр. {0}"],
	"speed": ["Speed ×{0}", "Швидкість ×{0}"],
	"recall": ["Recall", "Повернути"],
	"tap_continue": ["Tap to continue", "Торкнись, щоб продовжити"],
	"offline": ["Fully offline", "Повністю офлайн"],
	"version": ["Version {0}", "Версія {0}"],
}

static func balls_text(n: int, lang: int) -> String:
	if lang == 0:
		return "%d ball" % n if n == 1 else "%d balls" % n
	var m10 := n % 10
	var m100 := n % 100
	if m10 == 1 and m100 != 11:
		return "%d кулька" % n
	if m10 >= 2 and m10 <= 4 and (m100 < 12 or m100 > 14):
		return "%d кульки" % n
	return "%d кульок" % n
