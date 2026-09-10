# Адресный справочник оригинального EXE

Связанная очередь: [RESEARCH_MAP.md](../RESEARCH_MAP.md).
Эталон: `NTSD 2.4_2.0a/NTSD 2.4.exe`, SHA-256
`3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c`.
Исходный срез справочника: 2026-09-07, нативный код `a9f2cfe`.

Это начальный индекс уже обнаруженных участков, **не полный перечень функций**.
Названия ниже — наши описания назначения, не восстановленные имена из исходников.
Адреса — VA при image base `0x400000`; диапазон фрагмента не объявляет границу
функции. IAT-ячейка и поле данных не являются адресом исполняемого обработчика.
Файловое смещение следует получать через секции PE, не вычитанием base вслепую.

## Функции и фрагменты

D означает проверку ограниченного поведения функцией из оригинального EXE.
Даже если вызывается функция целиком, D не покрывает все её возможные ветви.

| Блок | VA / вид адреса | Обнаруженное назначение | Основание и граница |
| --- | --- | --- | --- |
| R01/R02/R15 | `421a2d..421cdc`, весь caller | Диагностика, exit/function-key notices; реальные VC80/401290/415160/43f010/43ef70 | D+Native: [POSTHUD_NOTICES](POSTHUD_NOTICES.md),819 прямых совпадений +8 явно отличающихся sNaN/Unicorn случаев с QNaN-парами;4 cookie-overwrite отклонены.195/198callerPC; оба own продолжены в GAMEPLAY_NOTICES, Windows открыт |
| R02/R15 | `421a2d..421cdc`, собственный caller | Продолжение обоих инициализированных HUD, исходные flags и неиспользованный локальный буфер | D [GAMEPLAY_NOTICES](GAMEPLAY_NOTICES.md):каждый481245records/806849858bytes+masks/61state/1604FPU;536/544helpers.10 actualPC+stop, нет новых events/local access; own backing остаётся nil. Полный возврат/W открыты |
| R02/R15/R16 | `421cdc..422218`; целая `43dd60..43def8`; `43f4b0..43f4cb`, `43f400..43f49e` | Запись результатов, сжатие1.1.4 всего повтора, изменение префикса ключом, stream write и освобождение | S [RESULT_RECORDING_PLAN](RESULT_RECORDING_PLAN.md):296caller/117writer; собственный stageDefeated найден, lifetime ещё проверять. Компрессор D ниже; whole writer/caller ещё открыты |
| R02/R16 | `43f4b0..43f4cb`, `43f400..43f49e`, полные wrappers с настоящими children | Сжатие буфера повтора, статусы/частичный выход и allocator failures | D [REPLAY_COMPRESSION](REPLAY_COMPRESSION.md):815 calls/31390143bytes+masks/11388helper returns,51+11wrapperPC и3208EXEPC. REP masks/неполные memory hooks и privateABI5816/5920 отмечены отдельно; whole writer/own/Windows открыты |
| R02/R16 | EXE IAT`4470d8/dc/e0/e4` → MSVCP`7c43a26c/7c4442e2/7c43f756/7c4336dc` | Исходная последовательностьofstream и фактическая буферизация CRT | D [REPLAY_STREAM](REPLAY_STREAM.md):66sequences/330returns,1772writes/6664690bytes совпали с Native;1626MSVCP+1324CRT actualPC. Declared open/descriptor/allocator/thread, отдельная privateABI; whole43dd60/own/W открыты |
| R00 | `0x445560`, PE entry | Точка входа бинарника | [PE-инвентаризация](../ORIGINAL_ENGINE.md); не вход игрового такта |
| R00/R03 | `0x4148a0`, функция | Расшифровка DAT | D: [oracle_dat.py](../../tools/oracle_dat.py), четыре исходных файла |
| R01 | `0x43d157..0x43d1df`, фрагмент | Ветви таймера, вызов диспетчера, ожидание | D: [oracle_presentation.py](../../tools/oracle_presentation.py), нормальная ветвь; вызов диспетчера заменён счётчиком |
| R01/R17 | `0x43cf40..0x43d21f`, функция | Внешний цикл, сообщения Windows и время | S: два возврата; D участка `43d157..43d1ef` с исполняемым диспетчером в новой трассе R01.1 |
| R01/R15 | `0x43e9a0`, вход; `0x43ed01`, ret | Верхний диспетчер с загрузкой и развилками | S + D обычного пути: [TICK_PIPELINE.md](TICK_PIPELINE.md), синтетическая загрузка и явные границы ОС |
| R01/R15 | `0x43eca1 → 0x4151d0`, `0x43ecba → 0x4246b0`, `0x43ecd3 → 0x414b70`, call sites | Вызовы из ветвей верхнего диспетчера | При `4593a0=0`: `4246b0(ECX=458b00)`, при World[0]=2 — `41bc90`; обычный путь S/D, остальные режимы не закрыты |
| R01 | `0x41bc90..0x422ab8`, функция, ret 4 | Обработчик матча вместе с вводом, графикой, HUD и звуком | S: 6 822 инструкции, один обычный возврат; D: 29 вызовов на синтетических данных, включая паузу; не эквивалентность Swift |
| R02/R03/R06 | `0x41bff0`, `0x41c013`, `0x41c070..0x41c091` | Аллокация каталога 0x4d823a8, загрузка `4122f0`, Actor по 0x420 байт | S; полная инициализация остаётся R02.1/R03.1 |
| R02/R06 | `0x41c052..0x41c2f5`, фрагмент | Загрузочный пул: 400 Actor, повторный конструктор/активация 0–7, первая запись каталога | D против Swift по полным записям/маскам: [BOOTSTRAP.md](BOOTSTRAP.md); не появление выбранных игроков |
| R02/R14 | `0x4014e0..0x40195e`, ret4; failure boundary `0x40187a` | Общий WAV loader: MMIO caller, PCM/format/descriptor, Lock/Restore/copy/free | D против Swift: [WAVE_LOADING.md](WAVE_LOADING.md),409 файлов/431 случаев; MMIO/COM responses supplied, invalid create continuation явно ограничена |
| R03/R14 | `0x41097b..0x410a99`, `0x40bd90..0x40be68`; calls `0x410a48/0x40be18` | Frame/weapon cache, назначение index, WAV, SetVolume(-10000), copy/count | D в полном каталоге с enabled audio: [CATALOG_SOUNDS.md](CATALOG_SOUNDS.md),400 source +29 interleaved calls, whole PCM/catalog/cache/ABI; COM/MMIO boundaries; caller null-dereference paths410a5a/40be2a ещё S |
| R02/R14 | `0x41be98..0x41bfeb`, фрагмент | Draw, очистка двух массивов,18 общих WAV, count18 и43e940 | D против Swift:3 прохода/54 настоящих child calls; globals после каждого ret4, first-load flag остаётся1; полный prologue/каталог/пул здесь не исполняются |
| R02/R15 | malloc `0x41c2f5..0x41c538`, constructors `0x41c31b..0x41c55e`, clear `0x41c577` |10 UI bitmap после пула, затем44d05c=0 | D против Swift: [INITIAL_INTERFACE.md](INITIAL_INTERFACE.md),13 проходов/114 constructors после реального пула; null malloc/device/key errors не отменяют сброс; catalog[0]/outer frame supplied |
| R13/R15 | `0x43ee50..0x43ef41`, ret12 | Bitmap constructor, required-resource errors, SetColorKey и Release при отрицательном HRESULT | D полного caller/storage/events/ABI;43ed10/COM/MessageBox/OutputDebugString boundaries, original embedded DIB dimensions; это не готовые пиксели |
| R02/R15 | `0x4229d0/0x4229d5/0x4229dd`, call site | `429730` получает mode pointer 451160 и menu pointer 44d020; World передаётся как this | S аргументов, D их использования в [MATCH_PRELUDE.md](MATCH_PRELUDE.md); выбор/ввод меню ещё supplied |
| R02/R15/R16 | `0x42cf8a..0x42d1ff`, фрагмент | Пролог запуска: Stage-сбросы, имя повтора, звук подтверждения/очистка | D против Swift: [MATCH_PRELUDE.md](MATCH_PRELUDE.md), 50 цепочек до42d704 с реальным sprintf; время/устройства заданы границей |
| R02/R15 | `0x42d704..0x42e0f9`, продолжение через ret12 | Команды меню, общий random roster и ветвь 450c2c==1 | D против Swift: [MATCH_CONTINUATION.md](MATCH_CONTINUATION.md), 222 возврата и полный state/candidate/call order; исходный SEH/cookie/ret исполнен с заданным ABI frame |
| R02 | `0x422ac0..0x422af7`; callers `0x427a2c/0x427a71`; prefix `0x43cf40..0x43cf63` | 3000 bytes RNG через настоящий CRT rand, нулевой хвост; seed из timeGetTime | D против Swift: [RANDOM_INITIALIZATION.md](RANDOM_INITIALIZATION.md), 50 таблиц в цепочке подготовки/записи, 176178 CRT draws; timer/thread/intervening draws supplied, полный menu path открыт |
| R02/CRT | DLL `0x78132d1a`, `0x7816d5e3..0x7816d611` | PTD+14 initial1, srand UInt32, rand UInt32 wrap/shift/mask | D actual MSVCR80 .6195 против Swift; thread binding — явная граница, Windows assembly binding не доказан |
| R02/R15/R17 | `0x43b3d0`, `0x43b8af..0x43b91f`, `0x43bc24..0x43bc3e` | WndProc для mouse200..205, globals и DefWindowProc/ret16 | D против Swift: [MAIN_MENU.md](MAIN_MENU.md),450 сообщений; unsigned16 координаты, только button flags для201/202/204/205; OS return supplied |
| R02/R17 | `0x43b3d0..0x43bc3e/ret16`, message401; `0x402ec0..0x40316e` | ACCEPT8, однократный recv77, send14/77/3001, live names/seats; READ1/CONNECT16/CLOSE32 только MessageBox | D+Native [NETWORK_NOTIFICATION](NETWORK_NOTIFICATION.md):415 callbacks/3692 requests/1119304 sendbytes,181/182 helper starts и37CRT; cookie checks неизменны. Общий inventory574/576WndProc; socket/stack/API заданы, client/peer/Windows открыты |
| R02/R15/R16 | `0x428420..0x42873e`, error continuation `0x4287de`; prologue `0x4246b0..0x424774` | Отложенное подключение: socket/lookup/connect, greeting14, send77/recv77/recv3001, live names/seats/RNG | D+Native [NETWORK_CLIENT](NETWORK_CLIENT.md):392 actions+2 paired calls/4 own packets,193/195 client starts (2 alignment absent), raw/packed10 tests. Пролог34 PC, EBP19; промежуточный UI и полный ret4 не исполнены, TCP/Windows открыты |
| R02/R15/R16 | `0x402d70..0x402eb6`, caller `0x427f6b` | Выход: sendto20..24 bytes, exact-1 early close без clear/cleanup; иначе listener close→clear2globals→WSACleanup | D+Native [NETWORK_EXIT](NETWORK_EXIT.md):56 whole returns/79 starts,56 cookie checks, own client producer→2 exits;14 raw/packed tests. Enclosing cancel UI/Windows остаются открытыми |
| R02/R15/R16 | `0x427ca7..0x42873e/0x4287de` | Whole network choice/host/client UI, hostname300-key scan, deferred client, real output/epilogue | D+Native [NETWORK_MENU](NETWORK_MENU.md):1944 whole UI matches,3 explicit own partial-read rejections;2×944 caller starts plus enabled sound. Actual World1→2→41bc90 boundary, runtime/listener/device/Windows remain open |
| R02/R14/R17 | `0x401970..0x4019a8/ret`; caller `0x43d08e..0x43d100` | Device creation/cooperative level and five initial menu WAV buffers45560c..45561c | D+Native [MENU_SOUND_STARTUP](MENU_SOUND_STARTUP.md):112 whole segments/560 WAV returns,10 separate stopped-create rejections;392 actual starts, full globals/store order/PCM/ownership. Explicit earlier state; full WinMain/menu/device/Windows join open |
| R02/R04/R14/R17 | `0x43bf10..0x43c0ba/ret`; caller `0x43d078..0x43d100` | Initial256 key bytes, four joystick records, two probes/calibration/capture, then shared menu sound | D+Native [INPUT_STARTUP](INPUT_STARTUP.md):56 whole segments+4 unknown-capability rejections,1900 own WndProc consumers; all32caller/127initializer starts. Shared caps provenance preserved; earlier WinMain/runtime/device/Windows open |
| R02/R15/R16 | `0x422f60..0x423222/ret`, caller `0x42836b/0x428371` | Character AL, exact Shift100, signed Caps low16, повторные GetKeyState20, keypad/navigation digits | D+Native [MENU_CHARACTER](MENU_CHARACTER.md):10492 whole calls/11048 reads/2890 requests,305/318 starts;13 duplicate-letter starts статически недостижимы. Native AL only; hostname loop и keyboard/Windows открыты |
| R02/R14/R17 | `0x43b3d0..0x43bc3e/ret16`, message400; `0x401e90..0x401f20` | Полная очередь GetEvent: только E_ABORT завершает, event1 seek+0, затем FreeEventParams и DefWindowProc | D+Native [GRAPH_EVENTS](GRAPH_EVENTS.md):371 callbacks/211 seeks,57/57 helper starts; вместе с input/lifecycle568/576 WndProc. Local+34/code,+3c/param1,+38/param2 сохраняются; Windows/device/reentrancy открыты |
| R02/R14 | `0x401c90..0x401d26`, полная функция | Graph creation, control/event/position QueryInterface, уведомление400 и flags0, очистка byte44ef04 | D+Native [GRAPH_EVENTS](GRAPH_EVENTS.md):4 init/49 starts,5 own callbacks от собственного zero-slot producer. Общая реализация MUSIC_PLAYBACK; HWND и COM responses объявлены, полного WinMain/playing-file join нет |
| R02/R13/R15/R17 | `0x43b3d0..0x43bc3e/ret16`, сообщения2/3/5/1c/20/105/112/30f/311 | Целые lifecycle callbacks: move/size/cursor/palette, смена режима и закрытие | D+Native [WINDOW_LIFECYCLE](WINDOW_LIFECYCLE.md):318 callbacks+2 init,18 own retained,3624 requests/1757 stores.185 WndProc PC; вместе с WINDOW_INPUT567/576. Actual delivery/reentrancy/Windows открыты |
| R02/R13 | `0x401a80..0x401ad6`, `0x401ae0..0x401af5`, `0x43bdd0..0x43beb9`; caller `0x43b83f..0x43b8aa` | Back→primary→draw release/clear, DestroyWindow, полное повторное создание между stores458434=1/0 | D+Native [WINDOW_LIFECYCLE](WINDOW_LIFECYCLE.md):140 release/recreate chains,19zero43bdd0 stillShowWindow/flagclear. HWND/palette/clipper не очищаются; wrapper43bec0 отдельно. Native rollback и retained280 init |
| R02/R04/R15/R17 | `0x43b3d0..0x43bc3e/ret16`, выбранные сообщения100/101,200..205,3a0/3a1/3b5..3b8 | Целые keyboard/mouse/joystick callbacks, распознавание двух последовательностей, ESC cleanup и caller HWND | D+Native [WINDOW_INPUT](WINDOW_INPUT.md):4369 whole callbacks +3 отдельных конструкторов,385 retained calls,5908 requests/23835 stores,424 WndProc PC.576 static starts включают другие, ещё открытые сообщения; приложение/устройства/Windows отдельно |
| R02/R04/R15 | `0x4031b0`, `0x4031d0..0x40325e/ret4`, initializer `0x4462e0` | Три constructor clears; B..Y/digits/space/dot, index/total/backspace/Enter и настоящий NUL/index alias | D+Native [WINDOW_INPUT](WINDOW_INPUT.md):1387 text returns,360 обычных B от собственного результата конструктора, два alias→index256. Activation и sequence zero — явные входы; неизвестное backing остаётся ошибкой/откатом |
| R02/R14/R16 | `0x4019b0`, `0x401d30`, `0x43d2a0`, `0x43d280`; WndProc ESC | Catalog→builtin→device, четыре music pointers, оба replay free→clear перед PostMessage caller HWND | D+Native [WINDOW_INPUT](WINDOW_INPUT.md):12 cleanup chains,20 free requests; общий native cleanup сохраняет прежний menu global HWND. Declared COM/free boundary, late/ownership rollback; actual devices/heap открыты |
| R02/R15 | `0x427915..0x427ca7`, фрагмент | Пять пунктов меню, поля/flags, подсветка, RNG, звук, ShellExecute | D против Swift: [MAIN_MENU.md](MAIN_MENU.md),1020probes/4150events; до42873e/4287de, bitmap request boundary, panel null/empty; tail в следующем исследовании |
| R02/R15 | `0x42873e..0x428805`; `0x4246b0..0x424736` | Общий tail/ret4 и целый вызов World=1→2 | D против Swift: [MENU_PRESENTATION.md](MENU_PRESENTATION.md),1482 returns/66 transitions,177955008bytes/masks; real cookie/SEH, earlier screen path supplied |
| R02/R15 | `0x423910..0x423938`, `0x43ef50..0x43ef68` | Release surface/free menu bitmap и очистка4511ac | D null bitmap/null surface/live surface и целых dead bytes/masks; S4238b9 allocation1f50, загрузчик423840 ещё не исполнен |
| R14/R15 | `0x402810..0x402893`, `0x401f30..0x401fff` | Общая громкость, две шкалы и порядок query/get/set/release | D actual helpers до COM, Int32 wrap и HRESULT branches; не вывод звука |
| R02/R14/R15 | `0x4229cc..0x4297ae`, переход через429730/4297a6 | Настоящий menu prologue и условный запрос main.wma; previous!=10/menu==10 | D основного продолжения round с music=1; paused control entry supplied. [MUSIC_PLAYBACK.md](MUSIC_PLAYBACK.md); остановка перед menu resources/previous assignment |
| R14 | `0x402020..0x4020f6`, `0x401c90..0x401d26`, `0x401da0..0x401e85` | Запрос/смена трека, создание и query интерфейсов, graph.log/wide path/RenderFile, ошибки и Run | D против Swift:748 случаев, настоящие helpers/CRT format/ret и полные globals/allocations; COM/Win32/new responses supplied, codec/музыкальный вывод открыты |
| R02/R13/R15 | `0x4297ae..0x429e5a`, особенно429b21/429c50 |11 menu bitmap, три массива8 слов, частичная SPARK-разметка и сброс44d07c | D против Swift:374 случая/2098 настоящих43ee50,3376 checkpoints, все записи/маски; [MENU_RESOURCES.md](MENU_RESOURCES.md).12 остановок перед null-SPARK write, не безопасный skip и не Windows AV; dispatch/пиксели открыты |
| R02/R15 | `0x41c581..0x429e5a`, actual4198f0 return41d495;429730 frame1000df08 | Собственное раннее menu/loading состояние через local/control/replay/round, музыку и ресурсы выбора | D против Swift:2 свежих natural phase1/pause0 chain,11897268 bytes/masks,136 events/44 checkpoints, сохранённые26 ранних wrappers; [MENU_STARTUP.md](MENU_STARTUP.md). Selection dispatch/body и app/W ещё открыты |
| R02/R15 | `0x429e5a..0x429f00`, `0x431d10` | Выбор экрана: mode5 при450c2c==0 принудительно ставит menu10; menu10 вызывает431d10 | S: естественное продолжение после ресурсов;431d10 вызывает415160, условный423840,4236d0 и bitmap draws. D/native полного тела ещё открыто |
| R02/R04/R15 | `0x431b70..0x431c64`, `0x4322ad..0x4328f8` | Общий ввод восьми мест и keyboard transitions экрана режимов431d10; playback boundary43249c | D2690 самостоятельных случаев/40350records/176765280bytes+masks, actual sound/background/device releases. Строгий button priority/seat latch, alias, signed navigation; весь экран из собственного startup ещё открыт. [MODE_SELECTION.md](MODE_SELECTION.md) |
| R15 | `0x422b00..0x422f59` | Имя клавиши и поправка позиции для исходной подсказки | S полного диапазона/последнего ret; native/D и caller432954 ещё открыты |
| R02/R15 | `0x419e40`, `0x4246b0..0x427089` | Ранние24 bitmap, восемь UInt16 имён,151 literal rectangle и шесть256-glyph tables | D290 случаев/4090 real constructors/995170 ordered writes: [FRONT_MENU_RESOURCES.md](FRONT_MENU_RESOURCES.md). Stop BEFORE423480; caller frame/allocator/device supplied, не полный startup |
| R02/R15 | `0x423480..0x4236c8`, call `0x427089`, store `0x427092` | Чтение data/control.txt, затем44d068=caller EBX (natural0) | D188 случаев [SETTINGS_LOADING.md](SETTINGS_LOADING.md):8742 actual VC80 scans/696 gets/510 feof,186 returns; свой native parent, полные globals/scratch masks. File open/close/translation и Windows открыты |
| R02/R15 | `0x42709b..0x427127`, выход `0x4275cb` | Выбор раннего экрана, fill, фон, bitmap caller42710f | D356 случаев [FRONT_SCREEN_PRELUDE.md](FRONT_SCREEN_PRELUDE.md), после свежих World/resources/settings; полный экран, pixels/W открыты |
| R02/R15 | `0x4237e0..0x42383e`, `0x43c450..0x43c495` | Raw string gate, lock/read458424/unlock, условный CreateThread43c240/GetLastError | D gate/26 thread requests с явными Win32 ответами; сам worker/конкурентность не исполнены |
| R02/R13/R15 | `0x423840..0x423909` | TimeGetTime UInt32%13+1, actual sprintf MENU_BACK, wrapper1f50/43ee50, store4511ac | D всех13 исходных PE DIB,64 конструкторов/66 formats; count/rectangles не инициализируются, old wrappers retained |
| R13 | `0x415160..0x4151c2` | Blt fill, только size/color в100-byte DDBLTFX | D354 fixed caller fills с полными effects/backing/masks; generic wrapping rectangle math S, DirectDraw raster/W открыты |
| R02/R15 | `0x4236d0..0x4237d3`, caller `0x427127`, return `0x42712c` | Обновление панели под critical section, две попытки content/bitmap, default/cache writes | D266 случаев [MENU_PANEL_UPDATE.md](MENU_PANEL_UPDATE.md) после свежего prefix:828 child returns/94 constructors/92 destructors; signed version/toggle, date asymmetry, полные records, две явные остановки до scanf; worker/IO/W открыты |
| R02/R15 | `0x42712c..0x4275cb`, фрагмент | Строки, GDI text, ссылки/клик, статусная кнопка и logo draw | D1142 случаев [FRONT_SCREEN_BODY.md](FRONT_SCREEN_BODY.md),8650 real helper returns/180886 events после свежего panel parent;192 local bytes/masks, все25 bitmap, две остановки до null text load; альтернативы/пиксели/W открыты |
| R02/R15 | `0x4275cb..0x42790f`, фрагменты; callers `0x427688/0x427704` | Selector−3 с анимацией/настройкой панели и записью control.txt; selector−1 с индикатором ожидания и отменой | D1066 случаев [FRONT_SCREEN_ALTERNATE.md](FRONT_SCREEN_ALTERNATE.md),6842 real helper returns/164 settings calls, общий worker gate,1348 fills, полные globals/stack/World/25bitmap и writer snapshots;24 null bitmap/fill/FILE boundaries; следом соединение main-menu/tail, device/W открыты |
| R02/R15 | `0x427915..0x427ca7 → 0x42873e..0x428805`; полный `0x4246b0` при World1 | Возврат главного меню с реальными ранними bitmap, overlay/network/CRT/present, World1→2 и освобождение фона | D806 возвратов [FRONT_MENU_COMPLETION.md](FRONT_MENU_COMPLETION.md),6996 helper returns/234000 actual rand/148 sprintf/395787072 bytes+masks; первый непрерывен от startup; поздние caller inputs явные, повторный screen loop/World2/W открыты |
| R02/R15 | Полный `0x4246b0`, повторные prefix/update/body/alternate/main/tail; `0x424741 → 0x41bc90` | Повторные внешние вызовы после свежего ret4, сохранение фона/settings/waiting/CRT и выбор последующей фазы своим состоянием | D238 calls/1094 phases [FRONT_MENU_LOOP.md](FRONT_MENU_LOOP.md):228 ret4,8 selector/FILE boundaries,2 actual loading entries;3945 helpers/30000 rand/376899720 bytes+masks. Нет внутренних caller register inputs; тело loading, остальные selectors, worker и W открыты |
| R02/R03/R14/R15 | `0x424741 → 0x41bc90..0x41c581`; `0x41bea9 → 0x43f010` | Ранний World2 продолжается настоящей первой загрузкой; MENU_WAIT/clip исполняются с живым ранним bitmap | D2 полных цепочек [MENU_LOADING.md](MENU_LOADING.md):36+800 WAVs/274 Objects/816 Actor/20 UI constructors,363365426 bytes+masks после меню; own native handoff, сохранённый stack/CPU/World и26 ранних records на проход. Animated loading, полный ret41bc90, приложение/W открыты |
| R02/R15 | `0x423230..0x423475` | Запись control.txt, кодирование/восстановление четырёх общих имён, defaults/metadata | D452 отдельных случаев [SETTINGS_WRITING.md](SETTINGS_WRITING.md),23964 fprintf/442 fclose,73626 descriptor writes/108 short-error, полные FILE/buffer/globals;8 null-FILE/2 no-NUL boundaries; caller/Windows открыты |
| R02/CRT | DLL `0x78141712`, `0x78141671`, `0x781416c8`, `0x78141f5d/0x78141fdf` | Byte output count и отдельные sign/value segments для plain%d/%s | S/D settings writer: после failed minus digits продолжаются, output count−1 может снова стать неотрицательным; shared printFormat используется также menu-info. Другие conversion modes/EILSEQ42 и Windows открыты |
| R02/R15 | `0x43c780..0x43cc53` | Загрузчик информационной панели: пути,24 ba/8 ta/un/y/end | D704 отдельных случаев [MENU_CONTENT.md](MENU_CONTENT.md), actual VC80 sprintf/fgets/sscanf, persistent globals/полный scratch; joined parent выше, исходные ad0/ad1 отсутствуют, present-file inputs контрольные; W открыт |
| R02/R13/R15 | `0x43cc60..0x43cf3a` | Замена bitmap458420 и11 буквальных rectangles | D118 отдельных случаев [MENU_PANEL_BITMAP.md](MENU_PANEL_BITMAP.md):102 constructors/100 destructors, все live/dead поколения и44 повторные выдачи адреса; joined parent выше, malloc/DIB/COM inputs supplied; W открыт |
| R02/R15 | `0x43c4a0..0x43c685/ret`, caller `0x43cf94` | Startup adinfo tokens/date widths/retained index-period/path order | D+Native [MENU_INFO_READING](MENU_INFO_READING.md):194 whole calls+2 unknown-local rejections;16 own reader/writer/reader chains.132/132reader starts, full states/masks. Whole WinMain/content/panel/default join and Windows open |
| R02/R15 | `0x43c690..0x43c708`, `0x43c710..0x43c77e` | Запись default/cache adinfo и путей | D534 отдельных случаев [MENU_INFO_WRITING.md](MENU_INFO_WRITING.md), actual VC80 sprintf/fprintf/fclose, все FILE/buffer/globals, short/error writes; joined parent выше, user-buffered FILE и descriptor IO supplied; W открыт |
| R02/CRT | DLL `0x7813ef8b`, `0x7813e93b`, `0x781422fc` | `_flsbuf`, flush, fclose для byte-output FILE flags102 | D в writer корпусах:2618 запросов `_write`/148 short/error, буферы1/7/64/4096, символ после failed flush; другой stream mode/EILSEQ42 и real Windows text translation открыты |
| R14/R15 | `0x4028a0..0x402a5f`, `0x401290..0x4012fe`, `0x43e940..0x43e99e` | Notice/timers, GDI text helper, три режима present | D actual sprintf/GDI requests/COM;184formats, raw COLORREF/rect, не пиксели или GDI DLL |
| R14/R15/R16 | `0x4019b0..0x401a26`, `0x401d30..0x401d90`, `0x43d2a0..0x43d2b7` | Shutdown sound lists/DirectShow/replay slots, затем PostMessageA caller4287cc | D helper order/free/latch и held-button continuation; COM reference counts и реальное закрытие окна вне границы |
| R02/R16 | `0x402b60..0x402d63`, `0x402ad0..0x402b58`, `0x402a60..0x402acf` | Сетевой init, выбор адреса по byte prefixes, порядок socket/AsyncSelect | D реальных EXE helpers против Swift в menu chain; WSOCK32 results/host buffers supplied,46 actual CRT formats, не реальная сеть |
| R02 | `0x42d1ff..0x42d6ed`, фрагмент | Общая подготовка выбранных Actor/арены и сброс ввода | D против Swift: [MATCH_PREPARATION.md](MATCH_PREPARATION.md), полный каталог и 50 последовательных сценариев |
| R02/R16 | `0x42d6fc`, call site; `0x43d2c0..0x43db38`, функция; `0x43d280`, free | Начальное состояние записи повтора, смена буфера, сброс счётчика RNG | D против Swift: [REPLAY_INITIALIZATION.md](REPLAY_INITIALIZATION.md), 50 полных буферов; playback/файл/такты ещё открыты |
| R14 | `0x401a30..0x401a6f`, функция, ret 4 | Прямой вызов sound buffer vtable +48/+34/+30 при ненулевых ресурсах | D loop=0 в прологе, включая failing HRESULT; device output не проверен. S `43d0c4..43d0ce` связывает 455610 с data/m_ok.wav |
| R13 | `0x415160..0x4151c2`, функция | Прямоугольная заливка поверхности 455608, flags 0x1000400 | D пролога (0,0,794,550,0) до device boundary; определены лишь size/color effects, не остальные stack bytes |
| R02/R03 | `0x40c957..0x40c970`, `0x40cb4e..0x40cb54`, `0x40c220`, `0x41253d..0x412543` | Основные области каталога: стадии, фоны, счётчики | S байтов/арифметики: [catalog-layout.json](../evidence/catalog-layout.json); загрузка целиком ещё открыта |
| R02/R03 | `0x4122f0..0x4127fb`, функция, ret 8 | Родитель каталога: встроенные записи, реестр, порядок дочерних вызовов | D против Swift: [CATALOG_REGISTRY.md](CATALOG_REGISTRY.md), 12 случаев; дочерние Object/BG/Stage/bitmap — непрозрачные границы |
| R02/R03 | `0x412648`, `0x41275c`, call sites | Чтение строк объектов/фонов через `%d %s %d %s %s` / `%d %s %s` | D родителя с ограниченным CRT-контрактом; подписи не проверяются, повторные ID сохраняются, BG получает ordinal отдельно от ID |
| R02/R03 | `0x41259d..0x4125c6`, фрагмент | Вклад внешнего токена в global 44f620: signedByte × индекс, dword wrap | D родительского вклада; не полная контрольная сумма загруженной игры |
| R02/R06 | `0x4061d0..0x4064cc`, функция | Конструктор Actor: пишет 913/1056 байт | S/D побайтно и по маске против Swift: [STATE_LAYOUT.md](STATE_LAYOUT.md); практика отдельно меняет spawn/скорости |
| R02 | `0x419e40..0x419e5f`, функция; `0x446300..0x446305`, статический инициализатор | World: конструктор обнуляет только selector + 400 байт активности | D конструктора; S статического адреса 458b00. Полный lifecycle открыт |
| R02/R03 | `0x412660..0x412695` | Object: аллокация 0x25360 и вызов 40ef70 | S; сырой снимок хранит всю аллокацию, загрузка целиком требует R03.1 |
| R02/R03 | `0x40bbf0`, функция | Начальное состояние записи кадра | D: [FRAME_LOADER.md](../FRAME_LOADER.md) |
| R02/R03 | `0x40c910..0x40d09d`, функция, ret | Целый stage.dat: 60 слотов, stage/phase/entry, sparse defaults | D против Swift: [STAGE_LOADER.md](STAGE_LOADER.md), 25 стадий / 138 фаз + контроль; не Stage gameplay, CRT-границы |
| R03 | `0x414a30..0x414b6f`, функция, ret | Декодер с явным source/destination; Stage вызывает без проверки суффикса | D полных decoded bytes text/raw; не реальный MSVCR80 |
| R02/R03 | `0x40c9f5..0x40cb79`, фрагмент | 100 фаз × 60 записей, defaults Stage | D всей записи/маски после каждой stage ID; 288 904 определённых байта при первой инициализации |
| R03 | `0x40cc38..0x40cc75`, фрагмент | bound+80 с wrap перезаписывает x всех 60 записей текущей фазы | D исходника/контроля, порядок с x сохранён |
| R02/R03 | `0x40c160..0x40c901`, функция, ret 12 | Целый BG: name/geometry, слои, тень, checksum | D против Swift: [BACKGROUND_LOADER.md](BACKGROUND_LOADER.md), все 17 исходных арен и контроль; source ID не читается, ordinal выбирает запись |
| R03/R13 | `0x40c030..0x40c0db`, `0x40c0e0..0x40c157`, функции, ret 4 | Отдельная загрузка/выгрузка слоёв; первый pointer — sentinel, остальные сохраняют старые адреса | D полного storage/resource order; device/allocator границы, не native pixels или путь меню |
| R03/R13 | `0x40c70e..0x40c737`, фрагмент | Преобразование rect после `%ld`, включая matching failure | D исходных арен/контроля; точные сдвиги и +70707, не стандартный RGB565 helper |
| R03 | `0x40ef70..0x4122e7`, функция, ret 16 | Целый Object: конструкторы, декодирование, заголовки, кадры, ресурсы | D против Swift: [OBJECT_LOADER.md](OBJECT_LOADER.md); три исходных файла и контроль, CRT/device-границы, не весь каталог |
| R03 | `0x40efc3..0x40f0c0`, фрагмент | 400 конструкторов кадров, defaults заголовка объекта | D полного загрузчика: 130 894 определённых байта Object после этого участка; неизвестные байты сохранены |
| R03 | `0x40f799..0x40fa5a`, фрагмент | Численные параметры движения заголовка | S: смещения известны; MSVCR80 `%lf` здесь не проверен |
| R03/R13 | `0x40f254..0x40f6a2`, `0x40fd28..0x410165` | Завершение листа, cumulative row*col, прямые/зеркальные сетки | D заголовков и полных bitmap-записей; пиксели/DirectDraw отдельно |
| R03/R14 | `0x40bd90..0x40be68`, функция | Регистрация оружейного звука; сохранение прежнего индекса при неизвестном новом пути | D kunai/control; Frame sound сбрасывает индекс в -1 перед поиском (`41097b`) |
| R03/R13 | `0x43ee50..0x43ef41`, функция | Bitmap wrapper, загрузка размеров и установка color key | D с границами `43ed10`/DirectDraw; отсутствие mirror проверено как заданный device failure |
| R03 | `0x4103f8..0x412277`, фрагмент | Загрузка одной секции кадра и постобработка | D: [oracle_frames.py](../../tools/oracle_frames.py); 349 групп за границей |
| R03/R14 | `0x41098e..0x410a99`, фрагмент | Регистрация пути звука в общем кэше | D отдельных случаев, звуковое устройство выключено |
| R04/R16 | `0x4198f0`, функция | Применение сетевых команд мест со status ровно−1; запись полного байта | D1452 случаев /757 remote returns [RECEIVED_INPUT](RECEIVED_INPUT.md), все256 byte values/phase/status/alias controls; socket transport отдельно |
| R04/R16 | `0x4197a0`, функция | Применение команд повтора ко всем восьми местам | D того же корпуса: raw previous, phase0 decoding, игнорирование status/activity; источник playback packet отдельно |
| R02/R04/R16 | `0x41c5e5..0x41d46f`, фрагмент | Phase0 local hotkeys, два порядка packet exchange, checksums и ошибки | D5 986 случаев против Swift: [INPUT_CONTROL](INPUT_CONTROL.md), оба первых caller непрерывны от загрузки; Winsock/COM/MessageBox/free/PostMessage — явные границы |
| R02/R16 | `0x41bdce..0x41be8b`, фрагмент | Очистка обоих command buffers и условное чтение playback packet | D2 268 случаев общего [REPLAY_TICK](REPLAY_TICK.md) corpus; пауза не отменяет очистку, ранний playback prefix/camera отдельно |
| R16 | `0x43dc50..0x43dd56`, `0x43db40..0x43dc47`, две функции cdecl | Чтение/запись10 bytes по `2b38+10*tick` с UInt32 wrap | D630 read/1 026 write calls, реальные возвраты/ABI; buffers supplied, metadata overlap сохранён |
| R02/R16 | `0x41d4b7..0x41d5db`, фрагмент | Проверка суммы HP первых20 seats каждые150ticks, error/reset/restore | D678 checksum reads,114 reset/56 restore, activity ровно1/Actor aliases/Int32 wrap; не очищает450bdc, не освобождает буфер |
| R02/R16 | `0x41d5db..0x41d714`, фрагмент | Запись пакета/суммы до ограничения tick647999 | D546 checksum writes, предел/пауза/выбор источника и наложение с metadata;614 connected input chains, не полный такт |
| R02/R10 | `0x41d714..0x41d73b`, `0x41d79e..0x41e339`, связанные ветви | Paused-render continuation; counters, living teams/Stage, confirmation и восстановление перед gameplay/menu/эпилогом | D4 148 случаев [MATCH_ROUND](MATCH_ROUND.md), свежие input/replay родители, полные записи; paused draw/gameplay/menu bodies не исполнены |
| R10/R11 | `0x41ddf2..0x41e0e1`, цикл400 мест | Обратная подмена по sourceID324, разделение по328/32c/330/334 с реальным4061d0 | D90 конструкторов, самоссылки/порядок half HP и signed координаты; исходный каталог, без подмены Object headers |
| R11 | `0x41de84..0x41dedb`, ветвь | Текущий sourceID50 при458428==0 ищет sourceID6 и пропускает последующий split path | S/D round corpus; оригинальное исключение, не allowlist персонажа |
| R14 | `0x402100..0x40212b`, функция | При ненулевом44f04c:44f044 method+24, затем44f04c method+20 с binary64+0 | D142 requests в round corpus, реальные ret/ABI; COM results supplied, аудиовыход отдельно |
| R10/R15/R16 | `0x41e0e1..0x41e18b`, ветвь | Menu28/128/202/2, timer reset/input reset, условный playback restore/menu10, выход422a95 | D914 reset/22 restore; буфер не освобождается, эпилог и меню не подразумеваются |
| R04/R15 | `0x416c70..0x416fad`, группа helpers | Общие команды: flags, pause/step, menu, дополнительные запросы и счётчики | D25 984 настоящих вызовов; исходные menu/mode/phase/timer gates и Int32 wrap; последующие игровые эффекты команд отдельно |
| R02/R16 | `0x43df00..0x43df93`; caller `0x416d58..0x416d74` | Возврат saved settings/строк и звуковых флагов из playback buffer | D4 восстановлений; saved320 bytes и обе allocations supplied, строки через NUL внутри extent. Полный save/playback startup и файл открыты |
| R04 | `0x431c70..0x431d0d`, функция | Сброс семи current bytes через восемь ссылок World и300 keyboard bytes | D30 вызовов в control corpus, включая повторные Actor-ссылки; memset — объявленная граница |
| R02/R04/R16 | `0x41d469..0x41d4b7`, `0x41d495..0x41d5db` (без playback) | Caller remote→playback, обход при локальной паузе | D обоих корпусов, первый phase1 переход из41c5e5 непрерывен; первый phase0 control — supplied caller entry. Network/hotkeys и playback checksum вне границ |
| R04/R17 | `0x419a60`, функция | Путь ввода локальных игроков | D606 cases/601 ret12 [LOCAL_INPUT](LOCAL_INPUT.md): keyboard/joystick bytes, phase/status/packing; AI dispatch с явными child boundaries. OS polling и Windows input/latency открыты |
| R04/R05 | `0x413080`, функция | Буферы, управляющие переходы и скорости кадра | D срезов движения/боя/игл; прочие ветви открыты |
| R04/R05/R14 | `0x413080..0x4143cb`, вся функция; `0x417090..0x417162` | Общий контроль Actor и stereo accumulator | D [ACTOR_CONTROL](ACTOR_CONTROL.md),25 795 synthetic и5376 случаев/42 исходных type0 Object; World caller теперь соединён ниже, весь такт открыт |
| R02/R04/R05 | `0x41e339..0x41e634`; `0x403270..0x4034d3`, `0x4034e0..0x4034ea` | Полный400-slot control caller, телепортации и превращения/связанные объекты | D [WORLD_CONTROL](WORLD_CONTROL.md):1491 synthetic/full pool+masks и оба собственных MATCH_LAUNCH до41e634; следующая физика теперь соединена ниже |
| R02/R05/R10/R11 | `0x41e634..0x41eed1`, весь проход | Общая физика, смерть/возрождение, создание998, обратное превращение и связи | D [WORLD_PHYSICS](WORLD_PHYSICS.md):515 synthetic/full400-slot pool и оба собственных MATCH_LAUNCH до41eed1; до начального Z/contact |
| R14 | `0x416fb0..0x417082`, функция | Каталожный stereo accumulator | D [ACTOR_PHYSICS](ACTOR_PHYSICS.md):2511 sound requests двух корпусов включают builtin/catalog; фактический вывод отдельно |
| R04 | `0x413080..0x4132ef`, префикс; `0x40e170`, `0x40e2d0`, `0x40e450`, `0x412800..0x413077` | Общие фронты/история,9 комбо, DAT-переходы и стоимость | D [ACTOR_INPUT](ACTOR_INPUT.md),14 624 synthetic cases/полные Actor bytes+masks; остальной413080 и полный такт открыты |
| R04 | `0x412800..0x413077`, группа обработчиков; `0x40e170`, helper | Распознавание комбинаций, сброс неверной последовательности | D прогресса девяти комбинаций; выполнение большинства техник ещё отсутствует |
| R04 | `0x40e2d0`, функция | Переход в кадр, доступность HP/MP, очистка буферов | D положительного перехода Саске 261 за 100 MP; отрицательные/999 и иные стоимости требуют расширения |
| R05 | `0x40d960..0x40de20`, вся функция | Планировщик кадров, счётчиков, переходных HP/MP и звука | D [ACTOR_SCHEDULER](ACTOR_SCHEDULER.md):6084 controlled calls при53 битах, все316 инструкций и actual416fb0; fullActor/masks/globalsSHA/756sounds. Окружающий400-slot caller и естественные DAT-последовательности открыты |
| R05 | `0x40e490..0x40ef6a`, вся функция; `0x4450d0..0x44517a`, конечные преобразования | Перемещение, hitstop, гравитация, приземление/отскок; x87/CW037f | D [ACTOR_PHYSICS](ACTOR_PHYSICS.md):9344 synthetic +46089 случаев/все15363 кадра137 исходных Object; nonfinite/прочие CW/Windows startup открыты |
| R05/R10 | `0x41fb0b..0x41fc61`, фрагмент | Ранний lifetime, смерть и коррекция grounded кадров после планировщика | D в целом [POSTDRAW_OPOINT](POSTDRAW_OPOINT.md):1991 controlled calls, signed/NaN/Inf/zero gates, ownership/алиасы; не полный lifecycle |
| R02/R05/R06/R10 | `0x41f550..0x41fb0b`, префикс одного слота | Трансформации, частицы9996, HP/MP и полный scheduler; неактивный выход4214c6 | D [POSTDRAW_SLOT_PREFIX](POSTDRAW_SLOT_PREFIX.md):897 controlled calls/329 instructions/full pool+masks/globals/retained SP+70 и2334 events; полный consumer теперь ниже, own chain открыта |
| R02/R05/R06/R10 | `0x41f550..0x4214cf`, полный живой обход400 слотов | Prefix/scheduler/opoint/weapon/commands/late effects/lifetime и продвижение EDI | D [POSTDRAW_LIFECYCLE](POSTDRAW_LIFECYCLE.md):5432 calls,921 whole loops,1885/1892 body PCs,полный пул/маски/globals/6 retained words/25638 events; оба [own consumer](GAMEPLAY_LIFECYCLE.md) теперь до4214d5 приCW023f |
| R02/R05/R06/R10 | `0x41f550..0x4214d5`, новая own граница перед4214d5 | Состояние после полной инициализации/запуска и полного post-draw обхода | D [GAMEPLAY_LIFECYCLE](GAMEPLAY_LIFECYCLE.md):оба parent полностью воспроизведены; каждый385317 records/700844396 bytes+masks/503helpers/55snapshots; source302 executed PCs+1stop в новой стадии, FPU1192 checks; tick return ещё открыт |
| R02/R06/R10 | `0x4214d5..0x421a15`, целый consumer до HUD | Команды предметов/ресурсов, два таймера лечения и очистка400 слотов | D [POSTDRAW_COMMANDS](POSTDRAW_COMMANDS.md):3898 calls/318 из327 body PCs; полный пул/маски/globals/SP34 и3252 events. Исходные ID122/300, переполнения/алиасы/byteEB; flags сбрасываются позже |
| R02/R06/R10 | `0x4214d5..0x421a15`, новая own граница | Полностью инициализированный Naruto/Sasuke District после recovery/cleanup | D [GAMEPLAY_COMMANDS](GAMEPLAY_COMMANDS.md):оба parent воспроизведены; каждый417293 records/736179550 bytes+masks/503helpers/57state/1593FPU;49 executed PCs+1stop. Первый проход неизменен, SP34 не читается; HUD продолжен ниже, полный такт открыт |
| R06/R10/R11 | `0x4203b4..0x4213a4`, продолжения после opoint | Оружейные фрагменты по исходным ID, команды998, эффекты999 смерти/огня, previousFrame update | D в полном [POSTDRAW_LIFECYCLE](POSTDRAW_LIFECYCLE.md): live aliases, RNG166..207, lookup miss/retainedObject/fullpool, sound и rounding53; естественные DAT-последовательности и Windows открыты |
| R10 | `0x41f994..0x41faf8`, фрагмент | Восстановление HP/MP и иные изменения ресурсов до планировщика | D в полном [префиксе](POSTDRAW_SLOT_PREFIX.md): signed HP/redHP/MP gates, wrapping, divisor, sourceID51/52 и порядок перед40d960; естественный полный матч ещё открыт |
| R06/R02 | `0x41ef55..0x41f276`, весь участок в caller41eefb..41f2ac | RNG146..154, фильтры100..<200/122/123, координаты, constructor/активация/vrest | D [WORLD_HITS](WORLD_HITS.md):150 whole caller cases, full pool и новая собственная цепочка; no-free-slot требует caller scratch provenance, empty candidates fault-domain отдельно |
| R06 | `0x41fc61..0x4203b4`, тело с выходами4203b4/420e93 | Общий opoint: count/facing, constructor, spread, owners/hold/vrest | D [POSTDRAW_OPOINT](POSTDRAW_OPOINT.md):2291 constructors/6873 conversions в1991 whole caller probes; исходные multiplicities1..10/35. Альтернатива4203b4..420e93 перенесена в lifecycle выше |
| R06 | `0x4213a9..0x4214c6`, ранние пути из41fb0b | Деактивация некорректного кадра либо lifetime1100..<1300 с owner counters | D [POSTDRAW_OPOINT](POSTDRAW_OPOINT.md):точный ранний register context, activity==1, aliases/all400owners; остальные входящие контексты ещё открыты |
| R05/R09/R11 | `0x417f80..0x4187a3`, вся функция; caller `0x41eed1..0x41eed8` | Два400-slot прохода: глубина, held-object placement/use/throw, ID122/123 и RNG136..143 | D [WORLD_LINKS](WORLD_LINKS.md):3018 synthetic/full pool+mask и обе собственные launch цепочки до41eed8; второй caller и другие link helpers отдельно |
| R07/R11 | `0x419380..0x4196df`, вся функция; caller `0x41eed8..0x41eefb` | Префикс400 слотов, signed vrest, обе стороны каждой пары и обязательныйfusion tail | D [WORLD_CONTACTS](WORLD_CONTACTS.md):7925 controlled cases и обе собственные launch цепочки; далее42e100/item passes |
| R07 | `0x4171c0..0x4171fc`, `0x417200..0x4173fa`, `0x417400..0x417f7b`, все тела | Signed rectangle, current/cached Frame gates, raw ITR/BDY filters и ordered contact buffers/RNG133/134 | D WORLD_CONTACTS полного pool/масок и ABI; естественные DAT-последовательности отдельно |
| R09/R11 | `0x4064d0..0x406a1f`, всё тело |20-seat cooldown, fusion sourceID7/8→51, unfusion с реальным4061d0 и дубликатамиID | D WORLD_CONTACTS, including inactive cooldown, catalog misses, clamp/alias/reconstruction order |
| R08 | `0x42e100..0x431b64`, вся функция; caller `0x41eefb..0x41f2ac` | Полное разрешение контактов: урон/guard/падения/отражение, cpoint-подготовка/подбор/силы/искры, live raw ITR и CRT | D [WORLD_HITS](WORLD_HITS.md):7845 synthetic cases и обе own launch цепочки до41f2ac, весь pool/маски/globals/heap/CRT; естественные DAT-последовательности и W отдельно |
| R08 | `0x42f0a9..0x42f183`, `0x430520..0x430569`, фрагменты | Реакция state 3000 на попадание/блок | D игл; это ветвь по состоянию, а не проверка ID 440 |
| R08/R14 | `0x42fe19..0x42fe85`, фрагмент | Выбор звука при блоке type 3 | D игл с исходным default -1 |
| R08 | `0x4196f0..0x419798`, функция | Применение накопленного импульса | D1030 pools/9385 writes при CW037f; own41f4ac..41f550 с CRT/GDI и очищением count0. [FPU audit](FPU_PRECISION.md): startup выбирает53 бита, native-коррекция открыта |
| R02 | `0x445a31..0x445a59`, функция; `0x445546`, вызов | Startup `_controlfp_s(NULL,10000,30000)` | S initializer-table path; D whole helper/реальная MSVCR80, четыре CW controls,191 PCs.53-битная точность и32 отличающихся stores; Windows/thread/device provenance открыта |
| R09 | `0x418c30..0x419373`, `0x4187b0..0x418c2f`, целые функции; caller `0x41f2ac..0x41f484` | Cpoint actions/exhaustion/throw/подмена, current-frame placement/injury, held-owner cleanup и второй417f80 | D [WORLD_CPOINTS](WORLD_CPOINTS.md):2681 controlled cases и две собственные цепочки до41f484; caller scratch, естественные DAT-связки и Windows отдельно |
| R01/R07 | `0x4219d6..0x4219f5`, фрагмент | Очистка части контактного состояния | Наблюдённые записи воспроизводятся стендом; окружающий цикл открыт |
| R02/R16 | `0x417170`, функция | Игровой RNG | D 6 500 вызовов; начальная таблица из исходного повтора |
| R16 | `0x43e766..0x43e7d3`, `0x43e3c5..0x43e3f8`, фрагменты | Префикс повтора, восстановление RNG | D: [original_replay.py](../../tools/original_replay.py); распаковка — явная граница Python zlib |
| R13 | `0x41b5d0..0x41bc87`, `0x41a250..0x41a590`, `0x41a050..0x41a24d`, целые тела; caller `0x41f484..0x41f496` | Все400 bounds/deactivation, camera target/smoothing/replay, DAT background/parallax/counters, built-in99 и реальные bitmap/fill children | D [WORLD_CAMERA](WORLD_CAMERA.md):4742 controlled cases и обе own chains до41f496, full pool/masks/globals/101BG/events; raster/Windows отдельно |
| R13 | `0x41a5a0..0x41ae50`, `0x40de30..0x40e160`, `0x40be70..0x40bf1f`, `0x40bf30..0x40bfa8`, `0x43f310..0x43f37a`, целые тела | Стабильная сортировка400 слотов, тени/спрайты, листы/ширины/отражение, подписи, жизни и изменяемые sparks; actual bitmap/clip/rectangle children | D [WORLD_DRAWING](WORLD_DRAWING.md):2679 controlled cases/full pool/masks/globals/BG и202262 ordered events; own caller41f496..41f4ac, пиксели/Windows отдельно |
| R13 | `0x41ae60..0x41b12d`, целое тело/ret4 | Восемь HUD-ячеек, выбор слота0..<8 либо10..<18, портрет728, полосы ресурсов и команда | D [WORLD_HUD](WORLD_HUD.md):1753 calls/276106events/39462Blts,223/223 HUD PCs; caller421a15 сбрасывает flags, аргумент не читается,target455608. Полный пул/маски/globals, real bitmap/clip/rectangle; pixels/W открыты |
| R02/R13 | `0x421a15..0x421a2d`, собственный HUD caller | Инициализированный Naruto/Sasuke District через весь HUD | D [GAMEPLAY_HUD](GAMEPLAY_HUD.md):каждый449269records/771514704bytes+masks/59state/1603FPU;536/544helpers,124/180events,419/424 original PCs+COM+stop; backing сохранён. Диагностика продолжена в GAMEPLAY_NOTICES; полный возврат/W открыты |
| R02/R13/R15 | DLL `0x7817775d`, `0x78149dd9`, `0x78149f23`, `0x7814d4b2`, game literal421a60 | Диагностические `%2.3f`/`%2.4f`: LD10/17digits,80-bit integer scaling и два округления | D [DIAGNOSTIC_NUMBERS](DIAGNOSTIC_NUMBERS.md):74424 outputs+intermediates; all binary64 exponent fields/signs,1567 original PCs+PTD hook. Source504-byte tables pinned; не весь caller/printf/Windows |
| R13 | `0x41b5d0..0x41bc74`, фрагмент | Границы арены и камера до рисования | D District и двух вариантов локального игрока |
| R13 | `0x41a250`, функция | Вывод фоновых слоёв | D 120 списков District; не пиксели DirectDraw |
| R13 | `0x40dffc..0x40e0b5`, фрагмент | Позиция спрайта и отражение | S, визуальная проверка macOS; позы D отдельно |
| R13/R11 | `0x41a690..0x41a770`, фрагмент | Условия и смещения тени | S; некоторые условия ID перечислены ниже |
| R13 | `0x43f010..0x43f2fe`, `0x43ef70..0x43f000` | Whole/frame bitmap draw, signed clipping, mirror correction, Blt requests и ret24 | D против Swift:3971 случай,3330 clip returns/2297 Blt,198 double-draw cases; [BITMAP_DRAWING.md](BITMAP_DRAWING.md). Явные backing/viewport/device inputs, negative/wrapped indices и20 invalid-access boundaries; DirectDraw raster/пиксели и Windows открыты |
| R14 | `0x416fb0`, `0x417090`, функции | Входы звука кадра / встроенного звука | D событий с заменой аудиовыхода; не DirectSound mix |
| R14 | `0x41bec8..0x41bf86`, фрагмент | Соответствие встроенных звуков исходным WAV | S; используемые события D |
| R11/R12 | `0x403a7e`, `0x404c12`, инструкции | Сравнения ID с 2 и 11 в ветвях выбора действий | S, функции/условия целиком ещё не исследованы; не закрытая реализация AI |
| R09/R10/R15/R16 | **Полный набор границ не установлен** | Все захваты/оружие, ресурсы, исход матча, режимы, сетевой протокол | Начальные стадии найдены в R01.1; продолжать через их поля/вызовы, не угадывать семантику соседних функций |

## Где продолжать нативный перенос

Это текущие файлы реализации. Их имена не предписывают окончательное устройство
общего движка; рефакторинг сохраняет исходный порядок и принятые сравнения.

| Блок | Текущий нативный код | Проверка |
| --- | --- | --- |
| R01/R02 | [OriginalMelee.swift](../../native/Sources/NTSDCore/OriginalMelee.swift), [OriginalClock.swift](../../native/Sources/NTSDCore/OriginalClock.swift) | [oracle_projectiles.py](../../tools/oracle_projectiles.py), [oracle_presentation.py](../../tools/oracle_presentation.py); полного такта пока нет |
| R02 | [OriginalStateRecord.swift](../../native/Sources/NTSDCore/OriginalStateRecord.swift) | [oracle_state.py](../../tools/oracle_state.py), [oracle_state_trace.py](../../tools/oracle_state_trace.py); конструкторы D против Swift, полный такт ещё не сравнивается |
| R02/R06 | [OriginalWorldBootstrap.swift](../../native/Sources/NTSDCore/OriginalWorldBootstrap.swift) | [oracle_bootstrap.py](../../tools/oracle_bootstrap.py); 400 слотов с исходным порядком конструкторов, отдельная загрузочная стадия |
| R02/R04/R16 | [OriginalInputControl.swift](../../native/Sources/NTSDCore/OriginalInputControl.swift) | [oracle_input_control.py](../../tools/oracle_input_control.py); общий control после полной загрузки, shared sound/shutdown/reset и receiveInput. Platform IO и Practice пока отдельно |
| R02/R16 | [OriginalRandom.swift](../../native/Sources/NTSDCore/OriginalRandom.swift) | [oracle_combat.py](../../tools/oracle_combat.py), [original_replay.py](../../tools/original_replay.py) |
| R02/R03 | [OriginalStageLoader.swift](../../native/Sources/NTSDCore/OriginalStageLoader.swift) | [oracle_stages.py](../../tools/oracle_stages.py); полный storage/порядок загрузки, не Stage gameplay |
| R03/R13 | [OriginalBackgroundLoader.swift](../../native/Sources/NTSDCore/OriginalBackgroundLoader.swift) | [oracle_backgrounds.py](../../tools/oracle_backgrounds.py); metadata и layer resource lifecycle, не renderer |
| R03 | [OriginalObjectLoader.swift](../../native/Sources/NTSDCore/OriginalObjectLoader.swift), [OriginalDATDecoder.swift](../../native/Sources/NTSDCore/OriginalDATDecoder.swift), [OriginalFrameLoader.swift](../../native/Sources/NTSDCore/OriginalFrameLoader.swift) | [oracle_objects.py](../../tools/oracle_objects.py), [oracle_frames.py](../../tools/oracle_frames.py); практика пока отдельно использует импорт JSON |
| R04/R05 | [OriginalFighter.swift](../../native/Sources/NTSDCore/OriginalFighter.swift), [OriginalMovement.swift](../../native/Sources/NTSDCore/OriginalMovement.swift) | [oracle_movement.py](../../tools/oracle_movement.py), combat/projectiles corpora |
| R06/R07/R08 | [OriginalMelee.swift](../../native/Sources/NTSDCore/OriginalMelee.swift), [OriginalProjectile.swift](../../native/Sources/NTSDCore/OriginalProjectile.swift) | combat/projectiles corpora; текущий каталог намеренно ограничен |
| R13/R14/R17 | [MeleeScene.swift](../../native/Sources/NTSDApp/MeleeScene.swift), [Assets.swift](../../native/Sources/NTSDApp/Assets.swift), [main.swift](../../native/Sources/NTSDApp/main.swift) | oracle_presentation, позы/события из корпусов, UI-проверки; пиксели/сведение/задержка открыты |
| R09/R10/R11/R12/R15 | Отдельной полной реализации нет; имеющиеся фрагменты перечислены выше | Новые карточки и исходные эталоны обязательны для расширения объявленного объёма |

## Опорные вызовы внутри обработки мира

Новая непрерывная D-цепочка [MATCH_LAUNCH](MATCH_LAUNCH.md): собственные
`42cf8a..42d1ff`, `42d1ff..42d6b6`, caller`42d6b6`→`4025b0`→`402020`,
`42d6bb..42d6ed`, caller`42d6fc`→`43d2c0`/`43d280`, продолжение`42d704`,
все вложенные возвраты и следующий целый`4246b0` до`41e339`.
`43d280` вызывается даже при null: нулевая проверка находится в`43d285..43d289`.
На первом новом входе caller`41d60e`→`43db40` возвращается`41d613`,
`41d6ac` пишет checksum1000; контрольная граница имеет phase1/tick1/RNG39/0.
Два корпуса совпали с Native. `41e339..41e62e` и дальнейший игровой проход
в этой цепочке ещё не исполнены; следующая зависимость — настоящий413080
с окружающими state400/401/500/501, затем физика и остальные стадии R01.2.

Источник: дизассемблирование EXE; ранее зафиксированные связи в
[MOVEMENT.md](../MOVEMENT.md). Это **не полный граф вызовов**.
Условия обычного входа, циклы и пропущенные стадии установлены в
[R01.1](TICK_PIPELINE.md); полный индекс воспроизводит `tools/inspect_tick.py`.

| Call site | Цель / операция | Статус в текущем стенде |
| --- | --- | --- |
| `0x41c5e0` | `0x419a60`, локальный ввод | Не выполняется |
| `0x41d490` | `0x4198f0`, сетевые команды | В старом tick corpus вызывается отдельно; новый [RECEIVED_INPUT](RECEIVED_INPUT.md) также исполняет реальный caller |
| `0x41e35f` | `0x413080`, управление | Вызывается для активных объектов |
| `0x41e652` | `0x40e490`, физика | Вызывается для активных объектов |
| `0x41eed3` | `0x417f80`, границы Z и held-object pass | Вся функция и первый собственный caller теперь D WORLD_LINKS |
| `0x41eef6` | `0x419380`, контакты и4064d0 | Весь caller/function/helper tree теперь D WORLD_CONTACTS на собственной цепочке до41eefb |
| `0x41ef42` | `0x42e100`, разрешение для активных type 0 | Весь caller D WORLD_HITS; старая Practice-композиция ещё отдельна |
| `0x41ef6c` | `0x417170(146,200)`, шанс появления предмета при числе type 1/2/4/6 < 4 | D WORLD_HITS всего item caller; первый own draw64, index/counter40/1 |
| `0x41f299` | `0x42e100`, разрешение для активных signed type > 0 | D WORLD_HITS: после создания предмета, включая новые активные слоты; повторного сбора контактов нет |
| `0x41f2ae`, `0x41f2b3`, `0x41f47f` | Cpoint actions, placement, held-owner cleanup, затем второй417f80 | Весь caller и обе целые cpoint функции D WORLD_CPOINTS на собственной цепочке до41f484; старая Practice-композиция ещё отдельна |
| `0x41f491` | `0x41b5d0`, границы/камера/рисование | Выполнение обрывается перед рисованием |
| `0x41f4a7` | Вызов отрисовки объектов | Стенд снимает позы самостоятельно |
| `0x41f540` | `0x4196f0`, накопленные импульсы | Вызывается |
| `0x41fb06` | `0x40d960`, планировщик | Вызывается в обходе слотов, затем выбранные фрагменты opoint/удаления |

Два вызова разрешения относятся к разным типам. Результат R01.1 устраняет
неопределённость старой записи; он не означает двойной удар по каждому бойцу.

## Связанный экран режимов

Подробности и границы D — [MODE_SCREEN.md](MODE_SCREEN.md). Поздние caller
probes не означают выполнение всего внешнего цикла.

| Адрес | Назначение | Доказательство / следующий участок |
| --- | --- | --- |
| `429eb2` → `431d10`, return`429eb7` | Mode screen, this=World, target/menu/mode/selection, ret16 | D1264 случаев из собственного startup и явных повторных callers |
| `422b00..422f59` | Исходное имя key code и поправка x | D всех256 byte codes и четырёх Int32 controls в связанном help |
| `423840` | Общий случайный фон меню | D56 constructors в новом корпусе; прежний ранний caller использует тот же native helper |
| `42e0d2..42e0f9` | Эпилог429730/ret12 | D двух собственных первых возвратов [MENU_RETURN](MENU_RETURN.md); caller`4229dd`, return`4229e2` |
| `4229e2..422ab8` | Network notice, volume/present, menu0 timer,41bc90 ret4 | D190 output cases, только два первых исполняют эпилог; остальные188 останавливаются до422a95 |
| `424746..424750`, `4287de..428805` | held457580=0 и ранний ret4 после41bc90 | D двух собственных первых возвратов: ESP/SEH/nonvolatile восстановлены; cursor/44d060/второй present здесь отсутствуют |
| `429f09..42a1ea` | Menu3/1 character initialization,400 teams и CHARMENU | D в68 собственных [CHARACTER_SCREEN](CHARACTER_SCREEN.md); Stage/War альтернативы пока S |
| `4246b0` → `41bc90` → `429e5a` | Повторный собственный World2, phase/input/round/menu | D8 вызовов [MENU_CYCLE](MENU_CYCLE.md):6 полных ret4,2 остановки перед character-selection dispatch; acquired key без подстановки Actor/menu/phase |
| `41bcd0..41bd24`, `41bdce..41be92` | Повторный non-playback пролог и оба command buffers после завершённой загрузки | D фаз0/1/0/1, собственного подтверждения VS и отложенного отпускания; playback prefix остаётся отдельной границей |
| `42a69e..42a6c6` | Right-navigation gate для signed sourceID/10 групп3 и5 | D собственного закрытого gate и обхода до Naruto/Sasuke; открытый gate/left/up/jump требуют дополнительных probes |
| `42a25a..42b290`, `42e0b6..42e0d2` | Human-seat render/join/roster/team/ready, activity и countdown | D68 экранов CHARACTER_SCREEN, дополнительно100 экранов MATCH_SELECTION с реальным jump/countdown; альтернативные modes/edge cases пока S |
| `42b296..42b959` | Computer count и popup0..7; min/max, input latch, подтверждение | D собственной VS/count0 ветви [MATCH_SELECTION](MATCH_SELECTION.md); положительный CPU count и mode2/3 открыты |
| `42b621..42b72f` | Случайный подбор всех мест с selected<0, включая неактивные | D6 списков/tagd7 на проход, общее правило type0/sourceID<30/исключение8 выбранных |
| `42b964..42cb86` | Dispatch computer character/team; при count0 всё равно читает current seat | D собственного нулевого CPU пути; компьютерные тела остаются открытыми |
| `42cb86..42cf8a` | Панель настроек, BG name/difficulty, input и Start | D50+50 собственных кадров через District до42cf8a; Stage/War альтернативы S |
| `402130..4025a5` | Music selection/title; Random каждый кадр расходует417170 | D29 вызовов на проход с choice0; left/right/OFF/Stage имеют S правила, wider D открыт |

## Известные структуры: опоры для R02.1

| База / смещения | Известное назначение | Граница знания |
| --- | --- | --- |
| Object `+0x6f4`, `+0x6f8` | ID, type | Используются исходным кодом и стендом; весь заголовок ещё не закрыт |
| Object `+0x7a4 + frame * 0x178` | Запись кадра | Карта полей в [FRAME_LOADER.md](../FRAME_LOADER.md) |
| Frame `+0x30`, `+0x4c`, `+0x58..0x74` | hit_Fa, mp, opoint | Это смещения от записи кадра, не Actor |
| Actor `+0x10/+0x14/+0x18` | Целые x/y/z | Снимки D |
| Actor `+0x40/+0x48/+0x50`, `+0x58/+0x60/+0x68` | Double vx/vy/vz, x/y/z | Порядок x87 и округления важен; D конкретных траекторий |
| Actor `+0x70/+0x74/+0x7c`, `+0x80`, `+0x88` | frame / previousFrame / collisionFrame, facing, wait | Типы/размеры полей уточнять по операциям, не по Swift Int |
| Actor `+0xf0` | 400 signed-byte vrest | D корпуса с объектами |
| Actor `+0x2fc/+0x300/+0x308` | HP / recoverable HP / MP | Восстановление между тактами ещё не перенесено |
| Actor `+0x348/+0x34c/+0x350`, `+0x354/+0x364/+0x368` | Урон нанесён/получен, MP потрачено; owner/team/Object pointer | D ограниченного боя; прочие статистики не считать нулевыми автоматически |
| World `+0`, `+4`, `+0x194`, `+0x7d4` | Селектор диспетчера, активность слотов, указатели Actor, ссылка на каталог/фоновые данные | World по 458b00; конструктор записывает только первые 404 байта. Полный layout/каталог открыты |
| `0x450b90`, `0x450bfc`, `0x44fb60`, `0x44fcb0` | Фаза и очередь паузы | S/D R01.1; полный ввод — R04 |
| `0x450bd0`, `0x450bd4`, `0x450bd8` | Счётчики modulo 12/3 и переключатель неприостановленного пути | S/D R01.1; в старом нативном состоянии отсутствуют |
| `0x44ff90`, `0x450bcc`, `0x450c34` | Таблица RNG, индекс, счётчик | Восстановление seed D; инициализация нового матча открыта |
| `0x450b4c`, восемь 32-битных ячеек | Режимы входных слотов |4198f0 выбирает ровно−1 для remote input;4197a0 применяет playback ко всем восьми независимо от статуса. Для камеры старый стенд временно меняет выбранный слот |
| `0x450bc4`, `0x450bc8` | Положение и скорость камеры | D для District |
| `0x44d034` | Флаг учёта стоимости перехода | Стоимость включена в стенде снарядов; все режимы изменения флага открыты |
| `0x455638`, шаг 20 байт | Кэш звуковых путей | D повторов и перекрытия; это не независимые безопасные строки |

`ACTOR=0x22000000`, `WORLD=0x23000000`, шаг `0x500` между Actor и другие адреса
`0x2…` в Python — **размещение памяти тестовым стендом**, не адреса/stride
исходной игры. R01.1 установила аллокацию Actor по **0x420 байт**; остальные
размеры и полный layout — R02.1. Точные маски и новые опоры —
[STATE_LAYOUT.md](STATE_LAYOUT.md). Нейтральные render-поля ProjectileState —
также схема снимка, не оригинальные поля.

## Начальный реестр исключений R11

| Исключение | Адрес / условие | Что подтверждено | Следующая проверка |
| --- | --- | --- | --- |
| EX-001 | `0x41a6ed`, `0x41a6f4`: ID 223/224 | S: пропуск тени; native 224 сохраняет исключение | Одинаковые state/высота у исключённого и обычного объекта; список исходных draw calls |
| EX-002 | `0x41ffb0`, `0x41ffb8`: ID 223/224 | S: обход коррекции z по удержанным up/down в ветке создания | Проверить именно различающую ветвь при одинаковом подходящем state; имеющиеся тесты змеи state 3002 сами её не доказывают |
| EX-003 | `0x403a7e`: ID 2 | S: существует ветка, читающая ресурсы и вызывающая RNG | Вход/выход всей функции, условия, эффект на команды AI |
| EX-004 | `0x404c12`: ID 11 | S: ветка с проверками MP, расстояния, RNG и записью управляющего состояния | То же; не выводить назначение лишь из имени Sasuke |

Новые подтверждённые contact/fusion ветви перечислены в
[WORLD_CONTACTS](WORLD_CONTACTS.md):4174ad..417506 sourceID200/203/205/206/207/
215/216 против209;41776c..417919 sourceID212/остатки кадров;417afb..417b0f
mode1/sourceID201/202;406506..406a1f слияние7/8/51. Они имеют7925-case общий
контрольный корпус, но полная естественная достижимость и весь R11 ещё открыты.

Это четыре начальные записи, не полный список всех проверок ID в EXE.
Дальнейший поиск должен учитывать загрузку ID в регистр, диапазоны и таблицы
переходов; поиск одного текста `cmp [object+0x6f4]` заведомо неполон.

## Границы платформы и CRT

| IAT VA | Импорт | Работа |
| --- | --- | --- |
| `0x447008` | DDRAW.dll / DirectDrawCreate | R13/R17: платформенный вывод; фактические вызовы интерфейсов искать отдельно |
| `0x447010` | DSOUND.dll / ordinal:1 | R14: аудиоплатформа; имя по ordinal здесь не угадывается |
| `0x447250`, `0x447098`, `0x447060` | timeGetTime, Sleep, GetTickCount | R01/R17: проверить всех пользователей времени и источник семантики обычного боя |
| `0x447188`, `0x447158` | MSVCR80 fscanf, sscanf | R03: фактические числовые преобразования, включая переполнения |
| `0x447174`, `0x4470a4` | MSVCR80 sprintf, GetLocalTime | R02/R16: [MATCH_PRELUDE.md](MATCH_PRELUDE.md); реальный экспорт sprintf7817775d в закреплённой DLL, три формата, SYSTEMTIME supplied |
| `0x447198`, `0x4470ec` | MSVCR80 rand, srand | Отличать от игрового RNG `0x417170`; сейчас rand подменён только для неотрисованных hit sparks |

Все 163 импорта и секции находятся в `build/original/executable.json`, который
создаёт [inspect_original.py](../../tools/inspect_original.py). Наличие DLL в
таблице не доказывает использование конкретной функции в каждом режиме.

<a id="reproduce"></a>
## Воспроизведение адресного поиска

Из корня репозитория:

```bash
python3 tools/inspect_original.py
mkdir -p build/research
xcrun llvm-objdump --disassemble --x86-asm-syntax=intel \
  'downloads/NTSD_2.4_2.0a_clean/NTSD 2.4_2.0a/NTSD 2.4.exe' \
  > build/research/original.asm
rg -n 'call.*(413080|40e490|419380|42e100|4196f0|40d960)' build/research/original.asm
```

Перед адресным анализом сверить SHA-256 из инвентаризации. Полный листинг и
промежуточные дампы остаются в игнорируемом `build/`; доказательство в карточке
должно сохранять адреса, короткие необходимые наблюдения и воспроизводимые входы.
