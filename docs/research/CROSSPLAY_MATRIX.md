# Матрица перекрёстной проверки с оригиналом

Ведётся циклом [CROSSPLAY_LOOP](../CROSSPLAY_LOOP.md).

Статусы:

- **✓** — совпало в обеих программах (со ссылкой на evidence);
- **≠** — расхождение (со ссылкой на разбор);
- **…** — в работе;
- **—** — не проверено;
- **н/п** — непроверяемо (с причиной).

Сравнение: строки Summary, время, итоги команд. Где помечено «память», —
значения прочитаны из памяти обеих программ, а не со снимков.

## 0. Инструменты (приоритет 1)

| Задача | Статус |
| --- | --- |
| Summary из памяти: оригинал через `winedbg`, Mac через дамп | ✓ `summary_original.py`, `--summary-json`, `compare_summaries.py` (2026-10-03) |
| Пакетный прогон списка записей в оригинале через Cua | ✓ `play_original.py` (без человека, один экземпляр под блокировкой, проверка старта повтора), `random_vs.py` (один повтор при сбое инструмента; фон — J на строке Background) |
| Матчи «компьютер против компьютера» в оригинале с записью (оригинал → Mac) | ✓ `record_original.py`: VS с 1–7 компьютерами, 5 из 5 совпали ([оригинал → Mac 1](../evidence/crossplay-original-to-mac-1.json)) |
| Потиковое сравнение на выбранных тиках | ✓ `trace_ticks.py` (точка останова 421cdc в оригинале), `--network-trace` в приложении, `compare_traces.py`; первое применение — Demo |

## 1. Уже сверено (2026-10-02, [карточка](CROSSOVER_REPLAY_CROSSPLAY.md), [checksum](APPLICATION_CATALOG_CHECKSUM.md))

| Запись | Откуда | Режим | Статус |
| --- | --- | --- | --- |
| 20260101_010000_VS | Mac | VS, 3 игрока | ✓ |
| 20260101_010000_Battle | Mac | War | ✓ |
| 20260101_010000_Stage_1 | Mac | Stage 1-1 | ✓ |
| 20260101_010000_1on1_Prelminar | Mac | 1 on 1 | ✓ |
| 20260101_010000_2on2_SemiFinal | Mac | 2 on 2 | ✓ |
| 20260927_093914_VS | оригинал | VS | ✓ |
| 20260331_115445_Stage_1 | оригинал (дистрибутив) | Stage 1-1 | ✓ |
| 20260331_115533_Stage_1 | оригинал (дистрибутив) | Stage 1-1 | ✓ |
| 20260331_115752_Battle | оригинал (дистрибутив) | War, 8 игроков | ✓ (итоги команд — накопление сессии) |
| 20260331_012329_VS | оригинал (дистрибутив) | VS | ✓ (e2e playback) |
| свежая Mac VS после исправления суммы | Mac | VS | ✓ без правки байтов |

## 2. Персонажи (приоритет 2)

Каждый из 25 играбельных хотя бы в одном сверенном матче, как игрок или как
компьютер. Все 25 покрыты; дополнительно сверен id 51 (выпал в Random, [random VS 2](../evidence/crossplay-random-vs-2.json)):

Sakura(1), Naruto(2), Kakashi(3), Sai(4), Shino(5), Sasori(6), Rock_Lee(7),
Chiyo(8), Itachi(9), Deidara(10), Sasuke(11), Kiba(12), Yamato(13), Kankuro(14),
Temari(15), Gaara(16), Kisame(17), Neji(18), Ten_Ten(19), Orochimaru(20),
Jiraiya(21), Shikamaru(22), Kabuto(23), Hidan(24), Kakuzu(25).

| Персонаж | Статус |
| --- | --- |
| Sakura | ✓ [random VS 1](../evidence/crossplay-random-vs-1.json) |
| Naruto | ✓ [random VS 2](../evidence/crossplay-random-vs-2.json) |
| Kakashi | ✓ [random VS 2](../evidence/crossplay-random-vs-2.json) |
| Sai | ✓ [random VS 2](../evidence/crossplay-random-vs-2.json) |
| Shino | ✓ [random VS 1](../evidence/crossplay-random-vs-1.json) |
| Sasori | ✓ [random VS 1](../evidence/crossplay-random-vs-1.json) |
| Rock_Lee | ✓ [random VS 1](../evidence/crossplay-random-vs-1.json) |
| Chiyo | ✓ [random VS 2](../evidence/crossplay-random-vs-2.json) |
| Itachi | ✓ [random VS 2](../evidence/crossplay-random-vs-2.json) |
| Deidara | ✓ [random VS 1](../evidence/crossplay-random-vs-1.json) |
| Sasuke | ✓ [random VS 2](../evidence/crossplay-random-vs-2.json) |
| Kiba | ✓ [random VS 1](../evidence/crossplay-random-vs-1.json) |
| Yamato | ✓ [random VS 1](../evidence/crossplay-random-vs-1.json) |
| Kankuro | ✓ [random VS 2](../evidence/crossplay-random-vs-2.json) |
| Temari | ✓ [random VS 1](../evidence/crossplay-random-vs-1.json) |
| Gaara | ✓ [random VS 1](../evidence/crossplay-random-vs-1.json) |
| Kisame | ✓ [random VS 2](../evidence/crossplay-random-vs-2.json) |
| Neji | ✓ [random VS 1](../evidence/crossplay-random-vs-1.json) |
| Ten_Ten | ✓ [random VS 1](../evidence/crossplay-random-vs-1.json) |
| Orochimaru | ✓ [random VS 1](../evidence/crossplay-random-vs-1.json) |
| Jiraiya | ✓ [random VS 1](../evidence/crossplay-random-vs-1.json) |
| Shikamaru | ✓ [random VS 1](../evidence/crossplay-random-vs-1.json) |
| Kabuto | ✓ [random VS 1](../evidence/crossplay-random-vs-1.json) |
| Hidan | ✓ [random VS 1](../evidence/crossplay-random-vs-1.json) |
| Kakuzu | ✓ [random VS 1](../evidence/crossplay-random-vs-1.json) |

## 3. Фоны (приоритет 3)

Все 17 в VS: District, SandCountry, Cave, Deep, Hideout, Rain, SnowCountry,
River, Forest, Arena, RamenPlace, Springs, Academy, CastleRoof, Valley,
Grassland, Path.

| Фон | Статус |
| --- | --- |
| District | ✓ [оригинал → Mac 1](../evidence/crossplay-original-to-mac-1.json), запуск 5 (память); e2e VS (скрин) |
| SandCountry | ✓ [random VS 1](../evidence/crossplay-random-vs-1.json) |
| Cave | ✓ [random VS 1](../evidence/crossplay-random-vs-1.json) |
| Deep | ✓ [random VS 4](../evidence/crossplay-random-vs-4.json) |
| Hideout | ✓ [random VS 2](../evidence/crossplay-random-vs-2.json) |
| Rain | ✓ [random VS 2](../evidence/crossplay-random-vs-2.json) |
| SnowCountry | ✓ [random VS 1](../evidence/crossplay-random-vs-1.json) |
| River | ✓ [random VS 1](../evidence/crossplay-random-vs-1.json) |
| Forest | ✓ [random VS 1](../evidence/crossplay-random-vs-1.json) |
| Arena | ✓ [random VS 2](../evidence/crossplay-random-vs-2.json) |
| RamenPlace | ✓ [random VS 2](../evidence/crossplay-random-vs-2.json) |
| Springs | ✓ [random VS 1](../evidence/crossplay-random-vs-1.json) |
| Academy | ✓ [random VS 1](../evidence/crossplay-random-vs-1.json) |
| CastleRoof | ✓ [random VS 3](../evidence/crossplay-random-vs-3.json) |
| Valley | ✓ [random VS 4](../evidence/crossplay-random-vs-4.json) |
| Grassland | ✓ [random VS 4](../evidence/crossplay-random-vs-4.json) |
| Path | ✓ [random VS 4](../evidence/crossplay-random-vs-4.json) |
| встроенный фон 99 | ✓ [random VS 1](../evidence/crossplay-random-vs-1.json) |

## 4. Режимы и стадии (приоритет 4)

| Строка | Статус |
| --- | --- |
| Stage: 25 стадий, 138 фаз; дальше 1-1 | … Stage 5-1 с тремя союзниками совпала (`crossplay-loop/stg1/35`); с бездействующим P1 союзники останавливаются у GO, поэтому дальше P1 идёт вправо и бьёт (`--p1 walk`) |
| Stage: Survival (пятое нажатие на строке Stage) | ✓ поведение одинаково: в `data/stage.dat` NTSD 2.4 25 стадий (id 0–4 … 40–44), стадии 50 нет; оба показывают «Survival Stage» без врагов (Man: 0) и не заканчиваются, пока P1 жив ([оригинал](../evidence/crossplay-survival-original.jpg), [Mac](../evidence/crossplay-survival-mac.jpg)) |
| Stage: финал (меню 300, ENDING) в живом приложении | — |
| Tournament: весь турнир, а не только матч игрока | — |
| Team Tournament: весь турнир | — |
| War: разные настройки войск | … `random_vs.py --mode war`: множители защиты и численность войск из затравки, 4 записи Mac готовы |
| Demo (не записывается: сравнение по кадрам и времени) | … `demo_crossplay.py`: таблица ГСЧ оригинала заменяется таблицей Mac, состав совпал; первое отличие (тик 144) — фаза 450bd0, которая идёт и в меню; фаза выставляется на первом тике |
| Сложность: все значения 450c30 | ✓ Easy (2), Normal (1), Difficult (0) с 7 компьютерами, 6 из 6 ([random VS 5](../evidence/crossplay-random-vs-5.json)); CRAZY! (−1) открывается только при 458428 ≠ 0 (переключатель клавиши управления), не проверено |

## 5. Механики (приоритет 5)

| Строка | Статус |
| --- | --- |
| Предметы и оружие (подбор, бросок) | ✓ на уровне Summary: каждый из 25 персонажей подбирал предметы в совпавших матчах (до 15 подборов; [сводка](../evidence/crossplay-mechanics-tally.json)); бросок отдельно не выделен |
| Спецприёмы и MP у всех персонажей | ✓ на уровне Summary: MP Usage > 0 у всех 25 в совпавших матчах ([сводка](../evidence/crossplay-mechanics-tally.json)); по отдельным приёмам — не выделено |
| Резервы и порождение войск War | — |
| Призывы и объекты (типы 1–5) | — |

## 6. Меню и настройки (вне повторов; сравнение снимков, кроме шрифта GDI)

| Строка | Статус |
| --- | --- |
| CONTROL SETTINGS: запись `control.txt` | — |
| RECORDING INFO: имя, запись вкл/выкл | — |
| Выбор персонажей и команд, Random | — |
