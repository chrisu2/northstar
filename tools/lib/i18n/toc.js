'use strict';
// The game's AddOns list shows each addon's `## Title` and `## Notes`, and in
// a client language the `## Title-<locale>` and `## Notes-<locale>` beside
// them. These are the translations of every Northstar addon's, written once
// here (AI translations, glossary: data/i18n/glossary; Northstar, Codex
// and the names of people and projects are kept as they are).
//
//   tocLines(addon) -> ['## Title-deDE: ...', '## Notes-deDE: ...', ...]
//     for every locale (LOCALE_CODES order). addon: the folder name;
//     the language folders Northstar_<locale> name their own language.
//   languageAddon(locale) -> 'Northstar_<locale>': our guides' texts
//     (Texts.lua) and the game's names (Names.lua) in that language, one
//     load-on-demand folder (rust/crates/forge-guide/src/toc.rs is the twin)
//   languageToc(locale, iface, version) -> its TOC, written alike by
//     `forge guide compile` and `forge data names`
//   retiredLanguageAddons(locale) -> the two folders it replaced (0.3.0)
// The TOCs in the repository carry these lines as they are; the generated
// ones (Codex, QuestDB, ItemDB, Guides, the language folders) get them from their
// builders. tests/i18n-toc.test.js checks every TOC under addon/.

const { LOCALES, LOCALE_CODES } = require('./locales');
const { GENERATED_MARKER } = require('../pack/format');

const TEXT = {
	Northstar: {
		title: { deDE: 'Northstar', esES: 'Northstar', esMX: 'Northstar', frFR: 'Northstar', koKR: 'Northstar', ptBR: 'Northstar', ruRU: 'Northstar', zhCN: 'Northstar', zhTW: 'Northstar' },
		notes: {
			deDE: 'Leveling-Guides für World of Warcraft: Forever.',
			esES: 'Guías para subir de nivel en World of Warcraft: Forever.',
			esMX: 'Guías para subir de nivel en World of Warcraft: Forever.',
			frFR: 'Guides de montée en niveau pour World of Warcraft: Forever.',
			koKR: 'World of Warcraft: Forever 레벨업 가이드.',
			ptBR: 'Guias de evolução para World of Warcraft: Forever.',
			ruRU: 'Гайды по прокачке для World of Warcraft: Forever.',
			zhCN: '魔兽世界：Forever 练级指南。',
			zhTW: 'World of Warcraft: Forever 的升級指南。',
		},
	},
	Northstar_Codex: {
		title: { deDE: 'Northstar Codex', esES: 'Northstar Codex', esMX: 'Northstar Codex', frFR: 'Northstar Codex', koKR: 'Northstar Codex', ptBR: 'Northstar Codex', ruRU: 'Northstar Codex', zhCN: 'Northstar Codex', zhTW: 'Northstar Codex' },
		notes: {
			deDE: 'Teil von Northstar: Gegenstände, Reittiere, Haustiere, NPCs, Quests und wo man sie bekommt, Dungeons und Rares, für Nachschlagen, Dungeons und Rares. Wird bei Bedarf geladen.',
			esES: 'Parte de Northstar: objetos, monturas, mascotas, PNJ, misiones y dónde conseguirlos, mazmorras y raros, para Buscador, Mazmorras y Raros. Se carga bajo demanda.',
			esMX: 'Parte de Northstar: objetos, monturas, mascotas, PNJ, misiones y dónde conseguirlos, calabozos y raros, para Buscador, Calabozos y Raros. Se carga bajo demanda.',
			frFR: 'Fait partie de Northstar : objets, montures, mascottes, PNJ, quêtes et où les obtenir, donjons et rares, pour Recherche, Donjons et Rares. Chargé à la demande.',
			koKR: 'Northstar의 일부: 아이템, 탈것, 애완동물, NPC, 퀘스트와 얻는 곳, 던전과 희귀 몬스터. 찾아보기, 던전, 희귀에서 씁니다. 필요할 때 불러옵니다.',
			ptBR: 'Parte do Northstar: itens, montarias, mascotes, PNJs, missões e onde obtê-los, masmorras e raros, para Consulta, Masmorras e Raros. Carregado sob demanda.',
			ruRU: 'Часть Northstar: предметы, транспорт, питомцы, NPC, задания и где их получить, подземелья и редкие существа для разделов «Поиск», «Подземелья» и «Редкие». Загружается по требованию.',
			zhCN: 'Northstar 的组成部分：物品、坐骑、宠物、NPC、任务及其获取途径、地下城和稀有怪物，供查询、地下城和稀有页面使用。按需加载。',
			zhTW: 'Northstar 的一部分：物品、坐騎、寵物、NPC、任務及其取得方式、地城與稀有怪物，供查詢、地城與稀有頁面使用。按需載入。',
		},
	},
	Northstar_Guides: {
		title: { deDE: 'Northstar Guides', esES: 'Northstar: guías', esMX: 'Northstar: guías', frFR: 'Northstar : guides', koKR: 'Northstar 가이드', ptBR: 'Northstar: guias', ruRU: 'Northstar: гайды', zhCN: 'Northstar 指南', zhTW: 'Northstar 指南' },
		notes: {
			deDE: 'Leveling-, Berufs-, Ruf- und Sammel-Guides für Northstar.',
			esES: 'Guías de subida de nivel, profesiones, reputación y coleccionables para Northstar.',
			esMX: 'Guías de subida de nivel, profesiones, reputación y coleccionables para Northstar.',
			frFR: 'Guides de montée en niveau, de métiers, de réputation et de collection pour Northstar.',
			koKR: 'Northstar용 레벨업, 전문 기술, 평판, 수집품 가이드.',
			ptBR: 'Guias de evolução, profissões, reputação e colecionáveis para o Northstar.',
			ruRU: 'Гайды по прокачке, профессиям, репутации и коллекциям для Northstar.',
			zhCN: 'Northstar 的练级、专业、声望和收藏指南。',
			zhTW: 'Northstar 的升級、專業、聲望與收藏指南。',
		},
	},
	Northstar_Guides_Alliance: {
		title: { deDE: 'Northstar Guides (Allianz)', esES: 'Northstar: guías (Alianza)', esMX: 'Northstar: guías (Alianza)', frFR: 'Northstar : guides (Alliance)', koKR: 'Northstar 가이드 (얼라이언스)', ptBR: 'Northstar: guias (Aliança)', ruRU: 'Northstar: гайды (Альянс)', zhCN: 'Northstar 指南（联盟）', zhTW: 'Northstar 指南（聯盟）' },
		notes: {
			deDE: 'Guides von Northstar für Charaktere der Allianz. Wird bei Bedarf geladen.',
			esES: 'Guías de Northstar para personajes de la Alianza. Se carga bajo demanda.',
			esMX: 'Guías de Northstar para personajes de la Alianza. Se carga bajo demanda.',
			frFR: 'Guides de Northstar pour les personnages de l\'Alliance. Chargé à la demande.',
			koKR: '얼라이언스 캐릭터를 위한 Northstar 가이드. 필요할 때 불러옵니다.',
			ptBR: 'Guias do Northstar para personagens da Aliança. Carregado sob demanda.',
			ruRU: 'Гайды Northstar для персонажей Альянса. Загружается по требованию.',
			zhCN: 'Northstar 的联盟角色指南。按需加载。',
			zhTW: 'Northstar 的聯盟角色指南。按需載入。',
		},
	},
	Northstar_Guides_Horde: {
		title: { deDE: 'Northstar Guides (Horde)', esES: 'Northstar: guías (Horda)', esMX: 'Northstar: guías (Horda)', frFR: 'Northstar : guides (Horde)', koKR: 'Northstar 가이드 (호드)', ptBR: 'Northstar: guias (Horda)', ruRU: 'Northstar: гайды (Орда)', zhCN: 'Northstar 指南（部落）', zhTW: 'Northstar 指南（部落）' },
		notes: {
			deDE: 'Guides von Northstar für Charaktere der Horde. Wird bei Bedarf geladen.',
			esES: 'Guías de Northstar para personajes de la Horda. Se carga bajo demanda.',
			esMX: 'Guías de Northstar para personajes de la Horda. Se carga bajo demanda.',
			frFR: 'Guides de Northstar pour les personnages de la Horde. Chargé à la demande.',
			koKR: '호드 캐릭터를 위한 Northstar 가이드. 필요할 때 불러옵니다.',
			ptBR: 'Guias do Northstar para personagens da Horda. Carregado sob demanda.',
			ruRU: 'Гайды Northstar для персонажей Орды. Загружается по требованию.',
			zhCN: 'Northstar 的部落角色指南。按需加载。',
			zhTW: 'Northstar 的部落角色指南。按需載入。',
		},
	},
	Northstar_ItemDB: {
		title: { deDE: 'Northstar Gegenstandsdaten', esES: 'Northstar: datos de objetos', esMX: 'Northstar: datos de objetos', frFR: 'Northstar : données d\'objets', koKR: 'Northstar 아이템 데이터', ptBR: 'Northstar: dados de itens', ruRU: 'Northstar: данные предметов', zhCN: 'Northstar 物品数据', zhTW: 'Northstar 物品資料' },
		notes: {
			deDE: 'Gegenstandswerte für Northstars Ausrüstungsratschläge. Wird bei Bedarf geladen.',
			esES: 'Estadísticas de objetos para los consejos de equipo de Northstar. Se carga bajo demanda.',
			esMX: 'Estadísticas de objetos para los consejos de equipo de Northstar. Se carga bajo demanda.',
			frFR: 'Caractéristiques des objets pour les conseils d\'équipement de Northstar. Chargé à la demande.',
			koKR: 'Northstar 장비 조언에 쓰는 아이템 능력치. 필요할 때 불러옵니다.',
			ptBR: 'Atributos de itens para as dicas de equipamento do Northstar. Carregado sob demanda.',
			ruRU: 'Характеристики предметов для советов Northstar по снаряжению. Загружается по требованию.',
			zhCN: 'Northstar 装备建议所用的物品属性。按需加载。',
			zhTW: 'Northstar 裝備建議所用的物品屬性。按需載入。',
		},
	},
	Northstar_Nav: {
		title: { deDE: 'Northstar Navigation', esES: 'Northstar: navegación', esMX: 'Northstar: navegación', frFR: 'Northstar : navigation', koKR: 'Northstar 길찾기', ptBR: 'Northstar: navegação', ruRU: 'Northstar: навигация', zhCN: 'Northstar 导航', zhTW: 'Northstar 導航' },
		notes: {
			deDE: 'Teil von Northstar: Laufwege für den Pfeil, mit Northstars eigener Wegfindung, entstanden aus der Wegfindung von Shortest Path Forever (Cillian Berragan, github.com/cjber/shortest-path-forever, mit seiner Erlaubnis verwendet). Wird bei Bedarf geladen.',
			esES: 'Parte de Northstar: rutas a pie para la flecha, con el cálculo de rutas propio de Northstar, que partió del de Shortest Path Forever (Cillian Berragan, github.com/cjber/shortest-path-forever, usado con su permiso). Se carga bajo demanda.',
			esMX: 'Parte de Northstar: rutas a pie para la flecha, con el cálculo de rutas propio de Northstar, que partió del de Shortest Path Forever (Cillian Berragan, github.com/cjber/shortest-path-forever, usado con su permiso). Se carga bajo demanda.',
			frFR: 'Fait partie de Northstar : itinéraires à pied pour la flèche, calculés par le routeur de Northstar, issu de celui de Shortest Path Forever (Cillian Berragan, github.com/cjber/shortest-path-forever, utilisé avec sa permission). Chargé à la demande.',
			koKR: 'Northstar의 일부: 화살표용 도보 경로. Shortest Path Forever의 길찾기(Cillian Berragan, github.com/cjber/shortest-path-forever, 허락을 받아 사용)에서 출발한 Northstar 자체 길찾기를 씁니다. 필요할 때 불러옵니다.',
			ptBR: 'Parte do Northstar: rotas a pé para a seta, com o cálculo de rotas próprio do Northstar, que partiu do Shortest Path Forever (Cillian Berragan, github.com/cjber/shortest-path-forever, usado com permissão dele). Carregado sob demanda.',
			ruRU: 'Часть Northstar: пешие маршруты для стрелки, построенные собственным алгоритмом Northstar, выросшим из алгоритма Shortest Path Forever (Cillian Berragan, github.com/cjber/shortest-path-forever, используется с его разрешения). Загружается по требованию.',
			zhCN: 'Northstar 的组成部分：为箭头提供步行路线，采用 Northstar 自己的寻路，源自 Shortest Path Forever 的寻路（Cillian Berragan，github.com/cjber/shortest-path-forever，经其许可使用）。按需加载。',
			zhTW: 'Northstar 的一部分：為箭頭提供步行路線，採用 Northstar 自己的尋路，源自 Shortest Path Forever 的尋路（Cillian Berragan，github.com/cjber/shortest-path-forever，經其許可使用）。按需載入。',
		},
	},
	Northstar_QuestDB: {
		title: { deDE: 'Northstar Quest-Datenbank', esES: 'Northstar: base de datos de misiones', esMX: 'Northstar: base de datos de misiones', frFR: 'Northstar : base de données des quêtes', koKR: 'Northstar 퀘스트 데이터베이스', ptBR: 'Northstar: banco de dados de missões', ruRU: 'Northstar: база заданий', zhCN: 'Northstar 任务数据库', zhTW: 'Northstar 任務資料庫' },
		notes: {
			deDE: 'Quest-, NPC-, Objekt- und Gegenstandsdaten für Northstars Questmarkierungen und Tooltips. Wird bei Bedarf geladen.',
			esES: 'Datos de misiones, PNJ y objetos para los marcadores de misión y las descripciones emergentes de Northstar. Se carga bajo demanda.',
			esMX: 'Datos de misiones, PNJ y objetos para los marcadores de misión y las descripciones emergentes de Northstar. Se carga bajo demanda.',
			frFR: 'Données des quêtes, PNJ et objets pour les marqueurs de quête et les infobulles de Northstar. Chargé à la demande.',
			koKR: 'Northstar 퀘스트 표시와 툴팁에 쓰는 퀘스트, NPC, 물체, 아이템 데이터. 필요할 때 불러옵니다.',
			ptBR: 'Dados de missões, PNJs, objetos e itens para os marcadores de missão e as dicas do Northstar. Carregado sob demanda.',
			ruRU: 'Данные заданий, NPC, объектов и предметов для меток заданий и подсказок Northstar. Загружается по требованию.',
			zhCN: 'Northstar 任务标记和鼠标提示所用的任务、NPC、物体和物品数据。按需加载。',
			zhTW: 'Northstar 任務標記與滑鼠提示所用的任務、NPC、物件與物品資料。按需載入。',
		},
	},
	Northstar_Recorder: {
		title: { deDE: 'Northstar Recorder', esES: 'Northstar Recorder', esMX: 'Northstar Recorder', frFR: 'Northstar : enregistreur', koKR: 'Northstar 기록기', ptBR: 'Northstar: gravador', ruRU: 'Northstar: запись', zhCN: 'Northstar 记录器', zhTW: 'Northstar 記錄器' },
		notes: {
			deDE: 'Zeichnet beim Spielen Quests, Wege und Weltdaten auf, um Northstar-Guides zu schreiben. /nsrec',
			esES: 'Graba misiones, rutas y datos del mundo mientras juegas, para crear guías de Northstar. /nsrec',
			esMX: 'Graba misiones, rutas y datos del mundo mientras juegas, para crear guías de Northstar. /nsrec',
			frFR: 'Enregistre les quêtes, les trajets et les données du monde pendant que vous jouez, pour écrire des guides Northstar. /nsrec',
			koKR: '플레이하는 동안 퀘스트, 경로, 월드 데이터를 기록해 Northstar 가이드 작성에 씁니다. /nsrec',
			ptBR: 'Grava missões, rotas e dados do mundo enquanto você joga, para criar guias do Northstar. /nsrec',
			ruRU: 'Записывает задания, маршруты и данные мира во время игры, для создания гайдов Northstar. /nsrec',
			zhCN: '在游戏时记录任务、路线和世界数据，用于编写 Northstar 指南。/nsrec',
			zhTW: '在遊戲時記錄任務、路線與世界資料，用於撰寫 Northstar 指南。/nsrec',
		},
	},
};

// The per-language folders: { title, notes } templates, %1 the locale code,
// %2 the folder's language in this language.
const LANGUAGE_PREFIX = 'Northstar_';
const PER_LANGUAGE = {
	[LANGUAGE_PREFIX]: {
		deDE: ['Northstar - %2', 'Guide-Texte und Spielnamen für Northstar (Quests, NPCs, Objekte, Gegenstände, Instanzen und mehr). Sprache: %2. Wird bei Bedarf geladen, nur in einem Client dieser Sprache.'],
		esES: ['Northstar - %2', 'Textos de las guías y nombres del juego para Northstar (misiones, PNJ, objetos, instancias y más). Idioma: %2. Se carga bajo demanda solo en un cliente en ese idioma.'],
		esMX: ['Northstar - %2', 'Textos de las guías y nombres del juego para Northstar (misiones, PNJ, objetos, instancias y más). Idioma: %2. Se carga bajo demanda solo en un cliente en ese idioma.'],
		frFR: ['Northstar - %2', 'Textes des guides et noms du jeu pour Northstar (quêtes, PNJ, objets, instances et plus). Langue : %2. Chargé à la demande, uniquement sur un client dans cette langue.'],
		koKR: ['Northstar - %2', 'Northstar 가이드 텍스트와 게임 이름(퀘스트, NPC, 물체, 아이템, 인스턴스 등). 언어: %2. 해당 언어 클라이언트에서만 필요할 때 불러옵니다.'],
		ptBR: ['Northstar - %2', 'Textos dos guias e nomes do jogo para o Northstar (missões, PNJs, objetos, itens, instâncias e mais). Idioma: %2. Carregado sob demanda, só em um cliente nesse idioma.'],
		ruRU: ['Northstar - %2', 'Тексты гайдов и названия из игры для Northstar (задания, NPC, объекты, предметы, подземелья и другое). Язык: %2. Загружается по требованию, только в клиенте на этом языке.'],
		zhCN: ['Northstar - %2', 'Northstar 的指南文本和游戏名称（任务、NPC、物体、物品、副本等）。语言：%2。仅在该语言的客户端中按需加载。'],
		zhTW: ['Northstar - %2', 'Northstar 的指南文字與遊戲名稱（任務、NPC、物件、物品、副本等）。語言：%2。僅在該語言的用戶端中按需載入。'],
	},
};

// Each language's name in each language, as it reads after "Language:".
const LANGUAGE_NAMES = {
	deDE: { deDE: 'Deutsch', esES: 'Spanisch (Spanien)', esMX: 'Spanisch (Lateinamerika)', frFR: 'Französisch', koKR: 'Koreanisch', ptBR: 'Portugiesisch (Brasilien)', ruRU: 'Russisch', zhCN: 'Chinesisch (vereinfacht)', zhTW: 'Chinesisch (traditionell)' },
	esES: { deDE: 'alemán', esES: 'español (España)', esMX: 'español (Latinoamérica)', frFR: 'francés', koKR: 'coreano', ptBR: 'portugués (Brasil)', ruRU: 'ruso', zhCN: 'chino (simplificado)', zhTW: 'chino (tradicional)' },
	esMX: { deDE: 'alemán', esES: 'español (España)', esMX: 'español (Latinoamérica)', frFR: 'francés', koKR: 'coreano', ptBR: 'portugués (Brasil)', ruRU: 'ruso', zhCN: 'chino (simplificado)', zhTW: 'chino (tradicional)' },
	frFR: { deDE: 'allemand', esES: 'espagnol (Espagne)', esMX: 'espagnol (Amérique latine)', frFR: 'français', koKR: 'coréen', ptBR: 'portugais (Brésil)', ruRU: 'russe', zhCN: 'chinois (simplifié)', zhTW: 'chinois (traditionnel)' },
	koKR: { deDE: '독일어', esES: '스페인어(스페인)', esMX: '스페인어(중남미)', frFR: '프랑스어', koKR: '한국어', ptBR: '포르투갈어(브라질)', ruRU: '러시아어', zhCN: '중국어(간체)', zhTW: '중국어(번체)' },
	ptBR: { deDE: 'alemão', esES: 'espanhol (Espanha)', esMX: 'espanhol (América Latina)', frFR: 'francês', koKR: 'coreano', ptBR: 'português (Brasil)', ruRU: 'russo', zhCN: 'chinês (simplificado)', zhTW: 'chinês (tradicional)' },
	ruRU: { deDE: 'немецкий', esES: 'испанский (Испания)', esMX: 'испанский (Латинская Америка)', frFR: 'французский', koKR: 'корейский', ptBR: 'португальский (Бразилия)', ruRU: 'русский', zhCN: 'китайский (упрощенный)', zhTW: 'китайский (традиционный)' },
	zhCN: { deDE: '德语', esES: '西班牙语（西班牙）', esMX: '西班牙语（拉丁美洲）', frFR: '法语', koKR: '韩语', ptBR: '葡萄牙语（巴西）', ruRU: '俄语', zhCN: '简体中文', zhTW: '繁体中文' },
	zhTW: { deDE: '德語', esES: '西班牙語（西班牙）', esMX: '西班牙語（拉丁美洲）', frFR: '法語', koKR: '韓語', ptBR: '葡萄牙語（巴西）', ruRU: '俄語', zhCN: '簡體中文', zhTW: '繁體中文' },
};

// Our pack's race parts (Northstar_Guides_<race file>: a race's class chains
// and the baked legs of the guides it may follow): { title, notes } templates,
// %2 the race in this language (the addon's own Locales/ names).
const RACE_PART_PREFIX = 'Northstar_Guides_';
const PER_RACE = {
	deDE: ['Northstar Guides (%2)', 'Leveling-Guides von Northstar und ihre Laufwege für Charaktere der Rasse %2. Wird bei Bedarf geladen.'],
	esES: ['Northstar: guías (%2)', 'Guías de subida de nivel de Northstar y sus rutas a pie para personajes de la raza %2. Se carga bajo demanda.'],
	esMX: ['Northstar: guías (%2)', 'Guías de subida de nivel de Northstar y sus rutas a pie para personajes de la raza %2. Se carga bajo demanda.'],
	frFR: ['Northstar : guides (%2)', 'Guides de montée en niveau de Northstar et leurs trajets à pied pour les personnages de la race %2. Chargé à la demande.'],
	koKR: ['Northstar 가이드 (%2)', '%2 캐릭터를 위한 Northstar 레벨업 가이드와 도보 경로. 필요할 때 불러옵니다.'],
	ptBR: ['Northstar: guias (%2)', 'Guias de evolução do Northstar e suas rotas a pé para personagens da raça %2. Carregado sob demanda.'],
	ruRU: ['Northstar: гайды (%2)', 'Гайды Northstar по прокачке и их пешие маршруты для персонажей расы «%2». Загружается по требованию.'],
	zhCN: ['Northstar 指南（%2）', 'Northstar 为%2角色提供的练级指南及其步行路线。按需加载。'],
	zhTW: ['Northstar 指南（%2）', 'Northstar 為%2角色提供的升級指南及其步行路線。按需載入。'],
};
// Each race (by race file) in each language, as addon/Northstar/Locales/ has it.
const RACE_NAMES = {
	deDE: { Human: 'Mensch', Orc: 'Orc', Dwarf: 'Zwerg', NightElf: 'Nachtelf', Scourge: 'Untoter', Tauren: 'Tauren', Gnome: 'Gnom', Troll: 'Troll', Skyborne: 'Himmelsgeborene' },
	esES: { Human: 'Humano', Orc: 'Orco', Dwarf: 'Enano', NightElf: 'Elfo de la noche', Scourge: 'No-muerto', Tauren: 'Tauren', Gnome: 'Gnomo', Troll: 'Trol', Skyborne: 'Cielonato' },
	esMX: { Human: 'Humano', Orc: 'Orco', Dwarf: 'Enano', NightElf: 'Elfo de la noche', Scourge: 'No-muerto', Tauren: 'Tauren', Gnome: 'Gnomo', Troll: 'Trol', Skyborne: 'Cielonato' },
	frFR: { Human: 'Humain', Orc: 'Orc', Dwarf: 'Nain', NightElf: 'Elfe de la nuit', Scourge: 'Mort-vivant', Tauren: 'Tauren', Gnome: 'Gnome', Troll: 'Troll', Skyborne: 'Éolide' },
	koKR: { Human: '인간', Orc: '오크', Dwarf: '드워프', NightElf: '나이트 엘프', Scourge: '언데드', Tauren: '타우렌', Gnome: '노움', Troll: '트롤', Skyborne: '스카이본' },
	ptBR: { Human: 'Humano', Orc: 'Orc', Dwarf: 'Anão', NightElf: 'Elfo Noturno', Scourge: 'Morto-vivo', Tauren: 'Tauren', Gnome: 'Gnomo', Troll: 'Troll', Skyborne: 'Celonato' },
	ruRU: { Human: 'Человек', Orc: 'Орк', Dwarf: 'Дворф', NightElf: 'Ночной эльф', Scourge: 'Нежить', Tauren: 'Таурен', Gnome: 'Гном', Troll: 'Тролль', Skyborne: 'Небеснорожденный' },
	zhCN: { Human: '人类', Orc: '兽人', Dwarf: '矮人', NightElf: '暗夜精灵', Scourge: '亡灵', Tauren: '牛头人', Gnome: '侏儒', Troll: '巨魔', Skyborne: '天裔' },
	zhTW: { Human: '人類', Orc: '獸人', Dwarf: '矮人', NightElf: '夜精靈', Scourge: '不死族', Tauren: '牛頭人', Gnome: '地精', Troll: '食人妖', Skyborne: '天裔精靈' },
};

// addon -> { [locale]: { title, notes } }
function tocText(addon) {
	const fixed = TEXT[addon];
	if (fixed) return Object.fromEntries(LOCALE_CODES.map((l) => [l, { title: fixed.title[l], notes: fixed.notes[l] }]));
	const race = addon.startsWith(RACE_PART_PREFIX) ? addon.slice(RACE_PART_PREFIX.length) : null;
	if (race && RACE_NAMES.deDE[race]) {
		const fill = (s, l) => s.replace('%2', RACE_NAMES[l][race]);
		return Object.fromEntries(LOCALE_CODES.map((l) => [l, { title: fill(PER_RACE[l][0], l), notes: fill(PER_RACE[l][1], l) }]));
	}
	for (const [prefix, templates] of Object.entries(PER_LANGUAGE)) {
		if (!addon.startsWith(prefix)) continue;
		const pack = addon.slice(prefix.length);
		if (!LOCALE_CODES.includes(pack)) break;
		const fill = (s, l) => s.replace('%1', pack).replace('%2', LANGUAGE_NAMES[l][pack]);
		return Object.fromEntries(LOCALE_CODES.map((l) => [l, { title: fill(templates[l][0], l), notes: fill(templates[l][1], l) }]));
	}
	throw new Error(`no AddOns-list translations for ${addon} (tools/lib/i18n/toc.js)`);
}

function tocLines(addon) {
	const text = tocText(addon);
	const out = [];
	for (const l of LOCALE_CODES) out.push(`## Title-${l}: ${text[l].title}`, `## Notes-${l}: ${text[l].notes}`);
	return out;
}

const languageAddon = (locale) => `${LANGUAGE_PREFIX}${locale}`;
const retiredLanguageAddons = (locale) => [`Northstar_Guides_${locale}`, `Northstar_Names_${locale}`];
// The language folder's files, in load order: every writer of the folder lists both.
const LANGUAGE_FILES = ['Names.lua', 'Texts.lua'];

function languageToc(locale, iface, version) {
	const language = LOCALES[locale].language;
	return `${[
		`## Interface: ${iface}`,
		`## Title: Northstar - ${language}`,
		`## Notes: Guide texts and the game's names (quests, NPCs, objects, items, instances and more) in ${language} for Northstar. Loaded on demand on a ${language} client.`,
		...tocLines(languageAddon(locale)),
		'## Author: Northstar',
		`## Version: ${version}`,
		'## Category: Northstar',
		'## Group: Northstar',
		'## LoadOnDemand: 1',
		'## Dependencies: Northstar',
		'## X-Northstar-Texts: guides',
		`## X-Northstar-Locale: ${locale}`,
		'## X-License: GPL-3.0-only',
		`# ${GENERATED_MARKER} (Texts.lua) and \`forge data names\` (Names.lua). Do not edit: rebuild with those commands.`,
		'',
		...LANGUAGE_FILES,
	].join('\n')}\n`;
}

module.exports = { tocText, tocLines, languageAddon, languageToc, retiredLanguageAddons, LANGUAGE_PREFIX, LANGUAGE_FILES, TOC_ADDONS: Object.keys(TEXT) };
