# Google Play: товари Deep Bounce

Згенеровано `tools/store/play_products.py` із рядків гри (`i18n/*.json`). Назва ≤ 55 символів, опис ≤ 200 — перевірено.
Ціна в таблиці — стартова в USD для Play Console; гравцеві гра завжди показує ціну, яку повертає Google Play (`ProductDetails.formatted_price`).

| Product ID | Тип у Play Console | Стартова ціна | Що дає |
|---|---|---|---|
| `db_no_ads` | One-time product (постійний): гра робить acknowledge, не consume; відновлюється | US$3.99 | Без реклами назавжди (відновлюється) |
| `db_ball_amber` | One-time product (постійний): гра робить acknowledge, не consume; відновлюється | US$0.99 | Бурштин |
| `db_ball_frost` | One-time product (постійний): гра робить acknowledge, не consume; відновлюється | US$1.99 | Морозна перлина |
| `db_ball_obsidian` | One-time product (постійний): гра робить acknowledge, не consume; відновлюється | US$1.99 | Обсидіанове ядро |
| `db_cannon_bronze` | One-time product (постійний): гра робить acknowledge, не consume; відновлюється | US$1.99 | Бронзовий майстер |
| `db_cannon_crystal` | One-time product (постійний): гра робить acknowledge, не consume; відновлюється | US$2.99 | Кристальний двигун |
| `db_cannon_obsidian` | One-time product (постійний): гра робить acknowledge, не consume; відновлюється | US$2.99 | Обсидіанова гармата |
| `db_support_small` | One-time product (витратний): гра робить consume після зарахування, тож його можна купувати знову | US$0.99 | Підтримка автора, нічого не відкриває |
| `db_support_medium` | One-time product (витратний): гра робить consume після зарахування, тож його можна купувати знову | US$2.99 | Підтримка автора, нічого не відкриває |
| `db_support_large` | One-time product (витратний): гра робить consume після зарахування, тож його можна купувати знову | US$4.99 | Підтримка автора, нічого не відкриває |
| `db_support_extra` | One-time product (витратний): гра робить consume після зарахування, тож його можна купувати знову | US$9.99 | Підтримка автора, нічого не відкриває |

## `db_no_ads`

| Мова Console | Назва | Опис |
|---|---|---|
| uk | Deep Bounce: Без реклами | Жодної реклами між забігами й рівнями. «Продовжити» біля червоної лінії та «Подвоїти кристали» без відео. |
| en-US | Deep Bounce: Ad-Free | No ads between runs and levels. Continue at the red line and Double Crystals without a video. |
| pl-PL | Deep Bounce: Bez reklam | Bez reklam między zejściami i poziomami. „Kontynuuj” przy czerwonej linii i „Podwój kryształy” bez filmu. |
| de-DE | Deep Bounce: Werbefrei | Keine Werbung zwischen Läufen und Levels. „Weiter“ an der roten Linie und „Kristalle verdoppeln“ ohne Video. |
| es-ES | Deep Bounce: Sin anuncios | Sin anuncios entre partidas y niveles. «Continuar» en la línea roja y «Duplicar cristales» sin vídeo. |
| fr-FR | Deep Bounce: Sans pub | Aucune pub entre les parties et les niveaux. « Continuer » à la ligne rouge et « Doubler les cristaux » sans vidéo. |
| it-IT | Deep Bounce: Niente pubblicità | Niente pubblicità tra partite e livelli. «Continua» alla linea rossa e «Raddoppia i cristalli» senza video. |
| pt-BR | Deep Bounce: Sem anúncios | Sem anúncios entre partidas e fases. "Continuar" na linha vermelha e "Dobrar cristais" sem vídeo. |
| tr-TR | Deep Bounce: Reklamsız | Oyunlar ve bölümler arasında reklam yok. Kırmızı çizgide "Devam et" ve "Kristalleri ikiye katla" videosuz. |
| ja-JP | Deep Bounce: 広告なし | ランやレベルの合間に広告なし。赤い線での「つづける」と「クリスタル 2 倍」が動画なしで使えます。 |
| ko-KR | Deep Bounce: 광고 제거 | 게임과 레벨 사이에 광고가 없습니다. 빨간 선의 "계속하기"와 "크리스털 2배"를 영상 없이 사용합니다. |
| zh-CN | Deep Bounce: 去广告 | 局与关卡之间不再有广告。红线处的“继续”和“双倍水晶”无需看视频。 |

## `db_ball_amber`

| Мова Console | Назва | Опис |
|---|---|---|
| uk | Бурштин | Напівпрозорий медовий бурштин, що світиться зсередини. (Кульки) |
| en-US | Amber | Translucent honey amber that glows from within. (Balls) |
| pl-PL | Bursztyn | Półprzezroczysty, miodowy bursztyn świecący od środka. (Kulki) |
| de-DE | Bernstein | Durchscheinender Honig-Bernstein, der von innen leuchtet. (Kugeln) |
| es-ES | Ámbar | Ámbar color miel, translúcido, que brilla desde dentro. (Bolas) |
| fr-FR | Ambre | Ambre miel translucide qui brille de l'intérieur. (Billes) |
| it-IT | Ambra | Ambra color miele, traslucida, che brilla dall'interno. (Palline) |
| pt-BR | Âmbar | Âmbar cor de mel, translúcido, que brilha por dentro. (Bolas) |
| tr-TR | Kehribar | İçten parlayan, yarı saydam bal rengi kehribar. (Toplar) |
| ja-JP | アンバー | 内側から光る、半透明のはちみつ色の琥珀。 (ボール) |
| ko-KR | 호박 | 안에서 빛나는 반투명 꿀빛 호박. (공) |
| zh-CN | 琥珀 | 半透明的蜂蜜色琥珀，由内而外发光。 (弹球) |

## `db_ball_frost`

| Мова Console | Назва | Опис |
|---|---|---|
| uk | Морозна перлина | Молочне крижане ядро з коротким світлим слідом. (Кульки) |
| en-US | Frost Pearl | A milky ice core with a short, light trail. (Balls) |
| pl-PL | Mroźna perła | Mleczny lodowy rdzeń z krótkim, jasnym śladem. (Kulki) |
| de-DE | Frostperle | Ein milchiger Eiskern mit kurzer, heller Spur. (Kugeln) |
| es-ES | Perla de escarcha | Un núcleo de hielo lechoso con una estela corta y clara. (Bolas) |
| fr-FR | Perle de givre | Un cœur de glace laiteux avec une traînée courte et claire. (Billes) |
| it-IT | Perla di brina | Un nucleo di ghiaccio lattiginoso con una scia breve e chiara. (Palline) |
| pt-BR | Pérola de gelo | Um núcleo de gelo leitoso com um rastro curto e claro. (Bolas) |
| tr-TR | Ayaz İncisi | Kısa ve açık renkli izi olan sütlü bir buz çekirdeği. (Toplar) |
| ja-JP | フロストパール | 乳白色の氷の芯と、短く明るい軌跡。 (ボール) |
| ko-KR | 서리 진주 | 우윳빛 얼음 심과 짧고 밝은 궤적. (공) |
| zh-CN | 霜之珍珠 | 乳白色的冰核，拖着短而明亮的尾迹。 (弹球) |

## `db_ball_obsidian`

| Мова Console | Назва | Опис |
|---|---|---|
| uk | Обсидіанове ядро | Темне ядро, світлий обідок і бірюзові тріщини. (Кульки) |
| en-US | Obsidian Core | A dark core, a light rim and turquoise cracks. (Balls) |
| pl-PL | Obsydianowy rdzeń | Ciemny rdzeń, jasny brzeg i turkusowe pęknięcia. (Kulki) |
| de-DE | Obsidiankern | Dunkler Kern, heller Rand und türkise Risse. (Kugeln) |
| es-ES | Núcleo de obsidiana | Núcleo oscuro, borde claro y grietas turquesa. (Bolas) |
| fr-FR | Cœur d'obsidienne | Un cœur sombre, un bord clair et des fissures turquoise. (Billes) |
| it-IT | Nucleo d'ossidiana | Nucleo scuro, bordo chiaro e crepe turchesi. (Palline) |
| pt-BR | Núcleo de obsidiana | Núcleo escuro, borda clara e rachaduras turquesa. (Bolas) |
| tr-TR | Obsidyen Çekirdek | Koyu çekirdek, açık kenar ve turkuaz çatlaklar. (Toplar) |
| ja-JP | オブシディアンコア | 暗い芯、明るい縁、ターコイズのひび。 (ボール) |
| ko-KR | 흑요석 코어 | 어두운 심, 밝은 테두리, 청록색 균열. (공) |
| zh-CN | 黑曜石之核 | 深色核心、明亮边缘和青绿色裂纹。 (弹球) |

## `db_cannon_bronze`

| Мова Console | Назва | Опис |
|---|---|---|
| uk | Бронзовий майстер | Теплі бронзові пластини з тонким гравіюванням. (Гармати) |
| en-US | Bronze Master | Warm bronze plates with fine engraving. (Cannons) |
| pl-PL | Mistrz brązu | Ciepłe płyty z brązu z delikatnym grawerem. (Działa) |
| de-DE | Bronzemeister | Warme Bronzeplatten mit feiner Gravur. (Kanonen) |
| es-ES | Maestro del bronce | Cálidas placas de bronce con grabado fino. (Cañones) |
| fr-FR | Maître du bronze | Plaques de bronze chaudes à la gravure fine. (Canons) |
| it-IT | Maestro del bronzo | Calde piastre di bronzo con incisioni sottili. (Cannoni) |
| pt-BR | Mestre do bronze | Placas de bronze quentes com gravação fina. (Canhões) |
| tr-TR | Bronz Usta | İnce oymalı sıcak bronz plakalar. (Silahlar) |
| ja-JP | ブロンズマスター | 細かな彫刻が入った温かいブロンズの板。 (大砲) |
| ko-KR | 청동 장인 | 섬세한 조각이 새겨진 따뜻한 청동판. (대포) |
| zh-CN | 青铜大师 | 刻有精细纹饰的温暖青铜板。 (火炮) |

## `db_cannon_crystal`

| Мова Console | Назва | Опис |
|---|---|---|
| uk | Кристальний двигун | Бірюзові кристалічні вставки в мідних кільцях. (Гармати) |
| en-US | Crystal Engine | Turquoise crystal inserts held in copper rings. (Cannons) |
| pl-PL | Kryształowy silnik | Turkusowe kryształowe wstawki w miedzianych pierścieniach. (Działa) |
| de-DE | Kristallmaschine | Türkise Kristalleinsätze in Kupferringen. (Kanonen) |
| es-ES | Motor de cristal | Incrustaciones de cristal turquesa en anillos de cobre. (Cañones) |
| fr-FR | Moteur de cristal | Inserts de cristal turquoise sertis dans des anneaux de cuivre. (Canons) |
| it-IT | Motore di cristallo | Inserti di cristallo turchese in anelli di rame. (Cannoni) |
| pt-BR | Motor de cristal | Inserções de cristal turquesa em anéis de cobre. (Canhões) |
| tr-TR | Kristal Motor | Bakır halkalara oturtulmuş turkuaz kristal parçalar. (Silahlar) |
| ja-JP | クリスタルエンジン | 銅のリングにはめたターコイズの結晶。 (大砲) |
| ko-KR | 크리스털 엔진 | 구리 고리에 박힌 청록 크리스털. (대포) |
| zh-CN | 水晶引擎 | 镶在铜环中的青绿水晶。 (火炮) |

## `db_cannon_obsidian`

| Мова Console | Назва | Опис |
|---|---|---|
| uk | Обсидіанова гармата | Чорний камінь, мідні з'єднання і бірюзове ядро. (Гармати) |
| en-US | Obsidian Cannon | Black stone, copper joints and a turquoise core. (Cannons) |
| pl-PL | Obsydianowe działo | Czarny kamień, miedziane złącza i turkusowy rdzeń. (Działa) |
| de-DE | Obsidiankanone | Schwarzer Stein, Kupfergelenke und ein türkiser Kern. (Kanonen) |
| es-ES | Cañón de obsidiana | Piedra negra, juntas de cobre y un núcleo turquesa. (Cañones) |
| fr-FR | Canon d'obsidienne | Pierre noire, jointures de cuivre et cœur turquoise. (Canons) |
| it-IT | Cannone d'ossidiana | Pietra nera, giunti di rame e un nucleo turchese. (Cannoni) |
| pt-BR | Canhão de obsidiana | Pedra negra, juntas de cobre e um núcleo turquesa. (Canhões) |
| tr-TR | Obsidyen Silah | Siyah taş, bakır eklemler ve turkuaz bir çekirdek. (Silahlar) |
| ja-JP | オブシディアンキャノン | 黒い石、銅の継ぎ目、ターコイズの芯。 (大砲) |
| ko-KR | 흑요석 대포 | 검은 돌, 구리 이음매, 청록빛 심. (대포) |
| zh-CN | 黑曜石火炮 | 黑色石材、铜质关节和青绿色核心。 (火炮) |

## `db_support_small`

| Мова Console | Назва | Опис |
|---|---|---|
| uk | Підтримка автора · Мала | Підтримка нічого не відкриває в грі. Вона просто допомагає авторові й далі вдосконалювати гру. |
| en-US | Support the Creator · Small | Support does not unlock anything in the game. It simply helps the creator keep improving it. |
| pl-PL | Wesprzyj twórcę · Małe | Wsparcie niczego nie odblokowuje w grze. Po prostu pomaga twórcy dalej ją ulepszać. |
| de-DE | Entwickler unterstützen · Klein | Die Unterstützung schaltet nichts im Spiel frei. Sie hilft einfach dabei, das Spiel weiter zu verbessern. |
| es-ES | Apoya al creador · Pequeño | El apoyo no desbloquea nada en el juego. Simplemente ayuda al creador a seguir mejorándolo. |
| fr-FR | Soutenir le créateur · Petit | Le soutien ne débloque rien dans le jeu. Il aide simplement le créateur à continuer de l'améliorer. |
| it-IT | Sostieni l'autore · Piccolo | Il sostegno non sblocca nulla nel gioco. Aiuta semplicemente l'autore a continuare a migliorarlo. |
| pt-BR | Apoie o criador · Pequeno | O apoio não desbloqueia nada no jogo. Ele só ajuda o criador a continuar melhorando o jogo. |
| tr-TR | Yapımcıyı Destekle · Küçük | Destek oyunda hiçbir şeyin kilidini açmaz. Yalnızca yapımcının oyunu geliştirmeye devam etmesine yardım eder. |
| ja-JP | 作者を応援 · 小 | 応援でゲーム内の何かが解放されることはありません。作者がゲームを改良し続ける助けになります。 |
| ko-KR | 제작자 후원 · 작게 | 후원으로 게임 안의 무언가가 열리지는 않습니다. 제작자가 게임을 계속 다듬는 데 도움이 될 뿐입니다. |
| zh-CN | 支持作者 · 小份 | 支持不会解锁游戏内任何内容，只是帮助作者继续改进游戏。 |

## `db_support_medium`

| Мова Console | Назва | Опис |
|---|---|---|
| uk | Підтримка автора · Середня | Підтримка нічого не відкриває в грі. Вона просто допомагає авторові й далі вдосконалювати гру. |
| en-US | Support the Creator · Medium | Support does not unlock anything in the game. It simply helps the creator keep improving it. |
| pl-PL | Wesprzyj twórcę · Średnie | Wsparcie niczego nie odblokowuje w grze. Po prostu pomaga twórcy dalej ją ulepszać. |
| de-DE | Entwickler unterstützen · Mittel | Die Unterstützung schaltet nichts im Spiel frei. Sie hilft einfach dabei, das Spiel weiter zu verbessern. |
| es-ES | Apoya al creador · Mediano | El apoyo no desbloquea nada en el juego. Simplemente ayuda al creador a seguir mejorándolo. |
| fr-FR | Soutenir le créateur · Moyen | Le soutien ne débloque rien dans le jeu. Il aide simplement le créateur à continuer de l'améliorer. |
| it-IT | Sostieni l'autore · Medio | Il sostegno non sblocca nulla nel gioco. Aiuta semplicemente l'autore a continuare a migliorarlo. |
| pt-BR | Apoie o criador · Médio | O apoio não desbloqueia nada no jogo. Ele só ajuda o criador a continuar melhorando o jogo. |
| tr-TR | Yapımcıyı Destekle · Orta | Destek oyunda hiçbir şeyin kilidini açmaz. Yalnızca yapımcının oyunu geliştirmeye devam etmesine yardım eder. |
| ja-JP | 作者を応援 · 中 | 応援でゲーム内の何かが解放されることはありません。作者がゲームを改良し続ける助けになります。 |
| ko-KR | 제작자 후원 · 보통 | 후원으로 게임 안의 무언가가 열리지는 않습니다. 제작자가 게임을 계속 다듬는 데 도움이 될 뿐입니다. |
| zh-CN | 支持作者 · 中份 | 支持不会解锁游戏内任何内容，只是帮助作者继续改进游戏。 |

## `db_support_large`

| Мова Console | Назва | Опис |
|---|---|---|
| uk | Підтримка автора · Велика | Підтримка нічого не відкриває в грі. Вона просто допомагає авторові й далі вдосконалювати гру. |
| en-US | Support the Creator · Large | Support does not unlock anything in the game. It simply helps the creator keep improving it. |
| pl-PL | Wesprzyj twórcę · Duże | Wsparcie niczego nie odblokowuje w grze. Po prostu pomaga twórcy dalej ją ulepszać. |
| de-DE | Entwickler unterstützen · Groß | Die Unterstützung schaltet nichts im Spiel frei. Sie hilft einfach dabei, das Spiel weiter zu verbessern. |
| es-ES | Apoya al creador · Grande | El apoyo no desbloquea nada en el juego. Simplemente ayuda al creador a seguir mejorándolo. |
| fr-FR | Soutenir le créateur · Grand | Le soutien ne débloque rien dans le jeu. Il aide simplement le créateur à continuer de l'améliorer. |
| it-IT | Sostieni l'autore · Grande | Il sostegno non sblocca nulla nel gioco. Aiuta semplicemente l'autore a continuare a migliorarlo. |
| pt-BR | Apoie o criador · Grande | O apoio não desbloqueia nada no jogo. Ele só ajuda o criador a continuar melhorando o jogo. |
| tr-TR | Yapımcıyı Destekle · Büyük | Destek oyunda hiçbir şeyin kilidini açmaz. Yalnızca yapımcının oyunu geliştirmeye devam etmesine yardım eder. |
| ja-JP | 作者を応援 · 大 | 応援でゲーム内の何かが解放されることはありません。作者がゲームを改良し続ける助けになります。 |
| ko-KR | 제작자 후원 · 크게 | 후원으로 게임 안의 무언가가 열리지는 않습니다. 제작자가 게임을 계속 다듬는 데 도움이 될 뿐입니다. |
| zh-CN | 支持作者 · 大份 | 支持不会解锁游戏内任何内容，只是帮助作者继续改进游戏。 |

## `db_support_extra`

| Мова Console | Назва | Опис |
|---|---|---|
| uk | Підтримка автора · Щедра | Підтримка нічого не відкриває в грі. Вона просто допомагає авторові й далі вдосконалювати гру. |
| en-US | Support the Creator · Extra | Support does not unlock anything in the game. It simply helps the creator keep improving it. |
| pl-PL | Wesprzyj twórcę · Hojne | Wsparcie niczego nie odblokowuje w grze. Po prostu pomaga twórcy dalej ją ulepszać. |
| de-DE | Entwickler unterstützen · Extra | Die Unterstützung schaltet nichts im Spiel frei. Sie hilft einfach dabei, das Spiel weiter zu verbessern. |
| es-ES | Apoya al creador · Extra | El apoyo no desbloquea nada en el juego. Simplemente ayuda al creador a seguir mejorándolo. |
| fr-FR | Soutenir le créateur · Généreux | Le soutien ne débloque rien dans le jeu. Il aide simplement le créateur à continuer de l'améliorer. |
| it-IT | Sostieni l'autore · Generoso | Il sostegno non sblocca nulla nel gioco. Aiuta semplicemente l'autore a continuare a migliorarlo. |
| pt-BR | Apoie o criador · Generoso | O apoio não desbloqueia nada no jogo. Ele só ajuda o criador a continuar melhorando o jogo. |
| tr-TR | Yapımcıyı Destekle · Cömert | Destek oyunda hiçbir şeyin kilidini açmaz. Yalnızca yapımcının oyunu geliştirmeye devam etmesine yardım eder. |
| ja-JP | 作者を応援 · 特大 | 応援でゲーム内の何かが解放されることはありません。作者がゲームを改良し続ける助けになります。 |
| ko-KR | 제작자 후원 · 아주 크게 | 후원으로 게임 안의 무언가가 열리지는 않습니다. 제작자가 게임을 계속 다듬는 데 도움이 될 뿐입니다. |
| zh-CN | 支持作者 · 超大份 | 支持不会解锁游戏内任何内容，只是帮助作者继续改进游戏。 |

