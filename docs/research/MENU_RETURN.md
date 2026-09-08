# Возврат из собственного экрана режимов

R02.1/R14/R15. Продолжение [MODE_SCREEN.md](MODE_SCREEN.md) после первого
431d10/ret16. EXE SHA-256:
`3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c`.
MSVCR80 8.0.50727.6195 SHA-256:
`c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d`.

Статус: оба свежих source corpus и их packed документы совпали с Native Core;
приняты два новых fixtures. Закрыт собственный первый возврат через все три
внешние функции и ограниченный набор последующих output caller probes.
Следующий полный внешний вызов, выбор участников и UI приложения ещё открыты.

## Цепочка первого возврата

Первый вызов продолжает собственный431d10 из раннего меню/loading/startup
на том же CPU, World и стеке. Перед ним заново проверяются все закреплённые
loading/startup документы и blobs, затем весь первый case MODE_SCREEN и его
referenced blobs. Последующие631 probes старого mode corpus source здесь не
исполняет; native parent всё ещё сравнивает весь632-case корпус после callback.

| PC / операция | ESP после возврата | FS:0 |
| --- | --- | --- |
|429eb7 →42e0d2..42e0f9/ret12 →4229e2 |1000e9bc |1000efb4 |
|4229e2..422a95: notice, overlay, present, timer |1000e9bc |1000efb4 |
|422a95..422ab8/ret4 →424746 |1000f000 |1000f418 |
|424746: held457580=0 →4287de |1000f000 |1000f418 |
|4287de..428805/ret4 →declared outer STOP |1000f42c |12345678 |

Реальный call429730 —4229dd, его return PC —4229e2. Frame41bc90 перед
аллокацией выравнивает ESP вниз по64; его исходный EBP сохраняется и
используется для возврата. Cookie и SEH проверяют исходные инструкции, а
стенд дополнительно проверяет ESP и четыре nonvolatile registers. Native
не исполняет x86 SEH, но сохраняет соответствующий порядок игровых операций.

После полного первого возврата остаётся собственное состояние. Более поздние
4229e2 вызовы — явные caller probes со SP1000e9bc и новыми declared inputs.
Они останавливаются **до**422a95 и не симулируют ещё один полноценный внешний
такт. Их FS/EBP не выдаются за восстановленный следующий caller. Очистка held
в этих probes не выполняется, поскольку до424746 они не дошли.

## Вывод после меню

Сетевая надпись4229e2..422a5c появляется только если signed44d058>0 и
Int8(44f1af)>0. При этом:

1. 415160 запрашивает fill794×550, color0, у глобальной поверхности455608.
2. 43f010 рисует frame0 исходного451178 в(230,221), colorKey=0, mirror=0,
   на455608, с настоящим clipping и COM Blt.
3. 401290 рисует исходную строку449158 `Waiting for opponent...` в(271,295),
   background652512, colorD8775A.
4. Только после text helper уменьшается44d058. Неуспех GetDC/GDI его не отменяет.

Далее всегда идёт4028a0 — прежний общий обработчик громкости и уведомлений,
затем43e940 с mode458348. Его проверенные правила описаны в
[MENU_PRESENTATION.md](MENU_PRESENTATION.md). При menu44d020==0 caller
обнуляет451158, вызывает timeGetTime и сохраняет UInt32 в451154. При другом
menu обе величины остаются прежними; чтение таймера не вставляется.

Только после ret4 из41bc90 caller424746 безусловно очищает held457580.
Он идёт сразу в ранний эпилог, а не в cursor/latch tail42873e. Поэтому здесь
нет дополнительного рисования, второго present или присваивания44d060.

## Общая реализация и границы

`OriginalMenuReturn.advance` выполняет новый caller вокруг прежних shared
fill/bitmap/text/overlay/present функций. Для4028a0 добавлен отдельный entry
`OriginalMenuPresentationEntry.overlay`; старые tail/worldOne последовательности
не менялись. Прежний private overlay не скопирован в новый набор правил.

`ModeScreenReference.onFirst` отдаёт собственные state/context/CRT/music/menu
resources после полного сравнения первого кадра. Новое продолжение работает
на этих значениях; полный старый mode corpus затем сравнивается на прежней
ветви значений. Source `after_first` — callback по умолчанию nil, не изменение
исходного632-case генератора. Ожидаемые после-снимки не инициализируют Core.

Каждый корпус содержит95 случаев: первый полный возврат,30 network
notice controls,14 menu/timer controls,8 present modes,20 overlay cases,
18 volume/key combinations и4 query/get HRESULT controls. Последние включают
Int32 overflow и исходный приоритет клавиш громкости. A5 и ramp/reverse варианты
сохраняют разные backing и физические Actor addresses.

Первоначальные45560c..45561c не загружены этим bounded WinMain-путём. Для
volume controls явно связываются первые пять собственных common WAV buffers
из451db0. Это не доказательство исходной установки этих пяти глобальных
слотов. Музыка сохраняет свои уже созданные COM tokens. Действительные
QueryInterface/get/set/release инструкции исполняются до объявленной COM-границы.

Сравниваются полные World/400 Actor/globals/context и все retained early
bitmap bytes/masks/liveness, CRT, события и helper ABI; на checkpoints также
проверяются полные globals. Fill FX сохраняет исходное stack backing и его
defined mask. Bitmap draw сохраняет raw surface binding. Общий DWORD count
bitmap не исправляется под размер картинки. Pixels/audio/latency, WinMain
device/file initialization и Windows остаются открытыми.

```
uv run tools/oracle_menu_return.py
uv run tools/oracle_menu_return.py --control
uv run tools/oracle_menu_return.py --accept
swift test --package-path native -c release --filter OriginalMenuReturnTests
swift build --package-path native -c release --product NTSDNative
```

SwiftPM запускается последовательно. Acceptance сравнивает оба packed документа
со всеми закреплёнными родителями до записи новых fixtures. Старые fixtures и
baseline assets не меняются.

На каждом проходе совпали193 checkpoints,571 event,293 helper returns,
82463 полных записи и148735152 bytes/masks нового участка после проверенных
родителей. Итого190 случаев,386 checkpoints,1142 события,586 helpers,
164926 records и297470304 bytes/masks. Source выполняет35 настоящих DLL
sprintf и2 timeGetTime на проход;6 сетевых надписей используют настоящий
bitmap/clip/Blt,22 music queries включают успех и ошибки query/get.

В первой диагностике native правила не менялись: GDI-наблюдатель, созданный
через __new__, не имел cache для чтения строки из PE. В новом observer ему
передан существующий cstr reader того же VM. После этого оба свежих source
прохода полностью повторили загрузку/startup/первый mode screen и95 новых
случаев. Ожидаемые после-снимки не исправлялись под Native Core.

Отчёты: [A5](../evidence/menu-return.json),
[control](../evidence/menu-return-control.json). Raw/packed размеры:
2626640/1106695 bytes и2639659/1179583 bytes. Все96 прежних fixture hashes
неизменны; SHA, размеры и полная распаковка обоих новых документов проверены.
Inventory содержит98 файлов в `build/research/menu-return-fixture-pins.json`.

Оба новых release XCTest прошли за25.434s; они также сравнивают полные прежние
mode/startup/loading/early native корпуса. Два прежних debug XCTest
OriginalFrontMenuCompletionTests прошли за8.532s. Release NTSDCatalogCheck
собран за83.08s, acceptance build за0.19s, NTSDNative за2.79s. Конфигурации
тестов различаются, объём проверок сохранён. Все source/SwiftPM/comparison
процессы завершились до сохранения этапа.

## Следующий участок

Выполнить следующий настоящий4246b0/World2→41bc90 на собственном состоянии
после первого полного возврата. Он должен сам пройти prologue/phase/input/
round/menu, включая phase0 control/network calls; не задавать phase1 или menu3
ради пропуска зависимостей. Затем общий ввод должен подтвердить VS и привести
к следующему menu3/1 character-selection entry. Выбор участников/арены,
подготовка выбранного матча, полный игровой такт и UI приложения ещё открыты.
