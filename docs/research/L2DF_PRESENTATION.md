# L2DF: исходный таймер и отображение камеры

Статус: принято в объявленном объёме. Приближает полный игровой цикл и исходный темп/вид из
[полной цели](L2DF_FULL_GAME_GOAL.md). Родитель — commit4778284, принятые
[bounded World](L2DF_CHIDORI_COMPATIBILITY.md), [MOVEMENT](../MOVEMENT.md),
[APPLICATION_TIMER](APPLICATION_TIMER.md), [WORLD_CAMERA](WORLD_CAMERA.md).

Читаем сохранённые результаты pinned NTSD EXE
`3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c`.
Новых EXE/DLL запусков, эмуляции или hooks нет. Источники — текущая чистая
основная копия ab0db06c, принятые Swift handlers и immutable fixtures.
Исходные таймерные наблюдения моделировали timeGetTime/dispatch/recovery/Sleep;
это не Windows latency и не собственный полный message loop.

| Вопрос | Уже готовый источник | Проверка кандидата |
| --- | --- | --- |
| Полная no-message timer decision43d157..43d1ef | original-application-timer.json:2025 случаев/8163 ordered requests; OriginalApplicationTimer.swift | baseline, fresh clock reads, target/dispatch/recovery/sleep order/arguments, неизменность input, late timer rollback |
| Исторический normal-speed aggregate | original-presentation.json:36 отсчётов | Несколько решений при неизменном now дают исходные ticks/baseline; это отдельная прежняя граница |
| District draw list и counter lifetime | Тот же presentation fixture:120 полных списков/15слоёв; OriginalClock.swift и whole OriginalBackgroundDrawing | Все layer/order/x/y/transparency, lifetime counters косвенно через последовательную анимацию; raw counter snapshots в fixture отсутствуют. Отдельно проверяется неизменность counters при preview; inputs отделены от expected |
| Реальное применение камеры | Уже сравнённое World.cameraX, OriginalWorldCamera/MOVEMENT | Актёры/тени/снаряды используют x-camera; фон свой parallax; исходный viewport794×550; лог проекции и визуальная проверка |
| Host integration | Одно решение таймера управляет одним L2DF update без второго accumulator | Пакетные330/70-tick проверки, полный70-case state/masks, pause/reset и новый архив с неизменными ресурсами |

Root реализует `compat/application_timer.lua`, `compat/background.lua`, host
`main.lua`/`conf.lua`, соответствующие prepare/run/package и reference comparator.
`/root/l2df_reference_review` проверяет контракт/код независимо только чтением.
`/root/l2df_prototype` отдельно исследует общие combat handlers без правок.
Изменяемые пути: prototypes/l2df, эта карточка, goal/CURRENT_WORK и новое evidence.
Main, upstream, ресурсы, предыдущие study/app/expected защищены.

Правила: UInt32 wrap baseline/clock, speedFlag0→3ms иначе33, strict lateness>,
дополнительные fresh reads при100ms clamp, signed-negative dispatch recovery,
signed-positive capped Sleep. Timer rollback сохраняет baseline, но не отменяет
уже совершённые внешние эффекты. Native host pause/focus reset — отдельный adapter,
а не доказательство исходной Windows семантики. Фон использует собственные
счётчики: increment/remainder до inclusive animation gate, parallax с truncation.
Позднее повторное рисование кадра не продвигает counters. Полные BG99/loops/fills
и arbitrary overflow не принимаются по узким120District спискам.

Результаты в task-owned X5 `build/l2df-prototype/presentation-20260912`.
UUID3A4F5FA6-DC86-4C6E-87E2-EAC2C2D72548, резерв6GiB, исходные pins в
plan-inputs.json. Лимит90с на новый кандидатный тест, до2GiB новых артефактов,
первые3исправления с последующей диагностикой контракта. Каждый запуск имеет
новую директорию, неизменные snapshots, PID/start/command и terminal result.
Никакой завершённый source не повторяется. Два initial read/setup errors
(несуществующее имя evidence и неверный zlib wrapper) сохранены в setup-errors.txt;
они произошли до запуска кандидата и не являются source faults.

Приёмка требует всех перечисленных сравнений и независимого review. Статус
полной цели остаётся открытым: алгоритм камеры пока bounded two-player, весь
gameplay/message loop, произвольные арены, пиксели/устройства/Windows отдельно.

## Фактическая приёмка

`numeric-03` совпал по всем2025 решениям/8163 requests,36 последовательным clock
samples и120 District спискам. Timer baseline rollback при позднем Sleep observer
и не меняющий counters preview проходят. В первом `numeric-01` ошибался comparator:
он создавал timer заново для каждого legacy sample, тогда как source producer
сохраняет baseline в двух цепочках по18samples. Все20 mismatches/старые snapshots
сохранены. `numeric-02` исправляет только жизнь timer в проверке, `numeric-03`
добавляет constructor input-immutability gate и отдельный результат rollback.
Игровые модули и source/expected для этих исправлений не менялись.

`native-01/NTSD L2DF Native.app` прошёл330-tick smoke,70-tick original needles
case и unsupported tick13/R-reset. Старый `check_app_case.py` сравнил все70
MeleeState и callback/controller masks,11 audio calls/isPlaying. Smoke сохраняет
пять игл,100MP и20 audio calls. Reset восстанавливает фон и даёт один следующий
такт. Все три jobs terminal0. Старые семь kernel modules совпадают с принятым
575/16685 прогоном; повторный полный kernel run без изменения модулей не выполнялся.

`check_host_logs.py` проверил642 timer decisions/70 dispatches и2706/330;
все fresh-clock/lag/sleep решения согласованы. Общие количества dispatch/state
совпадают, единственный update call site рассмотрен отдельно; per-dispatch tick
instrumentation отсутствует. Проверены560/2640 background requests и188/698
упорядоченных pre-Render Object poses. Pic/centerx/centery этот geometry gate не
сравнивает. Boolean/number distinction проверяется; camera ограничена0..166.
Первый read-only host report сохранён, вторые уточняют типы и пределы утверждения;
игра не перезапускалась ради изменения отчёта.

Root просмотрел `fan.png` и `interactive-13.png`: видно исходное camera-relative
поле794×550 с отдельной54px панелью и согласованным letterbox. Это визуальная
проверка текущего Mac, не Windows pixel match. Resize/focus automation, физические
клавиши, акустика и точная latency остаются открыты. `elapsed` в summary — сумма
callback `.033`, не реальное время устройства. Рекомендация логировать clock
generation/reset при дальнейшем focus/resize этапе сохранена.

Проверены271 ZIP members,112 исходных ресурсов/19544930байт,139upstream и136
package files. Все plan input pins и прежний app неизменны; main чистыйab0db06c.
Открыт новый интерактивный app без бесконечных diagnostic traces: PID113,
start12:33:08 MSK, unified session10657. В09:33UTC наблюдалось настоящее окно
14419/1152×748; оно было on-screen, но не active. PID перед действием перепроверять.
Первый lookup старого read-only window probe ошибся каталогом; FileNotFoundError
сохранён в observation, приложение не перезапускалось.

Независимый reviewer `/root/l2df_reference_review` рассмотрел правила, comparator
corrections и Host integration; обязательные замечания закрыты. Полные hashes,
job/trace/image pins и ограничения: [evidence](../evidence/l2df-presentation.json).
Следующий этап — подключение собственной Swift-сессии общего NTSDCore по C ABI,
затем initialized catalog/whole gameplay. [Полная цель](L2DF_FULL_GAME_GOAL.md)
остаётся активной со всеми семью критериями.
