# Текущая передача работы

Срез 2026-09-12. Это навигация для следующего goal, не новая приёмка игрового
поведения. Обязательный порядок работы — [WORKFLOW](WORKFLOW.md); подробная очередь
и доказательства — [RESEARCH_MAP](../RESEARCH_MAP.md). Старые «NEXT» читать в контексте
соответствующего исследования, а не как конкурирующие команды запуска.

## Принятая опора

[Матрица подготовки War](LIB_WAR_PREPARATION_MATRIX.md) принята в своём конечном
объёме: 256 внешних вызовов, 236 возвратов War, 56 подготовок. Она сохраняет
порядок music RNG перед arena RNG, sparse seats, retained owners и промежуточные
числовые stores. Приёмка: [evidence](../evidence/lib-war-preparation-matrix.json).
Предшествующий [preflight](LIB_WAR_PREPARATION_NATIVE_PREFLIGHT.md) остаётся отдельным
принятым корпусом. Ни один из этих результатов не является сыгранным полным матчем.

Не перезапускать завершённые матрицу, preflight, War setup и каталожные захваты.
Их ошибки, исходные ожидаемые данные, masks, frozen plans и producers сохраняются.
Полный каталог candidate5 закончил на объявленном лимите хранилища после 28 Objects;
это не полный возврат каталога. Проверять его сохранённые job-данные, не следовать
старым историческим записям, называющим тот процесс живым.

Завершены также два накопленных Native-блока:
[собственные файлы/каталог](APPLICATION_CATALOG_NATIVE_FILES.md) и
[library transforms](LIB_TRANSFORMS.md). Приняты три прежних полных каталога
через собственный файловый слой, ограниченные DAT/Object lifecycle и четыре
отрицательных close responses; 1 760 returned transform cases сравнились по
полным нормализованным записям/маскам и 3 480 событиям. Четыре source faults
отдельно отвергаются Native с откатом и не считаются совпадениями.
Release: 40 тестов плюс четыре после добавления negative-close, 41 уникальный
тест, без ошибок. Нового исполнения оригинала нет. Состав, transport, review,
архивы и границы: [evidence](../evidence/pending-native-completion-2026-09-12.json).
Полные собственные каталог, library loop и приложение остаются открытыми.

Принят [NULL bitmap при подготовке War](LIB_WAR_NULLABLE_BITMAP.md): три сохранённых
returned вызова s02/00, s02/01 и s03/00 совпадают с Native по целому вызывающему
пути, 3 838 событиям и 48 числовым checkpoints. При первом NULL четыре поздних
owner сохраняются и переживают следующий Start99 без Release/free. Проверены
11 связанных откатов; Native самостоятельно выполняет по десять принятых
prefix calls для двух цепочек, без нового исполнения оригинала.
Raw-тест прошёл за 19.231с; 17 bundled release-тестов за 510.590с, включая
матрицу 256 вызовов, preflight 22 и общие Tournament/Team/resource регрессии.
333 прежних fixtures неизменны, 336 текущих/777 Native-файлов, Git и оба архива
проверены. [Приёмка](../evidence/lib-war-nullable-bitmap.json).
Отдельный s03/01 source fault и остальной error corpus этим не приняты.

Приняты [частичные surfaces War](LIB_WAR_PARTIAL_SURFACES.md): шесть сохранённых
returned s04..s09/call-00, 7 884 события, 96 numeric checkpoints, пять wrapper
owners на вызов и 18 связанных откатов. Сохраняются неизвестные размеры при
missing image, неудалённый image при CreateSurface failure и запись о Release
при colorKey failure. Последняя не доказывает фактического уничтожения surface.
Raw прошёл за 38.681с; девять bundled release-тестов за 268.324с, включая War
matrix/preflight/nullable и общие BitmapSurfaceLoading/CharacterMenuSurface.
Нового исполнения оригинала и изменения Core/expected не было. 336 прежних
fixtures неизменны, 342 текущих/784 Native-файла, Git и три отдельных архива
проверены. [Приёмка](../evidence/lib-war-partial-surfaces.json).
Шесть следующих call-01 source faults сохранены отдельно и не приняты как matches.

Приняты [ошибки графических API War](LIB_WAR_GRAPHICS_ERRORS.md): восемь
сохранённых returned s12..s19/call-00, 10 550 событий, 598 API-запросов,
128 numeric checkpoints, 40 новых wrapper owners и 24 связанных отката.
Проверены точные остановки после выбранного API, recording и перед outer return.
При GetDC failure два запроса пропускаются только в первом constructor;
CreateDC0 передаётся следующим операциям. DeleteDC фиксирует запрос даже при
результате 0, а DeleteObject0 сохраняет image с deleted=false. Эти записи
не доказывают реальное существование или уничтожение Windows/device объектов.
Raw прошёл за 50.264с; десять bundled release-тестов за 317.460с, включая War
matrix/preflight/nullable/partial и общие BitmapSurfaceLoading/CharacterMenuSurface.
Нового исполнения оригинала и изменения Core/expected нет. 342 прежних fixtures
неизменны, 350 текущих/793 Native-файла, staged Git и оба архива проверены.
[Приёмка](../evidence/lib-war-graphics-errors.json). Девять source faults остаются
отдельно; всего приняты 17 из 28 returned error-corpus вызовов.

Приняты [музыкальные ошибки War и два штатных контроля](LIB_WAR_MUSIC_ERRORS.md):
девять saved returned s00/s01/s20/s21/s23/s24/s25/s26/s27, только call-00.
Сравнились 12 028 событий, 144 numeric checkpoints, 221 bodyMusic events,
два сообщения, 827 graphics API requests, 55 wrapper owners и семь wide buffers /
210 bytes; прошли 27 связанных откатов. Responses строятся из declared inputs.
Сообщения сверяются с собственными globals после music stores; NULL Render и
opaque backing после conversion0 сохраняют владельцев и исходные маски.
Raw 56.435с; шесть bundled War-тестов 370.173с и пятнадцать общих тестов
224.595с прошли на одном frozen candidate — 21 уникальный bundled метод.
Core только передаёт optional store observer; правила игры и expected не менялись.
350 прежних fixtures неизменны, 359 текущих/804 Native-файла, Git и оба архива
сверены. Новый source не исполнялся. [Приёмка](../evidence/lib-war-music-errors.json).
Всего принято 26 из 28 returned вызовов; девять source faults остаются отдельно.

Приняты [сохранённые bitmap fields War](LIB_WAR_RETAINED_SCRATCH.md): два
returned s10/s11/call-00, 2 638 событий, 150 graphics API requests, 32 numeric
checkpoints и десять новых wrappers. Native получает поля от собственного menu
descriptor/GetDC и сохраняет их через десять prefix calls и пять arena constructors
в каждом случае. Actual music format завершает loader lifetime: поздние source
ABI bytes остаются известными, но не импортируются как Native dimensions. Copy
field сохраняется; следующий metadata consumer после music имеет отдельную границу.
Проверены десять связанных откатов и семь Native guard controls. Raw
17.523с/build281.21с; bundled War7 за 389.629с и shared10 за
477.643с прошли, 17 уникальных bundled методов. Первый кандидат выявил
60 поздних ABI comparison ошибок; он, поправки плана и второй кандидат сохранены.
Expected не менялись, нового исполнения оригинала нет. Все 359 прежних fixtures,
361 текущий/808 Native-файлов, Git и оба архива проверены.
[Приёмка](../evidence/lib-war-retained-scratch.json). Теперь приняты все 28 returned
вызовов в их объявленных границах; девять source faults остаются отдельно.

## Непринятая работа и отказ Codex

Текущий незакрытый этап — [обычные ошибки ресурсов War](LIB_WAR_PREPARATION_ERRORS_PLAN.md).
Среда и сохранённые исправления стенда описаны в [FS](LIB_WAR_PREPARATION_ERRORS_FS.md)
и [FS/stack](LIB_WAR_PREPARATION_ERRORS_FS_STACK.md). Они не меняют реальную Windows
среду и не разрешают повторять исходные ошибки или продолжать faulted VM.

После обновления методологии завершена отдельная карточка проверки сохранённых
данных: [результаты и Native gaps](LIB_WAR_PREPARATION_ERRORS.md),
[машинная сводка](../evidence/lib-war-preparation-errors.json).

- Все 29 `war-preparation-fs-errors-s*-capture2.job.json` имеют `terminal`, exit 0.
- Старый audit2 проверял 7 сценариев /11 вызовов; он сохранён неизменным.
  Новый read-only audit3 проверил **29 сценариев /37 вызовов:28 нормальных
  возвратов и9 source faults**, все записи/маски, stores, перечисленные reads,
  checkpoints, события выделения/освобождения и терминальные исходы.
- Дополнительная инвентаризация проверяет состав корпуса, input pins,
  290 сохранённых producer proofs,37 переходов live-owner flags и9 failure
  sidecars. Это чтение готовых данных; новых исполнений оригинала нет.
- В исторической сводке `nativeCompared=false`, `fullPreparationComplete=false`,
  `fullGameComplete=false`. Приёмки трёх NULL-вызовов, шести partial-surface,
  восьми graphics-error, девяти control/music и двух retained-scratch возвратов
  не переписывают источник;
  полный Native error corpus ещё не принят.
- Проверка процессов по командам War error capture/audit, transform boundaries
  и result recording не нашла соответствующих работающих процессов на момент
  чтения. Перед любым дальнейшим действием нужна новая проверка; это не инвентарь
  всех процессов проекта.

Данные лежат в `build/research/lib-war-preparation/`, symlink в task-owned X5.
Сводка `build/research/application-catalog-work.json → libWarPreparation.errors`
может отставать от terminal job-файлов: в ней ещё говорится о настроенных
оставшихся сценариях. При расхождении сначала сверять происхождение файлов,
времена, команды и результаты, затем выпускать новую наблюдательную сводку.

Ход Codex завершился 2026-09-12 в 00:30:32.397 UTC с `cyber_policy`; ранее были
ещё два отказа. Все три сохранены в [реестре](../evidence/codex-safety-incidents-2026-09-12.json)
с session/turn, точными ошибками, предшествующими публичными действиями и SHA логов.
Точная причина фильтра и невыданный вывод неизвестны. Последняя завершённая
команда сама по себе не считается доказанным триггером.

Новый goal **не возобновляет автоматически затронутое исследование**. Остановка
ответа Codex также не отменяет уже завершённые захваты. Ограниченный Native
[transform-контракт](LIB_TRANSFORMS.md) теперь проверен по сохранённым данным;
это не снимает прежний incident. Полный transform/application и result-recording
пути остаются с собственными границами и отказами; смена модели не закрывает их.

## Следующая независимая карточка

**Девять отдельных Native rejections с полным rollback по сохранённым source faults.**

Использовать готовую инвентаризацию и read-only review
`build/research/lib-war-preparation/war-retained-scratch-native-20260912/next-boundaries-review.json`.
Проверены 54 pins: 45 report/job/config/pins/raw и девять failure sidecars.
Нового исполнения оригинала, producer imports, исторического audit rerun или
продолжения faulted VM не требуется. Девять отказов Native не являются matches
с исходными memory faults и не закрывают safety incidents.

Конечный объём: s03..s09/call-01, s22/00 и s28/00. Девять собственных цепочек
проходят по десять accepted bound prefix calls; перед семью call-01 воспроизводят
уже принятый call-00 с его owners. Итого 97 returned parent invocations и девять
rejected invocations. Это 90 перекрывающихся prefix calls/десять references,
семь parent-call воспроизведений и девять полных coupled rollback checks.

| Случаи | Native boundary | Сравнимые front events до отказа |
| --- | --- | ---: |
| s03/01 | BG release ownership после четырёх Release/free | 805 |
| s04/01, s06/01, s08/01 | Arena bitmap release ownership | 797 каждый |
| s05/01, s07/01, s09/01 | Та же граница после четырёх пар | 805 каждый |
| s22/00 | Null COM continuation после трёх QueryInterface | 917 |
| s28/00 | Recording allocation unavailable or live alias | 1316 + отдельный allocator result |

Для s04..s07 adapter сейчас раньше Core выбрасывает XCTest unwrap из-за отсутствия
surface binding. Передавать surface0 допустимо только при собственном marker0
и отсутствии собственного surface owner. Отсутствующий binding при marker1
остаётся ошибкой стенда. s08/s09 сохраняют известную released surface identity;
Core отвергает marker0 до повторного Release. У s09 ordinal Release начинается с2.

s22 сохраняет отрицательный event query с явным output0 и третий query после него;
Native отвергает NULL event interface до notify, без wide allocation. Для s28
подать0 из declared.replayNull, а не из ожидаемого after-state. Source содержит
1317 событий, включая calloc0, последующие stores и attempted NULL write.
Native guard стоит до front calloc; сравнить 1316 событий и отдельно объявленные
allocator arguments/result. Не менять expected и не сравнивать Native rollback
с исходным fault snapshot как успешный результат.

Сохранить весь доступный prefix, точный тип/текст Native guard, 16 staged
Release/free пар в четырёх last-layer случаях и полный rollback globals/World/
Actors/BG/War scratch/resource contexts/music/recording/library/events. Общий
XCTAssertThrowsError, Stop.unexpected или XCTest unwrap не устанавливают эту границу.
Корпус содержит 171 511 851 raw bytes, 7 845 source events и 214 checkpoints;
текущий placement guards допускает 7 844 front events плюс отдельный allocator result.

Дальнейший consumer loader storage после его замены музыкальным private ABI
остаётся отдельной неподдержанной связью. Текущая приёмка s10/s11 заканчивается
после их normal returns и не импортирует эти слова в Native. Сначала оформить
конечный план rejection-карточки с обязательными retained War/shared регрессиями.

## Дальнейшая сквозная очередь

Незакрытые error contracts сохраняются как зависимость; далее по готовности —
43a860 War gameplay, собственные каталог/инициализация/внешний цикл и подключение
общего движка к приложению. Независимые ветви допустимы по карте. Первый полный
матч, остальное содержимое, сеть, Windows, окно/ввод/звук и чистая macOS открыты.

## Сохранность и навигация

Исходные 4 954 строки AGENTS сохранены побайтно в
[AGENTS_HISTORY_2026-09-12.md](../../AGENTS_HISTORY_2026-09-12.md), SHA-256
`1f124556e757a1f1efe7dabbc19df76bc482ca9a316df2295eb86beeae1f5dff`.
Файл находится в корне, поэтому его старые относительные ссылки работают.
Ограничения соответствующего исследования обязательны; история не является
новой командой выполнения. Архив не редактировать.

Перед обновлением методологии dirty-файлы закреплены в
`build/research/methodology-update-20260912-before.json`. В продолжении War все31
сохранены побайтно; девять относящихся к исследованию планов/инструментов включены
в исследовательский коммит. Остальные 22 pending-файла завершены отдельной
Native-карточкой выше: их исходные версии сохранены в
`build/research/pending-completion-20260912/initial-pending/`, старые 325 fixtures
неизменны. Из исходных pending изменён только расширенный transform test;
добавлены постоянные проверки, восемь fixtures, упаковщики и итоговые документы.
Исторический work JSON не переписывался. Новые принятые NULL/partial-surface/
graphics/music-error/retained-scratch контракты и следующая карточка fault rejection описаны выше.
