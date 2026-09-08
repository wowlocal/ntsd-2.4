# R02.1/R15 — общий обработчик обновления панели

Эталон — EXE SHA-256
`3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c`;
VC80 DLL SHA-256
`c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d`.
Первый путь продолжается от свежих World/resources/settings через
[первый рисунок](FRONT_SCREEN_PRELUDE.md), настоящий call`427127`, весь
`4236d0` и ret в`42712c`. CPU, стек и память исходника не восстанавливаются из
сохранённого снимка между этими участками. Это всё ещё не полный WinMain/startup.

Четыре зависимости исполняются настоящими дочерними вызовами:
[content43c780](MENU_CONTENT.md), [bitmap43cc60](MENU_PANEL_BITMAP.md),
[writers43c690/43c710](MENU_INFO_WRITING.md). Их существующие source observers
подключены к тому же VM. Native `OriginalMenuPanelUpdate` вызывает уже проверенные
`OriginalMenuContent`, `OriginalMenuPanelBitmap` и `OriginalMenuInfoWriting`.
Нативные globals, World и ранние ресурсы берутся из собственного проверенного
родителя через необязательный `FrontScreenPreludeReference.onNatural`.
Ожидаемые после-снимки не становятся игровым состоянием native.

## Порядок родителя

1. EnterCriticalSection(`4554a4`).
2. Если `458424 != 2`, сразу LeaveCriticalSection и возврат; статус сохраняется.
3. При статусе2 сравнить **signed32** `44d77c` (поступившая версия) с `44d778`
   (текущая). Затем записать `458424=0`, сохранив уже вычисленный результат сравнения.
4. Если поступившая версия не больше текущей, скопировать строку `458350` в
   `4527b0` побайтно через NUL, вызвать cache writer43c710, Leave и вернуть управление.
5. Иначе переключить `44d784`, вызвать content43c780 и, только при его успехе,
   bitmap43cc60. Успех обоих ведёт к копированию новой даты и cache writer.
6. При неуспехе любого из них переключить индекс повторно. Снова content, затем
   при успехе bitmap. Успех второй попытки вызывает **только cache writer**,
   без копирования новой даты.
7. Если вторая попытка не удалась, вызвать **defaults43c690, затем cache43c710**,
   после этого Leave и возврат. Вторая запись не удаляется как «лишняя».

Оба обычных ret (`42376f` и`4237d3`) продолжают настоящий caller в`42712c`.
Вложенные ret sites проверяются отдельно: content`423726/42374d/42379a`,
bitmap`423775/423756`, defaults`42375f`, cache`423764/4237c8`.
Родитель не проверяет успешность записи файла. Defaults/cache сохраняют свои
исходные изменения и порядок IO даже после ошибок.

Переключение — signed remainder `(Int32(1) &- oldIndex) % 2`, а не boolean toggle
или unsigned mask. Повторное переключение произвольного исходного индекса не
обязано восстанавливать его прежнее значение. Проверены отрицательные и крайние
индексы, включая minInt32. Значение версии, записанное самим content loader,
не запускает повторное сравнение в уже идущем вызове родителя.

Дата копируется на первой успешной новой версии и в ветви «версия не больше».
При возврате ко второй версии сохраняется старая дата. Defaults сбрасывает её
своим отдельным UInt32`now\0`. Byte-copy родителя и UInt32 default reset остаются
разными операциями с разными нетронутыми хвостами.

## Общее владение ресурсами

Bitmap handler сохраняет свой реестр поколений между вызовами родителя. Первая
неудачная bitmap-загрузка могла уже уничтожить прежнюю картинку. Если после неё
второй content не открылся, defaults/cache не восстанавливают прежний bitmap
и не удаляют новую пустую оболочку. Это видно по полным records/live flags.
Повторные выдачи освобождённого адреса проходят через тот же loader.

World и все25 ранних bitmap wrappers (24 startup и один фон) сохраняются и
сравниваются после каждого вызова. Панель выделяется в отдельном объявленном
allocator arena; source/native не подставляют её поверх ранних ресурсов.
Normal surface word+0 нормализуется только в известных bitmap records, raw
surface tokens и прочие globals сохраняются по прежним правилам.

## Входы и границы проверки

В первом входе свежего объявленного parent статус обновления равен0: он реально
исполняет Enter/Leave без дочерних загрузок. Worker не запускался. Все последующие
входы`427127` явно предоставляют caller registers/stack position и изменения
worker globals перед вызовом, продолжая собственные оставшиеся globals/resources.
Это контролируемые вызовы родителя, а не полные последующие итерации экрана.

Исходные ad0/ad1 txt/bmp отсутствуют. Успешные текстовые входы составлены по
формату EXE. Для успешного bitmap device response явно использован исходный
MENU_BACK1 DIB809×547 при запрошенном ad-пути; это **контрольная привязка на
границе устройства**, не новый игровой asset или доказательство содержимого
загруженной по сети рекламы. Raw DIB и отсутствие исходных файлов закреплены.

Перед каждым content helper наблюдается его настоящий entryESP−`454` backing,
без изменения стека. Маска1104-byte local region начинается с объявленного
неизвестного состояния, затем отмечает фактические записи child. Native получает
эти до-вызова bytes как явный stack boundary. В последнем аварийном случае
backing специально задан A5, а файл пустой: исходник останавливается перед
`sscanf` call`43c817`, native сообщает такую же границу.

При этой остановке статус уже очищен, частичные записи сохранены, а Leave не
происходит. Native не превращает unsupported read в false-result загрузчика
и не выполняет автоматическую очистку critical section. Последующие инструкции
такого аварийного пути и реальная Windows stack provenance остаются открытыми.

Fopen/read-close, translated `_read` bytes, malloc/DIB/COM, CRT thread/locks и
writer FILE flags102 сохраняют объявленные границы предыдущих исследований.
Writer stream создаётся на каждом реальном writer entry; `_write`/`_close` и
весь actual `fprintf`/`fclose` порядок сравниваются и внутри родителя. Сетевой
worker, конкурентное изменение globals, настоящая файловая трансляция и пиксели
не исполняются этим корпусом.

## Корпуса

Два прохода по133 случая: A5/прямые ранние ресурсы и ramp/обратные. Проверены
первый непрерывный вход, прочие статусы, signed version matrix, индексы,
оба отсутствующих/неверных/полных text inputs, сочетания missing/null/key/live
bitmap, строки даты, capacities1/7/4096, failed open/short write/close errors и
остановка без NUL. Все четыре children работают на общей памяти после реальных
вызовов родителя; границы каждого ребёнка фиксируются явно.

| Наблюдение на проход | Число |
| --- | ---: |
| Content / bitmap / defaults / cache calls | 166 / 59 / 65 / 125 |
| Завершённые child returns / pending content | 414 / 1 |
| Actual constructors / destructors | 47 / 46 |
| События родителя / children | 1 926 / 17 380 |
| Полные records / bytes и masks | 21 578 / 367 220 837 |

Проверяются ordered parent writes/calls/returns, все прежние child events и
их globals/local/FILE/buffer snapshots, полные retained bitmap generations,
World и ранние ресурсы после каждого случая. Native отдельно заново проверяет
свой свежий prefix/settings/front-resource parent. ABI children и root return
проверяются источником; native сверяет metadata реальных call/return sites.

```sh
uv run tools/oracle_menu_panel_update.py
uv run tools/oracle_menu_panel_update.py --control
uv run tools/oracle_menu_panel_update.py --accept
swift test --package-path native --filter 'Original(MenuPanelUpdate|FrontScreenPrelude)Tests'
swift build --package-path native -c release --product NTSDNative
```

Оба упакованных корпуса сравнены release CLI до принятия fixtures. Сохранены
SHA всех 31 прежних fixtures; для двух новых проверены raw/packed SHA и полная
распаковка. После добавления настраиваемых адресов child observers заново
воспроизведены оба прежних content и оба bitmap корпуса: все случаи и все blobs
совпали без изменений. Четыре XCTest (новый parent и прежний screen prefix)
прошли за 14.137 s, release NTSDNative собран за 2.39 s. Отчёты:
[основной](../evidence/menu-panel-update.json),
[контрольный](../evidence/menu-panel-update-control.json).

Далее — тело раннего экрана после`42712c`, альтернативы`4275cb`, затем соединение
с прежними main-menu/tail/loading ветвями. Новый результат не является готовым
оконным меню, полным тактом или матчем. R02.1, worker/WinMain, DirectDraw pixels,
Windows W и чистая macOS остаются открытыми.
