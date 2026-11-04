extends Node
## Localization: Ukrainian and English. To add a language, add its code to
## LANGS and a value under that code to every entry (missing ones fall back
## to English).

signal changed

const LANGS := ["uk", "en"]

var lang := "uk"

const STRINGS := {
	"title": {"uk": "TIME POST", "en": "TIME POST"},
	"subtitle": {"uk": "Посилки з майбутнього", "en": "Parcels From Tomorrow"},
	"btn_shift": {"uk": "Почати зміну", "en": "Start shift"},
	"btn_calm": {"uk": "Спокійна зміна", "en": "Calm shift"},
	"btn_record": {"uk": "Рекорд", "en": "Record run"},
	"btn_daily": {"uk": "Щоденна аномалія", "en": "Daily anomaly"},
	"btn_office": {"uk": "Відділення", "en": "Office"},
	"btn_collection": {"uk": "Колекція", "en": "Collection"},
	"btn_mail": {"uk": "Листи", "en": "Letters"},
	"btn_settings": {"uk": "Налаштування", "en": "Settings"},
	"btn_story": {"uk": "Нова глава!", "en": "New chapter!"},
	"btn_back": {"uk": "Назад", "en": "Back"},
	"btn_continue": {"uk": "Далі", "en": "Continue"},
	"btn_again": {"uk": "Ще зміну", "en": "Another shift"},
	"btn_menu": {"uk": "У меню", "en": "Menu"},
	"btn_resume": {"uk": "Продовжити", "en": "Resume"},
	"btn_end_shift": {"uk": "Завершити зміну", "en": "End shift"},
	"btn_ok": {"uk": "Зрозуміло", "en": "Got it"},
	"btn_skip": {"uk": "Пропустити", "en": "Skip"},
	"btn_yes": {"uk": "Так", "en": "Yes"},
	"btn_no": {"uk": "Ні", "en": "No"},
	"btn_chapters": {"uk": "Глави", "en": "Chapters"},
	"level_n": {"uk": "Рівень %d", "en": "Level %d"},
	"shift_n": {"uk": "Зміна №%d", "en": "Shift #%d"},
	"today": {"uk": "СЬОГОДНІ", "en": "TODAY"},
	"combo": {"uk": "серія", "en": "combo"},
	"paused": {"uk": "Пауза", "en": "Paused"},
	"dir_past": {"uk": "МИНУЛЕ", "en": "PAST"},
	"dir_present": {"uk": "ЗАРАЗ", "en": "PRESENT"},
	"dir_future": {"uk": "МАЙБУТНЄ", "en": "FUTURE"},
	"dir_quarantine": {"uk": "КАРАНТИН", "en": "QUARANTINE"},
	"record_best": {"uk": "Рекорд: %d", "en": "Best: %d"},
	"daily_done": {"uk": "Нагороду отримано. Найкраще: %d", "en": "Reward claimed. Best: %d"},
	"daily_new": {"uk": "Нагорода: уламки часу", "en": "Reward: time shards"},
	"mut_mirror": {"uk": "Дзеркальний день: минуле праворуч", "en": "Mirror day: past is on the right"},
	"mut_calendar": {"uk": "Сьогодні — 2050 рік", "en": "Today is the year 2050"},
	"mut_rush": {"uk": "Термінові посилки скрізь", "en": "Urgent parcels everywhere"},
	"mut_mystery": {"uk": "День загадок", "en": "Day of riddles"},
	"locked_level": {"uk": "Відкриється на рівні %d", "en": "Unlocks at level %d"},
	# Results
	"res_done": {"uk": "Зміну завершено!", "en": "Shift complete!"},
	"res_failed": {"uk": "Зміну зірвано", "en": "Shift interrupted"},
	"res_failed_hint": {"uk": "Надійність вичерпано. Монети за зміну збережено.", "en": "Out of reliability. You keep the coins you earned."},
	"res_record_over": {"uk": "Забіг завершено", "en": "Run over"},
	"res_calm": {"uk": "Спокійну зміну завершено", "en": "Calm shift finished"},
	"res_sorted": {"uk": "Відсортовано", "en": "Sorted"},
	"res_accuracy": {"uk": "Точність", "en": "Accuracy"},
	"res_combo": {"uk": "Найдовша серія", "en": "Best combo"},
	"res_score": {"uk": "Очки", "en": "Score"},
	"res_coins": {"uk": "Монети", "en": "Coins"},
	"res_bonus": {"uk": "зокрема бонус", "en": "incl. bonus"},
	"res_xp": {"uk": "Досвід", "en": "XP"},
	"res_shards": {"uk": "Уламки часу", "en": "Time shards"},
	"res_new_record": {"uk": "НОВИЙ РЕКОРД!", "en": "NEW RECORD!"},
	"res_level_up": {"uk": "Новий рівень: %d!", "en": "Level up: %d!"},
	"res_found": {"uk": "Нові знахідки", "en": "New finds"},
	"res_unlocked": {"uk": "Відкрито", "en": "Unlocked"},
	"res_series": {"uk": "Серій зібрано", "en": "Series completed"},
	# Office
	"office_title": {"uk": "Відділення №404", "en": "Office No. 404"},
	"tab_machines": {"uk": "Техніка", "en": "Machines"},
	"tab_rooms": {"uk": "Кімнати", "en": "Rooms"},
	"tab_decor": {"uk": "Декор", "en": "Decor"},
	"tab_equip": {"uk": "Рідкісне", "en": "Rare"},
	"tab_routes": {"uk": "Маршрути", "en": "Routes"},
	"buy": {"uk": "Купити", "en": "Buy"},
	"owned": {"uk": "Є", "en": "Owned"},
	"maxed": {"uk": "Макс.", "en": "Max"},
	"lvl": {"uk": "рів. %d/%d", "en": "lv %d/%d"},
	"need_room": {"uk": "Потрібна кімната відпочинку", "en": "Needs the Lounge"},
	"route_mult": {"uk": "Нагорода ×%s", "en": "Reward ×%s"},
	"bought": {"uk": "Придбано: %s", "en": "Bought: %s"},
	# Collection & mail
	"col_title": {"uk": "Колекція", "en": "Collection"},
	"col_found": {"uk": "Знайдено %d з %d", "en": "Found %d of %d"},
	"col_unknown": {"uk": "Ще не знайдено", "en": "Not found yet"},
	"col_count": {"uk": "×%d", "en": "×%d"},
	"era_past": {"uk": "Минуле", "en": "Past"},
	"era_present": {"uk": "Теперішнє", "en": "Present"},
	"era_future": {"uk": "Майбутнє", "en": "Future"},
	"era_anomaly": {"uk": "Аномалія", "en": "Anomaly"},
	"mail_title": {"uk": "Листи", "en": "Letters"},
	"mail_empty": {"uk": "Поки що листів немає. Люди пишуть тим, хто їм допомагає.", "en": "No letters yet. People write to those who help them."},
	"chapters_title": {"uk": "Історія", "en": "Story"},
	"chapter_next": {"uk": "Далі: %s", "en": "Next: %s"},
	"chapter_req": {"uk": "Потрібно: змін %d, рівень %d", "en": "Needs: %d shifts, level %d"},
	"chapter_req_robot": {"uk": "Полагодь БІТа (рів. %d) у «Відділенні»", "en": "Repair BIT (lv %d) in the Office"},
	"ending_got": {"uk": "Кінцівка: %s", "en": "Ending: %s"},
	"option_locked": {"uk": "Потрібно більше пам'яті БІТа й надії", "en": "Needs more of BIT's memory and hope"},
	# Settings
	"set_title": {"uk": "Налаштування", "en": "Settings"},
	"set_lang": {"uk": "Мова", "en": "Language"},
	"set_music": {"uk": "Музика", "en": "Music"},
	"set_sfx": {"uk": "Звуки", "en": "Sounds"},
	"set_haptics": {"uk": "Вібрація", "en": "Vibration"},
	"set_buttons": {"uk": "Кнопки напрямків", "en": "Direction buttons"},
	"set_motion": {"uk": "Менше руху", "en": "Reduce motion"},
	"set_fps": {"uk": "Частота кадрів", "en": "Frame rate"},
	"set_hints": {"uk": "Підказки свайпів", "en": "Swipe hints"},
	"set_reset": {"uk": "Скинути прогрес", "en": "Reset progress"},
	"set_reset_confirm": {"uk": "Справді стерти весь прогрес? Цю дію не скасувати.", "en": "Really erase all progress? This can't be undone."},
	"set_replay_tut": {"uk": "Повторити навчання", "en": "Replay tutorial"},
	"on": {"uk": "Увімк.", "en": "On"},
	"off": {"uk": "Вимк.", "en": "Off"},
	"lang_name": {"uk": "Українська", "en": "English"},
	# In-shift feedback
	"fb_perfect": {"uk": "Точно!", "en": "Spot on!"},
	"fb_wrong": {"uk": "Не туди! Треба: %s", "en": "Wrong way! Should be: %s"},
	"fb_timeout": {"uk": "Не встиг! Треба: %s", "en": "Too slow! Should be: %s"},
	"fb_urgent": {"uk": "Терміново — вчасно!", "en": "Urgent — on time!"},
	"fb_series": {"uk": "Серію зібрано! +%d", "en": "Series complete! +%d"},
	"fb_found": {"uk": "Знахідка: %s", "en": "Found: %s"},
	"fb_shield": {"uk": "БІТ врятував серію!", "en": "BIT saved your combo!"},
	"fb_robot": {"uk": "БІТ допоміг", "en": "BIT helped"},
	"fb_shard": {"uk": "+1 уламок часу", "en": "+1 time shard"},
	"fb_cat": {"uk": "Квант муркоче: +1 уламок", "en": "Quant purrs: +1 shard"},
	"n_shards": {"uk": "уламки: %d", "en": "shards: %d"},
	"fb_repair": {"uk": "Жолоб полагоджено: +1 надійність", "en": "Chute repaired: +1 reliability"},
	"fb_free": {"uk": "Фільтр парадоксів поглинув помилку", "en": "Paradox filter absorbed the mistake"},
	"ev_golden": {"uk": "ЗОЛОТА ГОДИНА: монети ×2", "en": "GOLDEN HOUR: coins ×2"},
	"ev_calendar": {"uk": "ЗСУВ КАЛЕНДАРЯ: сьогодні %d!", "en": "CALENDAR SHIFT: today is %d!"},
	"ev_mirror": {"uk": "ДЗЕРКАЛО: минуле праворуч!", "en": "MIRROR: past is on the right!"},
	"ev_cat": {"uk": "Квант на стрічці! Торкнись кота", "en": "Quant on the belt! Tap the cat"},
	"ev_storm": {"uk": "ЧАСОВА БУРЯ: швидко й ×2 очок", "en": "TIME STORM: fast and ×2 score"},
	"ev_end": {"uk": "Аномалія минула", "en": "Anomaly over"},
	"tut_past": {"uk": "1998 менше за 2038 — це минуле.\nСвайп ЛІВОРУЧ", "en": "1998 is before 2038 — the past.\nSwipe LEFT"},
	"tut_future": {"uk": "2077 більше за 2038 — це майбутнє.\nСвайп ПРАВОРУЧ", "en": "2077 is after 2038 — the future.\nSwipe RIGHT"},
	"tut_close": {"uk": "Уважно: 2040 — це вже майбутнє", "en": "Careful: 2040 is already the future"},
	"tut_free": {"uk": "Тепер сам! Порівнюй рік із табло «СЬОГОДНІ»", "en": "Your turn! Compare the year with the TODAY board"},
	"idle_income": {"uk": "Кавоварка заробила %d монет, поки тебе не було", "en": "The coffee machine made %d coins while you were away"},
	"save_recovered": {"uk": "Збереження було пошкоджене — відновлено з резервної копії", "en": "The save was damaged — restored from backup"},
	"save_reset": {"uk": "Збереження не вдалося прочитати — почато нову гру", "en": "The save couldn't be read — a new game was started"},
	"new_letter": {"uk": "Новий лист!", "en": "New letter!"},
	"swipe_hint": {"uk": "Свайпни посилку", "en": "Swipe the parcel"},
	"label_from": {"uk": "РІК", "en": "YEAR"},
	"label_was": {"uk": "було", "en": "was"},
	"label_series": {"uk": "Серія %s %d/%d", "en": "Series %s %d/%d"},
	"label_hazard": {"uk": "НЕБЕЗПЕЧНО", "en": "HAZARD"},
	"label_urgent": {"uk": "ТЕРМІНОВО", "en": "URGENT"},
	# New mechanic tips (shown once, the game pauses)
	"tip_present": {"uk": "Рік збігається з табло «СЬОГОДНІ»? Це теперішнє — свайп УГОРУ, у пневмопошту.", "en": "Year matches the TODAY board? That's the present — swipe UP into the pneumatic tube."},
	"tip_damaged": {"uk": "Етикетку пошкоджено, але видимих цифр вистачає. «19??» — точно минуле. Гра ніколи не змушує вгадувати.", "en": "The label is smudged, but the visible digits are enough. \"19??\" is surely the past. You never have to guess."},
	"tip_urgent": {"uk": "Термінова посилка: відсортуй за 3 секунди — отримаєш більше монет. Запізнення не карається.", "en": "Urgent parcel: sort it within 3 seconds for extra coins. Being late is not punished."},
	"tip_series": {"uk": "Серія посилок: усі частини правильно — і буде великий бонус.", "en": "Parcel series: get every part right for a big bonus."},
	"tip_mystery": {"uk": "Загадкова посилка: року немає, але є підказка про епоху. Диліжанс — минуле, Марс — майбутнє.", "en": "Mystery parcel: no year, but a clue about the era. A stagecoach is the past, Mars is the future."},
	"tip_hazard": {"uk": "Небезпечний часовий артефакт! Рік не важливий — лише свайп УНИЗ, у карантин.", "en": "Dangerous time artefact! The year doesn't matter — swipe DOWN into quarantine."},
	"tip_paradox": {"uk": "Парадокс: рік виправлено. Перекреслене ігноруй, дивись на новий рік.", "en": "Paradox: the year was corrected. Ignore the crossed-out one, read the new year."},
	"tip_collectible": {"uk": "Золота коробка! Відсортуй правильно — і предмет потрапить у колекцію.", "en": "A golden box! Sort it correctly and the item joins your collection."},
	"tip_sender": {"uk": "Посилка від знайомих. Правила ті самі, але друзі це запам'ятають.", "en": "A parcel from someone you know. Same rules, but friends will remember."},
	"tip_ev_golden": {"uk": "Золота година: кілька секунд усі монети подвоюються!", "en": "Golden hour: for a few seconds all coins are doubled!"},
	"tip_ev_calendar": {"uk": "Зсув календаря! Табло «СЬОГОДНІ» показує інший рік — порівнюй з ним, доки аномалія не мине.", "en": "Calendar shift! The TODAY board shows a different year — compare with it until the anomaly passes."},
	"tip_ev_mirror": {"uk": "Дзеркальна аномалія: портали помінялися місцями. Минуле тепер ПРАВОРУЧ, майбутнє — ЛІВОРУЧ.", "en": "Mirror anomaly: the portals swapped. The past is now on the RIGHT, the future on the LEFT."},
	"tip_ev_cat": {"uk": "Кіт Квант гуляє епохами. Торкнися його — він залишить уламок часу.", "en": "Quant the cat wanders through eras. Tap him and he leaves a time shard."},
	"tip_ev_storm": {"uk": "Часова буря: посилки летять без пауз, але очки подвоюються.", "en": "Time storm: parcels come with no pauses, but score is doubled."},
	# Unlock announcements
	"unlock_present": {"uk": "Теперішнє: свайп угору", "en": "Present: swipe up"},
	"unlock_collectibles": {"uk": "Рідкісні золоті посилки", "en": "Rare golden parcels"},
	"unlock_damaged": {"uk": "Пошкоджені етикетки", "en": "Damaged labels"},
	"unlock_urgent": {"uk": "Термінові доставки", "en": "Urgent deliveries"},
	"unlock_series": {"uk": "Серії посилок", "en": "Parcel series"},
	"unlock_ev_golden": {"uk": "Подія: золота година", "en": "Event: golden hour"},
	"unlock_mystery": {"uk": "Загадкові відправлення", "en": "Mystery parcels"},
	"unlock_daily": {"uk": "Щоденна аномалія", "en": "Daily anomaly"},
	"unlock_hazard": {"uk": "Небезпечні артефакти: карантин", "en": "Hazardous artefacts: quarantine"},
	"unlock_ev_calendar": {"uk": "Аномалія: зсув календаря", "en": "Anomaly: calendar shift"},
	"unlock_ev_cat": {"uk": "Подія: кіт Квант", "en": "Event: Quant the cat"},
	"unlock_ev_mirror": {"uk": "Аномалія: дзеркало", "en": "Anomaly: mirror"},
	"unlock_paradox": {"uk": "Парадоксальні посилки", "en": "Paradox parcels"},
	"unlock_ev_storm": {"uk": "Подія: часова буря", "en": "Event: time storm"},
	"mech_boomerang": {"uk": "Посилка-бумеранг", "en": "Boomerang parcel"},
	"mech_ev_blackout": {"uk": "Відключення світла", "en": "Blackout"},
	"unlock_boomerang": {"uk": "Посилки-бумеранги", "en": "Boomerang parcels"},
	"unlock_ev_blackout": {"uk": "Подія: відключення світла", "en": "Event: blackout"},
	"tip_boomerang": {"uk": "Посилка-бумеранг: якщо помилишся, вона повернеться — і надійність не впаде. Правильно з першого разу — ×1,5 монет.", "en": "Boomerang parcel: if you get it wrong it comes back and costs no reliability. Right the first time pays ×1.5 coins."},
	"tip_ev_blackout": {"uk": "Світло зникло! Лампа над столом ще світить — етикетку видно. Черги на стрічці не видно, зате монети ×1,5.", "en": "The lights are out! The desk lamp still works, so the label is readable. You can't see the queue, but coins are ×1.5."},
	"ev_blackout": {"uk": "ВІДКЛЮЧЕННЯ СВІТЛА: монети ×1,5", "en": "BLACKOUT: coins ×1.5"},
	"fb_boomerang": {"uk": "Бумеранг повертається — ще одна спроба!", "en": "The boomerang comes back — try again!"},
	"mut_blackout": {"uk": "День без світла", "en": "Day without light"},
	"mut_boomerang": {"uk": "День бумерангів", "en": "Boomerang day"},
	"season_winter": {"uk": "Зимова пошта", "en": "Winter post"},
	"season_spring": {"uk": "Весняна пошта", "en": "Spring post"},
	"season_summer": {"uk": "Літня пошта", "en": "Summer post"},
	"season_autumn": {"uk": "Осіння пошта", "en": "Autumn post"},
	"tab_items": {"uk": "Предмети", "en": "Items"},
	"tab_achievements": {"uk": "Досягнення", "en": "Achievements"},
	"tab_stats": {"uk": "Статистика", "en": "Stats"},
	"ach_got": {"uk": "Досягнення: %s", "en": "Achievement: %s"},
	"ach_count": {"uk": "Отримано %d з %d", "en": "Earned %d of %d"},
	"ach_reward": {"uk": "Нагорода: уламки: %d", "en": "Reward: shards: %d"},
	"res_achievements": {"uk": "Нові досягнення", "en": "New achievements"},
	"res_letters": {"uk": "Нові листи від друзів: %d", "en": "New letters from friends: %d"},
	"st_shifts": {"uk": "Змін відпрацьовано", "en": "Shifts worked"},
	"st_parcels": {"uk": "Посилок відсортовано", "en": "Parcels sorted"},
	"st_accuracy": {"uk": "Точність за весь час", "en": "All-time accuracy"},
	"st_combo": {"uk": "Найдовша серія", "en": "Best combo"},
	"st_record": {"uk": "Рекорд", "en": "Record run"},
	"st_calm": {"uk": "Найкраща спокійна зміна", "en": "Best calm shift"},
	"st_coins": {"uk": "Монет зароблено", "en": "Coins earned"},
	"st_time": {"uk": "Час у грі", "en": "Time played"},
	"st_dailies": {"uk": "Щоденних аномалій", "en": "Daily anomalies"},
	"st_hazards": {"uk": "Артефактів у карантині", "en": "Artefacts quarantined"},
	"st_events": {"uk": "Подій пережито", "en": "Events survived"},
	"st_level": {"uk": "Рівень", "en": "Level"},
	"mech_present": {"uk": "Теперішнє", "en": "The present"},
	"mech_damaged": {"uk": "Пошкоджена етикетка", "en": "Damaged label"},
	"mech_urgent": {"uk": "Термінова доставка", "en": "Urgent delivery"},
	"mech_series": {"uk": "Серія посилок", "en": "Parcel series"},
	"mech_mystery": {"uk": "Загадкове відправлення", "en": "Mystery parcel"},
	"mech_hazard": {"uk": "Часовий артефакт", "en": "Time artefact"},
	"mech_paradox": {"uk": "Парадокс", "en": "Paradox"},
	"mech_collectible": {"uk": "Колекційна посилка", "en": "Collectible parcel"},
	"mech_sender": {"uk": "Посилка від друзів", "en": "Parcel from friends"},
	"mech_ev_golden": {"uk": "Золота година", "en": "Golden hour"},
	"mech_ev_calendar": {"uk": "Зсув календаря", "en": "Calendar shift"},
	"mech_ev_mirror": {"uk": "Дзеркальна аномалія", "en": "Mirror anomaly"},
	"mech_ev_cat": {"uk": "Кіт Квант", "en": "Quant the cat"},
	"mech_ev_storm": {"uk": "Часова буря", "en": "Time storm"},
}

## BIT's comments during a shift.
const BIT_OK := {
	"uk": ["Біп! Чудово.", "Мої сенсори задоволені.", "Так тримати, Шефе!", "Ідеально по штемпелю.", "Я б краще не зробив. Хоча ні, зробив би.",
		"Час подякує вам. Колись.", "Ще одна історія врятована.", "Ох, як рівненько пішло!", "Записую у звіт: «геніально»."],
	"en": ["Beep! Lovely.", "My sensors are pleased.", "Keep it up, Boss!", "Stamp-perfect.", "I couldn't do better. Well, I could.",
		"Time will thank you. Eventually.", "Another story saved.", "Ooh, smooth delivery!", "Noting in the report: \"genius\"."],
}
const BIT_ERR := {
	"uk": ["Ой. Хтось у 1812-му отримає мікрохвильовку.", "Не страшно, я вдам, що не бачив.", "Рік, Шефе, дивіться на рік!", "Це посилка пішла на екскурсію.",
		"Динозаври будуть у захваті від смартфона.", "Нічого, я теж колись відправив сам себе у 1995-й.", "Глибокий вдих. Табло «СЬОГОДНІ» — наш друг."],
	"en": ["Oops. Someone in 1812 just got a microwave.", "No worries, I'll pretend I didn't see.", "The year, Boss, read the year!", "That parcel went sightseeing.",
		"The dinosaurs will love that smartphone.", "It's fine, I once mailed myself to 1995.", "Deep breath. The TODAY board is our friend."],
}
const BIT_IDLE := {
	"uk": ["Уся пошта світу — і ми.", "Знаєте, я колись сортував листи для Діда Мороза.", "Ця лампа блимає з 2003-го. Я до неї звик.", "Якщо що — я тут. Завжди тут. Буквально прикручений.",
		"Квант знову спав на стрічці. Я не скаржуся, він теплий.", "Мені наснилося, що я тостер. Було страшно.", "Ви помітили, що годинник іде назад по вівторках?",
		"Олена принесла пиріжки. Я не їм, але пахне правильно.", "ОРАКУЛ сьогодні тихий. Підозріло тихий."],
	"en": ["All the mail in the world — and us.", "I once sorted letters for Santa, you know.", "That lamp has flickered since 2003. I'm used to it.", "If you need me, I'm here. Always. Literally bolted down.",
		"Quant slept on the belt again. I don't mind, he's warm.", "I dreamt I was a toaster. It was scary.", "Have you noticed the clock runs backwards on Tuesdays?",
		"Olena brought pies. I don't eat, but they smell correct.", "The ORACLE is quiet today. Suspiciously quiet."],
}

const BIT_COMBO := {
	"uk": ["Серія! Мої шестерні танцюють!", "Не зупиняйтесь, Шефе!", "Це вже не сортування, це музика.", "Конвеєр ледве встигає за вами!"],
	"en": ["Combo! My gears are dancing!", "Don't stop, Boss!", "This isn't sorting anymore, it's music.", "The belt can barely keep up!"],
}
const BIT_LOWTIME := {
	"uk": ["Десять секунд! Тиснемо!", "Фінішна пряма, Шефе!"],
	"en": ["Ten seconds! Push!", "Final stretch, Boss!"],
}
const BIT_EVENT := {
	"golden": ["Золото! Хапайте, поки блищить!", "Gold! Grab it while it shines!"],
	"calendar": ["Календар з'їхав! Дивіться на табло!", "The calendar slipped! Watch the board!"],
	"mirror": ["Усе навпаки! Минуле праворуч!", "Everything's flipped! Past is on the right!"],
	"cat": ["Квант! Погладьте його!", "Quant! Pet him!"],
	"storm": ["Буря! Тримайтеся за штемпель!", "A storm! Hold on to your stamp!"],
	"blackout": ["Хто вимкнув світло?! Добре, що лампа на батарейках.", "Who turned off the lights?! Good thing the lamp has batteries."],
}


func _ready() -> void:
	var sys := OS.get_locale_language()
	lang = "uk" if sys in ["uk", "ru", "be"] else "en"


func set_lang(code: String) -> void:
	if code in LANGS:
		lang = code
		TranslationServer.set_locale(code)
		changed.emit()


func t(key: String, args = null) -> String:
	var e: Dictionary = STRINGS.get(key, {})
	var s: String = e.get(lang, e.get("en", key))
	if args == null:
		return s
	if args is Array:
		return s % args
	return s % [args]


## Picks the current language from {"uk":..,"en":..} or ["uk", "en"].
func pick(v) -> String:
	if v is Dictionary:
		return v.get(lang, v.get("en", ""))
	if v is Array:
		var i := LANGS.find(lang)
		return v[i] if i >= 0 and i < v.size() else v[v.size() - 1]
	return str(v)


func line(v: Array, offset: int = 1) -> String:
	## Story lines are [speaker, uk, en].
	var i := LANGS.find(lang)
	return v[offset + max(i, 0)] if offset + i < v.size() else v[v.size() - 1]


func bit_line(kind: String, rng: RandomNumberGenerator) -> String:
	if kind.begins_with("event:"):
		var e: Array = BIT_EVENT.get(kind.substr(6), ["", ""])
		return e[0] if lang == "uk" else e[1]
	var src: Dictionary = {"ok": BIT_OK, "err": BIT_ERR, "idle": BIT_IDLE, "combo": BIT_COMBO, "lowtime": BIT_LOWTIME}[kind]
	var arr: Array = src.get(lang, src["en"])
	return arr[rng.randi() % arr.size()]
