# R02.1/R13/R15 — первый рисунок раннего экрана

Эталон — EXE SHA-256
`3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c`;
VC80 DLL `c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d`.
Первый вход теперь непрерывно проходит World constructor → 24 ранних ресурса →
настройки → `42709b` → первый настоящий bitmap caller `42710f` и выбор следующей
ветви. Источник и DLL работают на том же CPU/стеке. Native продолжает собственные
World/globals/resources после независимых `FrontMenuResourcesReference` и
`SettingsLoadingReference`; ожидаемые после-снимки родителя не становятся входом.

Выполнены `4237e0`, `43c450`, `415160`, `423840`, `43ee50`, `43f010`, `43ef70`.
Конечные границы — **до call `4236d0` в `427127`** либо до альтернативного экрана
в `4275cb`. Это первый рисунок и выбор ветви, а не весь начальный экран.

## Выбор экрана и запрос потока

Если `44d064 != -2`, значение не меняется. Иначе:

- `450be8 == -1` задаёт `44d064 = -3`;
- прочие значения задают `44d064 = 0`;
- только `450be8 == 1` дополнительно вызывает `4237e0`.

`4237e0` переходит в `43c450`, если `44d788 == -99`, либо первые четыре байта
`4527b0` равны `now\0`, либо C-строка `4527b0` лексикографически не больше
`451d48`. Сравнение побайтное без знака, включая старшие байты. Других записей
в globals этот gate не делает.

`43c450` вызывает EnterCriticalSection(`4554a4`), читает `458424`, затем
LeaveCriticalSection с тем же адресом. Если прочитанное значение ненулевое,
поток не запрашивается. При нуле CreateThread получает start=`43c240`, attributes,
stack size, argument и flags — нулевые; последний параметр указывает на локальный
thread ID. Если возвращённый handle нулевой, вызывается GetLastError.
Возвращённые handle/ID/error — явные платформенные ответы. Тело worker `43c240`
и его одновременные изменения globals этим корпусом не исполняются.

## Заливка `415160`

Caller всегда передаёт `(x:0, y:0, width:794, height:550, color:10206c)`.
Устройство берётся из global `455608`; это отдельная привязка от последующего
bitmap target, полученного в аргументе внешнего caller.

Общий `OriginalSurfaceFilling` вычисляет right/bottom с Int32 wrap и формирует
Blt с null source/sourceRect, flags=`01000400`. В100-байтном DDBLTFX исходник
записывает **только** size=100 в `+0` и цвет в `+50`. Остальные92 байта сохраняют
входной stack backing. Сравниваются все100 байт и маска двух четырёхбайтных
записей. Fill backing объявлен входом на границе helper до его инструкций;
полное происхождение Windows stack не подразумевается. Это не обнулённый FX,
используемый другим helper для зеркального рисунка.

HRESULT заливки не влияет на продолжение caller. При null global target
источник останавливается перед `4151b6`, native возвращает `.nullFillTarget`
с уже выполненными изменениями selector/порядком запросов.

## Фон `423840`

Загрузчик вызывается только при `4511ac == 0`. Он читает timeGetTime как UInt32,
выбирает `milliseconds % 13 + 1` и вызывает настоящий VC80 sprintf (`7817775d`)
с `MENU_BACK%d`. Проверены все13 оригинальных PE DIB, каждый809×547.
Это отдельный источник случайного выбора: игровой RNG здесь не вызывается.

Сначала на стеке создаётся14-байтный `MENU_BACK0000\0`, затем sprintf заменяет
только свой текст и NUL. Остаток исходного буфера сохраняется. Native сравнивает
все14 байт, исходный формат, аргумент и возвращённую длину.

Далее malloc(`1f50`), при успехе настоящий общий `43ee50` с flags=`40`, optional=0;
результат wrapper записывается в `4511ac`, включая null. Count и прямоугольники
не инициализируются. При повторном занулении global прежние wrappers **не**
освобождаются, и все их bytes/masks остаются в реестре. Missing surface и
SetColorKey failure используют прежний общий bitmap constructor.

Ненулевой `4511ac` пропускает timer/format/allocation целиком. Текущее исследование
проверяет повторное использование фонов, созданных именно этим loader; чужой
необъявленный wrapper token не превращается в допустимый нативный указатель.

## Настоящий bitmap caller

`42710f` передаёт `x=0`, `y=453da4` при selector0, иначе `y=0`, `frame=-1`,
colorKey=1, mirror=0, target из аргумента внешнего caller. Исполняются целые
`43f010/43ef70` до реального ret24. Native использует уже проверенный общий
`OriginalBitmapDrawing`, включая исходный fallthrough после целой картинки.

Count/rectangles после конструктора нетронуты. Поэтому A5 и ramp дают разный
набор дополнительных reads/clips/Blt. Входной backing не заменяется нулями,
чтения не присваивают defined=true. Известное surface word восстанавливает raw
token до арифметики по прежним правилам drawing helper. Все обращения к bitmap,
обрезки и Blt сравниваются по порядку; HRESULT не отменяет следующий рисунок.

Null wrapper останавливается до `43f04b`, null target — до его разыменования
в `43f12b/43f2e6`. Native сохраняет выполненные до границы операции. Нулевая
страница стенда служит SEH и не делает такой доступ допустимым.

## Корпуса и проверка

Два свежих прохода по178 случаев: первый реальный вход, комбинации selector и
настройки, все13 timer residues и UInt32 boundaries, worker gates/строки/статусы,
failed thread, y/viewport boundaries, failed fill, missing surface/ключ, null
allocation/targets и повторное использование фона. Поздние входы `42709b` явно
предоставляют caller registers/stack position и продолжают свои globals/heap;
это не полные итерации начального меню.

| Сравнение | A5/прямое размещение | Ramp/обратное размещение |
| --- | ---: | ---: |
| Реальные helper returns | 707 | 882 |
| Упорядоченные события | 1 972 | 3 171 |
| Заливки / bitmap calls | 177 / 177 | 177 / 177 |
| Bitmap reads / undefined | 859 / 361 | 1 721 / 1 061 |
| Clip returns / Blt | 176 / 156 | 351 / 318 |
| Новые конструкторы / actual sprintf | 32 / 33 | 32 / 33 |
| CreateThread / GetLastError | 13 / 6 | 13 / 6 |
| Invalid-access boundaries | 3 | 3 |
| Полные записи / bytes и masks | 7 491 / 65 803 344 | 7 491 / 65 803 344 |

Полные World/globals и все текущие/старые bitmap records сравниваются после
каждого случая; constructor masks и все fill FX проверены. Отдельно сравнивается
нативный предшественник с настоящими24 конструкторами и чтением исходного
`control.txt`. Device surface binding `455608` задан перед первым ранним parent;
настоящий WinMain/DirectDraw initialization ещё не восстановлен.

Оба release-сравнения прошли до принятия
[основного](../evidence/front-screen-prelude.json) и
[контрольного](../evidence/front-screen-prelude-control.json) fixtures.
Все23 прежних fixture hashes неизменны. SHA новых raw/packed корпусов и полное
обратное распаковывание проверены. Добавленный source hook для device binding
по умолчанию ничего не меняет: оба старых94-case settings корпуса воспроизведены
заново и совпали **целиком, включая все blobs**. Native settings comparator
получил только необязательный callback собственного первого проверенного состояния.

```sh
uv run tools/oracle_front_screen_prelude.py
uv run tools/oracle_front_screen_prelude.py --control
uv run tools/oracle_front_screen_prelude.py --accept
swift test --package-path native --filter 'Original(FrontScreenPrelude|SettingsLoading|BitmapDrawing)Tests'
swift build --package-path native -c release --product NTSDNative
```

Пять targeted XCTest (два новых prefix, два прежних settings и bitmap drawing)
прошли за14.095 s; новые prefix отдельно —2.474 s. Release NTSDNative собран
за2.25 s. Окно приложения и графическое устройство этим не проверены.

SwiftPM выполняется последовательно. Следом — настоящий `4236d0` и тело экрана
после `427127`, альтернативы `4275cb` и дальнейшее соединение с ранее проверенными
main-menu/tail/loading ветвями. Worker lifecycle, пиксели DirectDraw, оконный UI,
практика/законченный матч, Windows и чистая macOS остаются открытыми.

[APPLICATION_FRONT_SCREEN](APPLICATION_FRONT_SCREEN.md) now continues the own
WinMain/loop/settings parents through this prefix, executing the whole background
image loader/copy and keeping92 private fill bytes unknown in Native. It reaches
427127/4275cb and preserves cached Sleep; this earlier supplied-boundary corpus
remains unchanged. Full World/dispatcher and Windows/device checks stay open.
