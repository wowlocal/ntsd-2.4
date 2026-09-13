# Текущая передача работы

Срез 2026-09-13. Это навигация для следующего goal, не новая приёмка игрового
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

Приняты [девять Native отказов с полным rollback](LIB_WAR_FAULT_REJECTIONS.md)
по saved s03..s09/call-01,s22/00,s28/00. Каждый тест выполняет97 returned parent
invocations и9 отдельных отказов, сравнивает7844 front events плюс отдельный
allocator0,214 checkpoints (включая32numeric),38music и202graphics events.
Шестнадцать staged Release/free pairs в четырёх last-layer случаях полностью
откатываются вместе с globals/World/Actors/BG/bitmap/music/replay/War/library/events.
Это Native rejections, а не matches исходных memory faults. Для s28 guard стоит
до front calloc; middle-state clear/live установлен code review, не snapshot.
Raw56.029с/build278.35с; bundled War8 за443.553с
и shared10 за474.245с прошли:18 уникальных bundled методов.
Первый кандидат остановился на отсутствующем nested startup report; ошибка,
первый review и поправка callback mapping сохранены. Core/expected не менялись.
Все361 прежних fixtures,370 текущих/818 Native-файлов, Git и оба архива проверены.
Нового исполнения оригинала нет. [Приёмка](../evidence/lib-war-fault-rejections.json).
Все28 returned error-corpus вызовов приняты в своих границах; для девяти source
faults проверены отдельные Native rejection/rollback contracts. Полная игра и
три safety incidents остаются открытыми.

Принята [собственная menu-session в production Core](APPLICATION_MENU_SESSION.md).
OriginalApplicationMenuSession выполняет50 сохранённых цепочек:62 завершённые
итерации и3 явные loading boundaries,18835 событий/869 checkpoints/9000 RNG.
Сравниваются1171 committed platform operation и отдельно3 pending clear, а не
повторное исполнение helper summaries. Canonical full record сохраняет реальные
aliases/masks; registry удерживает live/dead owners, библиотеку/DC и RNG.
Восемь поздних откатов и новые alias/unknown/owner/effect guards прошли вместе
с MenuReturn/MenuInput/MessageLoop/LoadingPrefix:11 release-методов за68.560с,
сборка283.55с. Первый compile setter failure и замечания review сохранены.
370 прежних fixtures неизменны,819 Native-файлов и оба архива сверены. Четыре
старых envelopes опускают финальный LF: payload+LF точно воспроизводит все
276384592 raw bytes/SHA,JSON и16424 blob entries. Эталоны не менялись.
Нового исполнения оригинала нет. [Приёмка](../evidence/application-menu-session.json).
На том этапе bootstrap ещё создавался в Native test composer; следующая
принятая карточка ниже переносит его в Core. Приложение и игра остаются открытыми.

Принят [production bootstrap от WinMain entry до первого меню](APPLICATION_BOOTSTRAP.md).
OriginalApplicationBootstrap сохраняет весь startup owner (panel/calendar/music/
пять WAV) и живую MenuSession. Core выполняет startup, resize,24 front resources,
settings, background/body/menu и timer return. Прежние50 session chains и12
LoadingPrefix cases получают этого собственного родителя.
48 primary attempts содержат один distinct WinMain original-entry и перекрывающиеся
43body/40front/19settings/7bitmap parents:47 menu commits и отдельный NULL-cursor
rejection/rollback. Startup144 операции (7input/20own-memory/117platform) повторён
48раз; early callbacks49 операций считаются отдельно. First-menu22623 committed
операции и464 uncommitted NULL-операции сверены по сохранённому порядку и маскам.
24 bundled release-метода прошли за149.107с, сборка293.60с, включая6 новых startup
и17 first-menu late controls. Candidate1 timer-routing failure и две ошибки
нового read-only projection verifier сохранены. Все370 fixtures неизменны,
822 Native-файла и оба архива сверены; пять дополнительных raw/fixture пар
воспроизводят205795824rawbytes и5443blobentries. Первые четыре пары используют
прежнюю полную проверку после новой сверки pins. Нового исполнения оригинала нет.
[Приёмка](../evidence/application-bootstrap.json). Это проверка declared inputs;
file/package/AppKit/audio, полная загрузка/каталог/игра и три incidents открыты.


Принят [регулярный пакет startup inputs](APPLICATION_STARTUP_INPUTS.md):
46 файлов/29700372 bytes содержат PE initial record50088 с доказанными masks,
adinfo/control, пять WAV и36 исходных DIB. Native владеет неизменяемым снимком,
строит19 settings inputs из явных преобразований control и получает bitmap
metadata из DIB, surface descriptions — из своего CreateSurface request.
Все48 primary attempts,50 MenuInput chains и12 LoadingPrefix cases используют
этого родителя; полные image/surface bindings сравниваются, сохраняются в Session
и откатываются вместе с ним. 28 bundled release-методов прошли за173.944с,
сборка295.28с. Проверены перенос в .app, отсутствие/порча пакета и независимость
снимка от последующего удаления файлов. Native1 path-alias failure, неисполненный
frozen candidate2 и исправленный candidate3 сохранены; expected не менялись.
Все370 fixtures,871 Native-файл и оба архива проверены. [Приёмка](../evidence/application-startup-inputs.json).
Новое исполнение оригинала не требовалось. Это inputs/metadata, ещё не pixels,
host graphics/audio, запуск приложения или полная игра; три incidents открыты.

Приняты [Native colors/masks для36 startup DIB](APPLICATION_DIB_PIXELS.md).
Два независимо закреплённых data decoder совпали по всем40736644 bytes:
30552483 RGB +10184161 masks. Проверены14632 rows и все44980 RLE commands.
10037872 пикселя записаны;146289 остаются неизвестными в cursor/SLOGAN/WORDS.
OriginalDIBPixels хранит top-left RGB8/defined; Bitmap владеет ими до Core attempt,
live image lookup отвергает удалённые handles, чтение unknown color — явная ошибка.
Прежние48/50/12 parent chains сравнивают новые colors/masks actual image owners
с сохранением всех records/events/rollback. 20 bundled release-методов прошли
за135.303с, сборка297.09с;18 controls =3 returns/15 rejections.
ImageIO отдельно совпал для29 ресурсов, разошёлся на567 written pixels в7;
его данные/диагностика сохранены, expected под host не менялись. Два synthetic
host controls не добавляют исходных ресурсов. Все370 прежних fixtures и46
package files неизменны;372 текущих fixtures/875 Native-файлов и оба архива
проверены. [Приёмка](../evidence/application-dib-pixels.json). Нового исполнения
оригинала нет. Unknown colors, surface/raster/device и полная игра остаются открытыми.

Принята [полная инвентаризация bitmap/surface startup](APPLICATION_BITMAP_SURFACE_INVENTORY.md).
Все48 primary/50MenuInput/12LoadingPrefix цепочек связаны с224 stage identities
и354 retained parent entries;41658 исходных событий сохранены целиком.
200 StretchBlt в7 bitmap/40front stages — full-image1:1 SRCCOPY;36 имён ресурсов
содержат28 разных DIB payloads. Отдельно491 downstream Blt также без scaling,
но их flags/clipping/NULL sources и raster contract остаются отдельными.
Все errors, повторное использование DC по поколениям и3 поздних Release
(3input/12loading occurrences) сохранены. Source image deletion не решает
срок хранения скопированных цветов; Release не доказывает уничтожение устройства.
Declared primary8-bit indexed reply не задаёт palettes/конверсию offscreen.
Inventory1 raw-deflate failure, inventory2 DC-reuse assertion и отдельно
закрытый catalog4 publication gap сохранены. Никакого исполнения оригинала
или нового Native теста нет;875Native/372fixtures/46package/90pins неизменны.
[Результат и проверки](../evidence/application-bitmap-surface-inventory.json).

Приняты [собственные source colors для startup surfaces](APPLICATION_SURFACE_COLORS.md).
40 saved bitmap/front lifetimes (индексы0..34,36..40),16929 полных API operations,
995 surfaces/992 copies/3 uncopied owners и993/992 поколения DC совпали с Native.
Surface сохраняет исходные RGB/masks после DeleteObject; unknown не становится
black. MenuSession учитывает3 поздних method8 Release до observer, включая12
loading parents; prefix-aware comparison и whole rollback сохраняются.
23 bundled release-метода за142.844с/build308.06с прошли без корректировок
кандидата/expected; все48 primary routes (47commits/1NULL rejection),50 input
и12 loading chains сохранены.17 supplemental controls дополняют source cases.
372 старых fixtures/46package неизменны;373current/878Native и оба архива
проверены. Две data-only reference ошибки сохранены; оригинал не исполнялся.
[Приёмка](../evidence/application-surface-colors.json). Device conversion,
palette/raster, полная игра и три safety incidents остаются открытыми.

## Непринятая работа и отказ Codex

Сохранённый этап — [обычные ошибки ресурсов War](LIB_WAR_PREPARATION_ERRORS_PLAN.md).
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
  девять отдельных rejection/rollback contracts приняты новой карточкой выше;
  source faults не считаются успешными matches.
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

Приняты [графические владельцы startup](APPLICATION_GRAPHICS_OWNERS.md):
Bootstrap/Session связывают команды с собственными display/bitmap/DC generations
и снимками source colors. Все48 primary attempts (47commits/1NULL rejection),
50 input и12 loading chains сравнили53 265 команд из224 stages;5 612 команд
уникальны. Сохранены501 nonnegative text acquisitions,6 negative GetDC и6 failed
ReleaseDC, точные rectangles, ответы API и whole rollback. Loading пока остаётся
композицией принятого production helper в тесте.32 bundled release-метода прошли
за166.551с/build309.09с. Ошибки двух первых кандидатов, три замечания review
и исправление hardcoded loading reply сохранены; expected неизменны.
373 старых fixtures/46package неизменны;374current/881Native и оба архива
проверены. [Приёмка](../evidence/application-graphics-owners.json). Финальные pixels,
реальное устройство, полная игра и три safety incidents остаются открытыми.

Принят [переход от меню к общей загрузке](APPLICATION_LOADING_SESSION.md). Собственный обработчик
принимает PendingLoading, выполняет MENU_WAIT, загрузку общих WAV и presentation.
Он сохраняет полный record 0xc3a8, PCM и маски, порядок операций и графические
команды. Проверены все 12 случаев: девять доходят до PendingCatalog, три явно
отвергают продолжение после ошибки CreateSoundBuffer. Результаты всех 190 WAV
попыток наблюдаются однократно: 187 возвратов и три отказа. Пять поздних ошибок
сохраняют прежнее состояние меню; незавершённая итерация таймера не фиксируется.

Пакет из 19 файлов (353 249 байт) содержит 18 исходных WAV (351 078 байт).
Все 19 release-тестов прошли за 155.354 с, сборка — 316.59 с. Прежние 374 fixtures
и 46 файлов Startup неизменны; проверены 903 Native-файла, новый пакет и оба
архива. Ошибка первой проверки размера sparse relations сохранена; после
фиксации candidate1 код Core и ожидаемые результаты не менялись.
[Приёмка](../evidence/application-loading-session.json). Полный каталог, возврат из загрузки и внешнего цикла,
вывод изображения/звук, матч/игра и прежние incidents остаются открытыми.

## Текущая граница и следующая карточка

[Поддержка всех 669 исходных изображений](APPLICATION_CATALOG_DIB_INPUTS.md)
сохранена как отдельная принятая зависимость. Реализован
[собственный catalog session из PendingCatalog](APPLICATION_CATALOG_SESSION.md).
Три Native-цепочки из собственного bootstrap/menu/common состояния совпадают до
20-го child return: по 194 bitmap, 4 995 malloc, 94 WAV и 51 510 событий.
На всех 60 границах сверены полные records/masks, files, WAV, globals, allocations,
операции и новые graphics/color owners. Parent остаётся с count19/188 known bytes:
двадцатый slot ещё не записан. Native knowledge отделена от source-observed mask.

21 bundled release-метод прошёл за 136.426с/build307.11с, включая прежние полные
каталоги и loading-регрессии. Проверены поздние откаты и запрет allocation overlap
с живыми common PCM. Source/expected неизменны; нового исполнения оригинала нет.
425 pins, 913 Native-файлов, 379 fixtures и оба пакета проверены; ошибки preflight,
transport и первой компиляции сохранены. [Evidence](../evidence/application-catalog-session.json).
Независимые plan/reference/draft review сохранены. Доступный отдельный reviewer
завершил [review4](../evidence/application-catalog-session-final-review.json) точного
f601614 без существенных замечаний: gap финального comparator закрыт.
12 449 appended graphics commands на цепочку сверены независимо. Все3 177 Blt
читают прежние три surfaces;194 новых catalog surfaces проверены по owners/RGB/
masks, а их последующий draw consumer ещё открыт.

[Полный input preflight](APPLICATION_CATALOG_FULL_INPUTS.md) подтвердил156 DAT/
registry-файлов,365 WAV и669 изображений —647 179 902 исходных байта. Все400 WAV
вызовов возвращаются1 без live temporary. Но старый audio adapter в одном CPU
сбрасывает w.regions и переиспользует два PCM mapping:666 сохранённых областей
не означают666 одновременно живых allocations. Полные записи и порядки каталогов
есть; полного clock/message/COM/DC потока собственного приложения в них нет.
[Evidence](../evidence/application-catalog-full-inputs.json):1219 pins/1227 archive
members проверены; все913 Native/379 fixtures и пакеты неизменны, новых запусков нет.

Принят [полный собственный Native catalog → PendingPool](APPLICATION_CATALOG_FULL_NATIVE.md)
в явно объявленном platform environment:137 Objects/17 BG/Stage,155 child returns,
829 bitmap owners,400 WAV и15 683 allocation tuples. Сверены полные Object/101 BG/
60 Stage records/masks, файлы, retained cache backing, новые bindings и цепочка
callbacks → operations → graphics. Исходный stride20/full-path cache воспроизведён
независимо:7412 записанных offsets/4364 retained, включая588 внутри первых8000.
Expected и Core game rules не менялись; все379 fixtures сохранены.

24 bundled release-теста прошли за191.186с/build312.21с; поздний Stage rollback,
before-publication rollback и новая попытка с fresh provider проверены. Independent
review закрыл существенные замечания. Все916 Native-файлов, пакеты и оба архива
проверены. Native1 compile failure, Native2 cache mismatch/явная остановка после
профиля XCTest и неисполненный frozen3 сохранены. [Evidence](../evidence/application-catalog-full-native.json).
Полного original application return или новых Windows/device/raster наблюдений нет.

Принято [соединение собственного каталога с pool/UI](APPLICATION_POOL_INTERFACE.md):
400 Actors/408 constructor returns, две полные фазы пула,10 UI bitmaps/170 API
и11 исходных global stores. PendingInput сохраняет actual World/globals/aliases,
каталог,423 WAV owners и20 command bytes.10 DIB/40102 bytes дают102933 pixels:
96058 known/6875 unknown; все RGB/masks/313 rows проверены независимо.
26 bundled release-тестов прошли за190.426с/build313.61с, включая8 поздних
откатов и19 guards.379 прежних fixtures неизменны,381 текущий/934 Native-файла,
пакеты и архивы сверены по manifests; [evidence](../evidence/application-pool-interface.json).
Native1 pass, неисполненный frozen2 и Native2 compile error сохранены;
финальный candidate3 меняет лишь конфликтовавшее локальное имя теста.

**Следующая задача — продолжить PendingInput с41c581 через input/loading caller
к outer loop и backend publication.** Сохранить собственные pool/UI, текущий
каталог, звуки, RNG, полные records/masks, aliases и whole-attempt rollback.
Не подставлять expected after-state. Полный original application return и draw
consumers новых catalog/UI surfaces остаются открыты. Completed captures,
включая terminal candidate5 после28 Objects, не перезапускать.

Actual raster всё ещё не имеет достаточных format/palette/device inputs в
проверенных зависимостях. Эта граница открыта; исходные RGB не становятся
измеренными Windows pixels. Catalog/loading выбраны как независимая ветвь.

Source-color owners и привязка команд приняты в
[APPLICATION_SURFACE_COLORS](APPLICATION_SURFACE_COLORS.md) и
[APPLICATION_GRAPHICS_OWNERS](APPLICATION_GRAPHICS_OWNERS.md).
Повторять полный inventory,40 lifetime assignments или завершённые тесты для
нового оформления не нужно. Повторять command binding тоже не нужно.
Сохранённые 491 downstream Blt, графические события,
полные request flags и источники находятся в принятом inventory/event-catalog.
Перед будущей реализацией raster consumer определить доказанные входы его формата,
палитры, color key, clipping, текста и назначения; неизвестные зависимости
перечислить до реализации. Primary reply объявляет8-bit indexed, но actual
offscreen conversion/палитра/инициализация устройства пока не установлены.

Нельзя объявить source RGB финальными Windows pixels или незаметно заменить
неизвестный цвет чёрным/alpha0. Все146289 DIB holes и18 downstream NULL-source
occurrences сохраняют границы. Новую карточку ограничить готовыми доказательствами,
целым вызывающим путём и late rollback; expected закрепить независимо от Core.
Исторические producers/captures/auditors не перезапускать. AppKit input/clock/audio,
full loading/catalog, War/матч/полная игра/Windows/cleanMac и три safety incidents
остаются открытыми.

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
graphics/music-error/retained-scratch/fault-rejection и menu-session/bootstrap контракты описаны выше.
