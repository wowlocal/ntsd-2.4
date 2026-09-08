# Повторные вызовы раннего меню

R02.1/R15, продолжение [FRONT_MENU_COMPLETION.md](FRONT_MENU_COMPLETION.md).
EXE SHA-256: `3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c`.
MSVCR80 8.0.50727.6195 SHA-256: `c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d`.

## Граница новой композиции

Свежий родитель заново исполняет конструктор World,24 ранних UI wrappers,
загрузку исходного control.txt, первый prefix/body/alternate, главное меню и
tail до настоящего ret4. Следующие вызовы начинают с4246b0. Каждый заново
исполняет настоящий пролог, выбирает ветвь по собственному World и проходит
через сохранившиеся ресурсы и globals. Внутри вызова нет заданных EAX selector,
подмены caller registers или переноса прямо на позднее меню.

Наблюдатель переключается на известных границах prefix/update/body/alternate/
completion, сохраняя CPU, память, SP и регистры. До возобновления проверяется,
что текущий PC совпадает с настоящим входом следующей фазы. В старых helper
обёртках используются варианты без восстановления регистров. Только внешний
ABI каждого нового4246b0 задан явно: ECX=World, аргумент target, return address,
четыре nonvolatile registers и предыдущее SEH. Это не WinMain/message loop.

Проверки мыши, фонового worker status, timer/COM/FILE responses и несколько
контрольных globals являются объявленными стимулами. Они не выдаются за
выполнение Windows message handling или worker thread. Между вызовами не
подставляются ожидаемые snapshots, начальный seed, previous click или World.

## Нативный обработчик

`OriginalFrontMenuLoop.run` соединяет общие восстановленные механизмы через
callbacks. Порядок их вызовов определяется текущими нативными World/globals.
Reference проверяет этот порядок против записи EXE; список ожидаемых фаз
не используется как инструкция, какие нативные функции запустить.

| Исходная ветвь | Продолжение |
| --- | --- |
| World1, `424703` | Общие release/background, MENU_WAIT, World2, overlay/present и полный возврат |
| World2, `424741` | Настоящий вызов41bc90; здесь остановка на его входе |
| Остальные World, `424755..424774` | DWORD phase=`1−4511f8` с переполнением; flag0 пропускает повторное создание ранних ресурсов |
| `42709b..427127/4275cb` | Prefix рисует фон и определяет, нужен ли updater/body |
| `427127..4275cb` | Настоящий4236d0, затем тело раннего экрана; клик может изменить selector до альтернативного dispatch |
| `4275cb..427915/42873e` | Общий выбор settings/waiting/main; main продолжает tail, settings/waiting сразу tail |
| `42873e..428805` | Cursor, overlay/present, previous click и ret4 |

Ресурсы наследуются от собственных нативных конструкторов первого прохода.
`OriginalFrontScreenPrelude` принимает уже принадлежащие ему background
records и raw surface bindings. Остальные ранние bitmap хранятся в общей
ownership memory. Новая конструкция фона добавляет запись туда же; World1
освобождает текущий фон, сохраняя его dead bytes/masks. Изменение известного
surface word в canonical1/0 делается только на границе drawing API, как в
предыдущем исследовании.

## Проверяемые последовательности

На каждом из двух allocator backing выполняются119 внешних вызовов:

- Простой redraw, открытие настроек, отпускание кнопки, раскрытие описания,
  32 последовательных анимационных прохода, выключение и повторное включение.
- Четыре прохода с worker status1 и возвращение к status0; enable с ошибкой
  CreateThread и повторные initial selector−2 для разных значений настройки.
- Waiting screen,30 unsigned timer steps через UInt32 wrap, отмена ожидания
  и следующий главный экран.
- Четыре наведения на network row без клика: настоящие3000 rand на каждое,
  с сохранённым состоянием CRT между внешними вызовами.
- Шесть крайних значений4511f8. Это арифметика DWORD, а не переключение Bool.
- Объявленное обнуление4511ac и новая MENU_BACK13 вместо первоначальной
  MENU_BACK1. Старый wrapper не освобождается этой ветвью и остаётся live.
- Три исходные ссылки и последующие отпускания кнопки.
- Null FILE при сохранении, отдельный следующий внешний вызов и повторный
  запрос сохранения; ошибка descriptor write с продолжающимся fclose.
- Явные selectors1/6/7 до427ca7, затем выбор матча из главного меню,
  полный World1→2 и следующий World2 до реального входа41bc90.

После null FILE нет доказательства обработки исключения или продолжения того
же Windows вызова: трасса остановлена до разыменования423260. Следующий probe
задаёт новый внешний ABI и сохраняет частичное игровое состояние. Аналогично
остановки на прочих selectors не означают возврата этих экранов.

## Сравниваемое состояние

После каждой фазы проверяются все globals, World, полные bitmap records и
маски, события и helper ABI. После main-menu и каждого возврата дополнительно
проверяются CRT state и replay pointers. Actual VC80 rand сверяется по каждому
result/before/after. Settings writing исполняет настоящий DLL fprintf/fclose;
native сравнивает FILE, буфер, globals и порядок событий на каждой границе.

Перед body сохраняются192 raw stack bytes как объявленный вход scratch.
Маска наблюдения начинает этот участок пустой; body проверяет все bytes/masks
после своих записей. При непосредственном продолжении alternate проверяется
сохранение этого local record. Scratch в проходах без body, main-menu и overlay
не объявляется полностью нативно восстановленным. Fill получает100 bytes
backing до своего вызова и сохраняет92 нетронутых байта. Это явные границы
происхождения памяти, не доказательство Windows heap/stack initialization.

## Результаты D

Оба raw и затем оба packed корпуса совпали до принятия fixtures:
[основной отчёт](../evidence/front-menu-loop.json) и
[control](../evidence/front-menu-loop-control.json).

| Показатель | A5 | Ramp |
| --- | ---: | ---: |
| Внешние вызовы / проверенные фазы |119 /547|119 /547|
| Ret4 / other selectors / null FILE / loading entry |114 /3 /1 /1|114 /3 /1 /1|
| Body / main-menu / tail / World1 |41 /37 /113 /1|41 /37 /113 /1|
| Helper returns / события |1857 /11667|2088 /13284|
| Bitmap calls / raw reads |565 /3471|565 /4626|
| Clips / Blt / fills |565 /543 /305|796 /774 /305|
| Конструкция нового фона / освобождение текущего |1 /1|1 /1|
| Таблицы RNG / actual DLL rand |5 /15000|5 /15000|
| Settings calls / returns / writer events |5 /4 /262|5 /4 /262|
| Fprintf / descriptor writes / failed writes |216 /33 /1|216 /33 /1|
| Полные records / bytes+masks |20029 /188449860|20029 /188449860|

Итого238 вызовов/1094 фаз,228 возвратов,3945 helper returns/24951 событий,
1130 bitmap calls/8097 raw reads,1361 clips/1317 Blt/610 fills,
10 RNG tables/30000 actual rand,40058 records/376899720 bytes+masks.
Разное число clips/Blt сохраняет исходные untouched count поля cursor/wait
и зависимость от allocator backing, описанную в предыдущем исследовании.

Все80 прежних fixture hashes неизменны. Проверены SHA обоих raw/packed,
размеры и полная обратная распаковка. Новый inventory содержит82 файла:
`build/research/front-menu-loop-fixture-pins.json`. Первое native сравнение
обоих raw прошло без исправления восстановленных правил или expected snapshots.

Шесть целевых XCTest прошли за17.337с: новый loop7.122с, исторический
completion7.552с, исторический prefix2.663с. Release NTSDNative собран за2.48с.
Сборки, сравнения и тесты завершились до коммита; SwiftPM выполнялся строго
последовательно. Проверенный объём оконного Practice этим этапом не расширен.

## Воспроизведение

```
uv run tools/oracle_front_menu_loop.py
uv run tools/oracle_front_menu_loop.py --control
swift build --package-path native -c release --product NTSDCatalogCheck
native/.build/release/NTSDCatalogCheck --front-menu-loop build/original/front-menu-loop.json
native/.build/release/NTSDCatalogCheck --front-menu-loop build/original/front-menu-loop-control.json
uv run tools/oracle_front_menu_loop.py --accept
swift test --package-path native --filter 'Original(FrontMenuLoop|FrontMenuCompletion|FrontScreenPrelude)Tests'
swift build --package-path native -c release --product NTSDNative
```

SwiftPM-команды выполняются последовательно. Fixtures принимаются только
после успешного native сравнения; предыдущие fixtures сохраняют свои hashes.

## Что остаётся

Далее соединить полученный World2 и живые ранние ресурсы с настоящим41bc90,
используя уже восстановленную цепочку loading/catalog/input. Весь41bc90 здесь
не выполнен; очистка457580 в424746 происходит только после его возврата.

Worker body/concurrency, status2 с panel children в повторных вызовах, enabled
optional panel, остальные selectors, полный startup/CRT lifetime, Windows
message handling и фактический вывод пикселей/звука остаются открытыми. Новая
композиция пока вне оконного Practice. R02.1/R01.2 и цель полной игры не закрыты.
