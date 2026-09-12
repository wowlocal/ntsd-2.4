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
  восьми graphics-error и девяти control/music возвратов не переписывают источник;
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

**Собственное сохранение bitmap scratch между War menu и Start:
два normal returned s10/s11, только call-00.**

Инвентаризацию не начинать заново. По сохранённым результатам и readonly review в
`build/research/lib-war-preparation/war-music-errors-native-20260912/next-boundaries-review.json`
оформить конечный Native-план. Объём: 2 638 whole-caller events, 32 numeric
checkpoints, 150 graphics API requests и десять новых живых wrappers.
Две Native-цепочки выполняют по десять собственных prefix calls, перекрывающих
те же десять принятых bound 0000..0009.

Происхождение всех 16 нужных байт найдено в accepted bound0001 `war-ready`,
последнем BATTLETROOPS. Stores363/364 от memset собственного CreateSurface
descriptor задают bytes[72..<80]; это будущие loader width/height в s10.
Stores417/418 сохраняют declared getDC#13.output и его result; это будущие
copy height/width в s11. До этих stores backing A5/unknown; после них байты
определены. Prefix0002..0009 и текущие вызовы до потребителей не перезаписывают
их; полные before/after records сохраняют bytes/masks. Наблюдаемые 0/0 и
0/370000d0 нельзя задавать литералами как игровые размеры.

Native уже создаёт descriptor и получает API response, но теряет эти поля
между вызовами. Добавить собственное retained state через WarMenuMemory и
передать его в arena loader/copy scratch. Разделить source caller depths:
menu loader/copy SP1000d394/1000d2e4 и preparation1000d36c/1000d2bc, сдвиг0x28.
Глобальный «последний GetDC» неверен: новый getDC#14 пишет другое место и не
заменяет прежнее значение, использованное как height. Модель должна хранить
отдельные семантические producer/consumer slots, без импорта source stack.

Обновлять retained state из собственного descriptor и фактического declared
API response. Сохранить различие lifetime masks и current-helper API masks:
при getObject#27=0 / description#14=-1 новых writes нет. s10 получает wrapper
0/0, но последующий copy GetObject возвращает реальные 384/383. В s11 wrapper
остаётся 384/383, а destination dimensions Stretch берутся из retained slots.
Все прежние ownership, globals, recording и request comparisons остаются полными.

Предусмотреть шесть late rollback trials: после createSurface#14 для s10 /
stretch#14 для s11, затем recording и beforeReturn для обоих. Дополнительно
объявить точку и число откатов формирования retained state в позднем War-menu
caller. Новое состояние входит в общую транзакцию. Сохранить matrix/preflight,
все принятые error cards, изменённые общие bitmap/menu регрессии и старые direct
unknown-field rejections. Найденная связь глубин не распространяется автоматически
на другие caller paths. Новое исполнение оригинала для этой карточки не нужно.

Это новая работа над Native по готовым данным, а не повтор исходного захвата.
Она не разрешает затронутую отказом операцию и не закрывает incident. Остальные
зависимости перечислены в итоговом исследовании: whole-War scratch join,
девять отдельных fault rejection trials и дальнейшие replay/gameplay contracts.
s10/s11 нормально вернулись; собственное Native-сохранение найденных producer
bytes ещё не реализовано. Объявлять их source faults или подставлять expected нельзя.
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
graphics/music-error контракты и следующая карточка retained scratch описаны выше.
