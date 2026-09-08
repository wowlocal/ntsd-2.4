# От раннего меню к первой загрузке

R02.1/R03.1/R15. Соединение [FRONT_MENU_LOOP.md](FRONT_MENU_LOOP.md) с
[INITIAL_LOADING.md](INITIAL_LOADING.md).
EXE SHA-256: `3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c`.
MSVCR80 8.0.50727.6195 SHA-256: `c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d`.

## Вопрос

Могут ли свежие World/resources/settings, повторные ранние меню и последующая
загрузка продолжаться на собственном состоянии без восстановления другого
World, замены globals, стека или готового каталога на границе41bc90?

## Соединённый путь

`oracle_menu_loading.py` заново выполняет весь ранний родитель и119 повторных
вызовов меню. Последние выбор матча/World1/World2 достигают настоящего
`424741 → 41bc90` с return address424746 и сохранённым targetSurface.
Загрузчик продолжает этот же CPU и World до41c581, включая общие звуки,
весь исходный каталог,400-slot pool и10 UI constructors.

| Граница | Данные нового вызова |
| --- | --- |
| World | Тот же raw address22000020 и маска конструктора/дальнейших записей |
| Caller | ESP1000eff8, return424746, argument28002020; внутренний loading prologue выравнивает стек самостоятельно |
| Globals/CRT | Собственное состояние после ret4 и реальной World1→2; новый seed, phase, checksum или settings не подставляются |
| Старые bitmap | Все ранние records и live/dead status сохраняются, включая освобождённый текущий фон и старый оставшийся wrapper |
| Новый каталог/Actor/UI | Реальные original parent/children и объявленные malloc/device responses, без восстановления ожидаемых snapshots |

Перед присоединением новых наблюдателей сохраняются весь стек, World/globals,
ранние bitmap records, CRT/replay pointers и CPU registers. После присоединения
проверяется полное равенство. Инициализация наблюдателей может выделять свои
области и привязывать platform imports; она не записывает игровые defaults.
Отдельные классические entry points инструментов сохраняют прежние значения
аргументов по умолчанию и прежние границы проверки.

## Устройства и память стенда

Graphics/audio device и поверхности представлены объявленными COM tokens до
первой загрузки ранних ресурсов. В этой цепочке44eecc,453e0c и455634 указывают
на28002020;458348 задаёт presentation1 в основном проходе и3 в контрольном.
Значения уже присутствуют во входах первого раннего родителя и сохраняются
до загрузчика. Создание настоящих Windows устройств здесь не выполнено.

Второй PCM segment использует2d000020. Прежний28000020 пересекается с ранней
bitmap arena, а2c000020 — с областью панели. Новая привязка выбирается на
границе Lock response, проходит через реальные memcpy и проверяется native.
Временный PCM и первый segment сохраняют прежние disjoint addresses.
Перенос служебной области не меняет исходных игровых данных или правил.

World получает canary bytes вне своего объявленного префикса до раннего
первого прохода. При присоединении его содержимое и маска не переписываются.
В раннем и загрузочном наблюдателях используется одна маска записей World.

## Настоящий MENU_WAIT

В41bea9 исполняется43f010 с реальным ранним MENU_WAIT45118c. Сохранены
43ef70, сырые чтения bitmap, оба возможных clipping paths, COM Blt, настоящий
ret24 и EAX. Уже проверенный native OriginalBitmapDrawing получает собственный
retained bitmap и raw surface binding. Count+0c остаётся нетронутым; различия
A5/ramp backing не обнуляются ради упрощения.

Наблюдатель общих WAV поддерживает необязательный callback для исполнения
этого drawing child. Старый отдельный WAV/loading корпус сохраняет свою
границу запроса bitmap. Реальный43e940 также использует прежнюю target surface;
его platform method events сравниваются в общей последовательности загрузки.

## Нативная композиция

`FrontMenuLoopReference.onLoading` передаёт собственные World/globals/CRT и
ownership memory после проверенного перехода. `InitialLoadingReference`
принимает эти записи через `initialState`, сверяет их с исходным before и
вызывает прежний `OriginalInitialLoading.load` на них. В этом пути нет нового
World constructor или явной записи selector2 в native.

Загрузчик по-прежнему строит OriginalLoadedCatalog, общие/зарегистрированные
звуки, bootstrap и UI через общие восстановленные механизмы. Новый reference
соединяет их проверки с настоящим drawing child и проверяет финальные globals,
тот же World и все старые bitmap. Указатели World→catalog/Actor нормализуются
только по объявленным bindings в принятую ordinal representation. Другие
неизвестные слова сохраняются буквально.

## Результаты D

Оба новых raw и затем оба packed набора прошли независимое native сравнение
до принятия fixtures. На каждом проверены
119 повторных ранних вызовов/547 фаз, затем полная первая загрузка до41c581.

| Показатель после входа41bc90 | A5 / present1 | Ramp / present3 |
| --- | ---: | ---: |
| Общие / зарегистрированные WAV |18 /400|18 /400|
| Objects / Frame occurrences |137 /15388|137 /15388|
| Actor / UI constructors |408 /10|408 /10|
| MENU_WAIT calls / raw bitmap reads |1 /5|1 /10|
| Clips / Blt / graphics helper returns |1 /1 /2|2 /2 /3|
| Retained records / bytes+masks |28 /256568|28 /256568|
| Loading records / bytes+masks |930 /3152264|930 /3152264|
| Registry audio bytes+masks |66210142|66210142|
| Catalog bytes+masks |112063739|112063739|
| Checksum |31475378|31475378|

Итого после меню сравниваются363365426 bytes/masks. Предшествующие меню имеют
свою полную проверку; эта сумма их объём не включает. Сохранены26 ранних bitmap
records, из них один dead, плюс World/globals. Десять новых UI bitmap принадлежат
результату OriginalInitialLoading и проверяются отдельно от старых wrappers.

Исторический основной initial-loading/catalog/sounds корпус заново выполнен
и совпал по всем трём JSON documents и каждому blob. Первый запуск сравнения
выявил только разницу Python tuples/JSON arrays в globalWrites; после приведения
к транспортному представлению полное повторное исполнение совпало. Также точно
воспроизведены431 прежний WAV case,3 initial sound passes и все их blobs.

Четыре прежних native XCTest прошли за175.906с: loop7.691с и оба исторических
initial-loading168.215с. [Основной отчёт](../evidence/menu-loading.json) и
[контроль](../evidence/menu-loading-control.json) закрепляют отдельные
menu/state/catalog/sounds captures и восемь lossless fixtures.

Новые два сквозных XCTest прошли за168.500с. Вместе с четырьмя прежними —
шесть тестов за344.406с без ошибок. Все82 прежних fixture hashes неизменны;
проверены raw/packed SHA, размеры и полная распаковка всех восьми новых файлов,
включая заявленную фильтрацию транспортного catalog JSON. Новый inventory
содержит90 файлов: `build/research/menu-loading-fixture-pins.json`.
Release-сборка `NTSDNative` завершилась успешно за0.17с. Активных SwiftPM
или source-capture процессов перед фиксацией этапа не осталось.

## Воспроизведение

```
uv run tools/oracle_menu_loading.py
uv run tools/oracle_menu_loading.py --control
swift build --package-path native -c release --product NTSDCatalogCheck
native/.build/release/NTSDCatalogCheck --menu-loading build/original/menu-loading.json build/original/menu-loading-state.json build/original/menu-loading-catalog.json build/original/menu-loading-sounds.json
native/.build/release/NTSDCatalogCheck --menu-loading build/original/menu-loading-control.json build/original/menu-loading-state-control.json build/original/menu-loading-catalog-control.json build/original/menu-loading-sounds-control.json
uv run tools/oracle_menu_loading.py --accept
swift test --package-path native --filter 'OriginalMenuLoadingTests'
swift test --package-path native --filter 'Original(InitialLoading|FrontMenuLoop)Tests'
swift build --package-path native -c release --product NTSDNative
```

SwiftPM выполняется последовательно. После изменения shared observers старые
raw captures сравниваются по полным JSON documents и всем blobs; JSON массивы
и Python tuples приводятся к одному транспортному представлению перед проверкой.

## Открытые границы

41c581 ещё требует продолжения уже существующими input/round/menu обработчиками
на этом же состоянии. Полный ret4 из41bc90 и последующая очистка held в424746
здесь не объявляются выполненными. Timer100/PeekMessage0 сохраняют прежний
no-draw loading-progress domain; animated4242e0 остаётся открытым.

Ресурсы/настройки/ранние rand используют прежнюю привязку actual VC80 к CPU.
Каталог сохраняет свою явно объявленную stdio/scanner границу: scanf проверяется
исполнением DLL в отдельном CRT scanner VM. Это не полное Windows CRT/file IO.
COM остаётся границей запросов, без raster/mixing/device latency. Worker,
остальные selectors, app integration, полный матч и Windows W не закрыты.
