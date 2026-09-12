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
  `fullGameComplete=false`. Приёмки трёх NULL-вызовов, шести partial-surface
  и восьми graphics-error возвратов выше не переписывают этот источник;
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

**Музыкальные ошибки и два штатных контроля: девять saved returned
s00/s01/s20/s21/s23/s24/s25/s26/s27, только call-00.**

Инвентаризацию не начинать заново. По сохранённым результатам и readonly review в
`build/research/lib-war-preparation/war-graphics-errors-native-20260912/next-music-errors-review.json`
оформить конечный Native-план. Объём: 12 028 whole-caller events, 144 numeric
checkpoints, 221 bodyMusic events, 827 preparationGraphics API requests, включая
два сообщения, 55 новых wrapper owners и семь wide owners / 210 bytes.
Девять Native-цепочек выполняют 90 prefix calls, перекрывающих двадцать прежних
случаев: s01 требует bound 0011..0020 с firstCase11, остальные — 0000..0009.

Строить музыкальные responses независимо из `resourceFailureInput.music` и
закреплённого producer contract, сохраняя различие nil output и явного 0.
`spec.music` у этих девяти отсутствует. Expected responses остаются сравнением.
В s20/s26 сообщение находится последним в preparationGraphics, а не bodyMusic;
нужен мост `.message` → whole `.preparationBitmap` без увеличения musicIndex.
Сравнивать его globals после музыкальных stores по собственному shadow.
Минимальный возможный join — optional store callback у resumeMatch, переданный
существующему play(store:); это не разрешение импортировать source after-state.

Для s27 producer явно объявляет собственный allocation 2c020020 с backing
a5 × count, defined=false и live=true. Native самостоятельно создаёт 30 байтов
с исходными unknown masks; conversion none/result0 ничего не записывает.
Render получает собственный opaque buffer без UTF-16 decoding. s25 сохраняет
NULL allocation, convert/Render с NULL и отсутствие wide owner. Это контроль
синтетических API-ответов, не проверка Windows converter/codec.

Проверить полные records/masks/owners и 27 связанных откатов: по одной точке
после обработки целевого результата, затем recording и beforeReturn в каждом
случае. Точные callback requests описаны в review; получение запроса и применение
его возвращаемого ответа различаются. Сохранить matrix 256, preflight 22,
nullable 3, partial 6, graphics 8; при изменении resumeMatch — также
OriginalMusicPlaybackTests, OriginalGraphEventsTests и связанные music/menu callers.
Новое исполнение оригинала для этих девяти сохранённых возвратов не требуется.

Это новая работа над Native по готовым данным, а не повтор исходного захвата.
Она не разрешает затронутую отказом операцию и не закрывает incident. Остальные
зависимости перечислены в итоговом исследовании: music/replay contracts,
whole-War сравнения, девять отдельных fault rejection trials и s10/s11 с
неустановленным собственным происхождением private dimensions. Два последних
нормально вернулись; объявлять их source faults или подставлять expected нельзя.
Новые источники для удобства формата/адаптера не запускать.

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
graphics-error контракты и следующая музыкальная карточка описаны выше.
