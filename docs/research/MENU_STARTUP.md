# От собственного раннего меню к ресурсам выбора персонажей

R02.1/R15. Продолжение [MENU_LOADING.md](MENU_LOADING.md) после41c581.
EXE SHA-256: `3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c`.
MSVCR80 8.0.50727.6195 SHA-256: `c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d`.

Статус: оба свежих source corpus и их packed варианты совпали с Native Core.
Приняты два новых fixtures; полная игра и UI приложения остаются открытыми.

## Вопрос и последовательность

Может ли собственное состояние после ранних119 вызовов меню и первой загрузки
пройти уже восстановленные input/round/music/resources участки без замены
World, Actor, globals, CPU или стека на промежуточных границах?

`oracle_menu_startup.py` соединяет прежние наблюдатели в одном CPU. Перед новым
участком он повторно выполняет и проверяет все четыре закреплённых raw документа
menu-loading, включая каждый blob. Оба варианта начинаются с естественных
phase1, pause0, menu10 и выключенных записи/воспроизведения повтора. Суффикс
control сохраняет обратные адреса Actor, ramp backing и иной presentation;
он не означает подстановку phase0 или пропуск паузной ветви.

| Участок | Настоящее продолжение |
| --- | --- |
| Локальный ввод |41c581 →419a60/ret12 →41c5e5 |
| Control/received |41c5e5 →41d46f →4198f0/ret12 →41d5db |
| Учёт повтора |41d5db →41d714 |
| Раунд |41d714 →4229cc, из собственного menu10 |
| Меню и музыка |4229cc →429730 →402020 с включённой музыкой →4297ae |
| Ресурсы выбора |4297ae →11 настоящих43ee50 →429e5a |

Вход41c581 имеет SP1000e9bc. Пролог429730 самостоятельно создаёт frame
меню: три аргумента/call, SEH и locals дают SP1000df08. Он отличается от
старого standalone SP1000df48 из-за настоящего предыдущего caller. Новый
стенд не записывает регистры или caller locals для перехода к меню.

## Владение памятью и платформенные границы

Старые отдельные наблюдатели используют прежние параметры по умолчанию. Для
совместного CPU они принимают уже существующий World и отдельные служебные
области. Это меняет ответы объявленных allocator/device/import границ.

| Область нового стенда | Адрес |
| --- | --- |
| Собственный World раннего меню |22000020 |
| Сохранённые ранние bitmap |28000000..2bffffff |
| Панель раннего меню |2c000000..2c1fffff |
| Второй PCM segment |2d000020 |
| Music COM tokens / wide allocations |31000000 |
| Bitmap выбора персонажей |32000000 |
| Control / music / resource imports |33000000 /33001000 /33002000 |

Прежние искусственные replay buffers2a000020/2b000020 здесь не создаются:
запись и playback ещё не начались, оба собственных replay pointers равны0.
Они пересекались бы с живой областью ранних bitmap. В native context остаётся
настоящее владение ранними wrappers. Устанавливаемые импортные адаптеры не
перезаписывают World/globals/старые ресурсы; это проверяется снимком до/после.
После передачи управления удаляется прежний общий code hook раннего меню:
при continuing_loading он уже ничего не выполнял. Ранние memory hooks и
явный настоящий MENU_WAIT callback сохраняются. Контрольный проход заново
воспроизвёл все четыре закреплённых menu-loading документа с этим изменением.

Saved-playback область458588..4588a7 снимается из исходного PE-состояния до
первого раннего прохода. Это объявленный исходный ввод отдельной области;
native создаёт её context из этих bytes, затем проверяет сохранение на всех
последующих checkpoint. После-снимки не используются для её инициализации.

Музыкальный формат%s\\graph.log по-прежнему выполняется закреплённой DLL на
существующей явно указанной scanner/format границе. COM, файлы, преобразование
кодировки и bitmap device возвращают объявленные значения. Настоящая Windows
среда и вывод звука/пикселей этим исполнением не подменяются.

## Нативное продолжение

`OriginalLoadedMatchEntry.run` вызывает общие local/control/received/replay/round
механизмы в исходном порядке, сохраняя собственные World/Actor/globals, команды
и context. Решение о recording/playback entry получает из receiveInput; результат
раунда возвращается как явное продолжение. Нужный AI/object child должен быть
предоставлен, если исполнение его достигнет. Персонажных ветвей не добавлено.

`MenuLoadingReference.onLoaded` отдаёт свой проверенный loading result, CRT и
ранние bitmap. Новый reference продолжает это состояние через общий обработчик,
затем существующие OriginalMusicPlayback и OriginalMenuResourceLoading. Проверяются
полные World/400 Actor/globals bytes+masks, командные буферы, saved context,
события, ret12/helper ABI, музыка, конструкторы и каждый resource checkpoint.
Все26 ранних bitmap и их liveness сравниваются до/после, включая dead wrapper.

## Проверки

Release NTSDCatalogCheck собран за75.70с. Первый повтор прежнего полного
menu-resources корпуса воспроизвёл все старые parent captures и blobs.
Оба новых raw corpus, затем оба packed варианта прошли сравнение с native.
На каждом:22 checkpoint,68 events,3412 records и5948634 bytes+masks после
проверенного menu/loading родителя. Итого нового продолжения —11897268 bytes/masks.
Проверены419a60 и4198f0 ret12,5 music helper returns,11 constructors и15
resource checkpoint. Первый native запуск выявил ошибку проверки ABI:4198f0
вызывается в41d490, возвращается в41d495. После сверки инструкций исправлен
только адрес в reference; Core и ожидаемые source snapshots не менялись.
Release-пересборка после этого исправления завершилась за46.90с.
С окончательными World/arena/import параметрами заново выполнен весь прежний
menu-resources корпус: все cases, parent captures и каждый blob совпали точно.
Оба прежних MenuLoading XCTest прошли за174.457с. Release NTSDNative собран
за2.88с; accept-пересборка NTSDCatalogCheck —0.18с. Оба новых startup XCTest
прошли за172.401с; вместе с прежними —4 теста за346.858с без ошибок.
Все90 прежних fixture hashes неизменны. SHA, размеры и полная распаковка двух
новых файлов проверены; inventory содержит92 файла в
`build/research/menu-startup-fixture-pins.json`. Основной raw/packed размер —
546495/346002 bytes, контрольный —564383/335670 bytes.

[Основной отчёт](../evidence/menu-startup.json) и
[контроль](../evidence/menu-startup-control.json) закрепляют raw/fixture SHA,
размеры и SHA четырёх прежних родительских fixtures. Каталог и звук повторно
не копируются в новые fixtures. Новые JSON упакованы lossless целиком.

```
uv run tools/oracle_menu_startup.py
uv run tools/oracle_menu_startup.py --control
uv run tools/oracle_menu_startup.py --accept
swift test --package-path native --filter OriginalMenuStartupTests
swift test --package-path native --filter OriginalMenuLoadingTests
swift build --package-path native -c release --product NTSDNative
```

SwiftPM выполняется последовательно. Старые fixtures не переписываются.

## Открытые границы

Следующее естественное продолжение — dispatch429e5a/431d10: сначала выбор
режима, затем выбор персонажей и подготовка выбранного матча. Общий ввод и
keyboard transitions отдельно перенесены в [MODE_SELECTION.md](MODE_SELECTION.md).
Новое [MODE_SCREEN.md](MODE_SCREEN.md) соединяет обычный431d10/ret16 с этим
собственным startup, сохраняя ранние ресурсы и состояние. Внешний возврат,
enabled panel/worker/playback files и следующий выбор участников ещё открыты.
Новый natural corpus не расширяет проверку
phase0/paused/AI ветвей: они сохраняют область своих отдельных исследований.
Полный возврат41bc90/очистка held424746, animated loading, остальные ранние
selectors, интерфейс приложения, законченный матч и Windows W ещё открыты.
