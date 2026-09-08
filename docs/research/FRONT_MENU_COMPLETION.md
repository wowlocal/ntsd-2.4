# Главное меню с ранними ресурсами и настоящий возврат

R02.1/R15, продолжение [FRONT_SCREEN_ALTERNATE.md](FRONT_SCREEN_ALTERNATE.md).
EXE SHA-256: `3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c`.
MSVCR80 8.0.50727.6195 SHA-256: `c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d`.

## Что соединено

Первый проход заново выполняет World constructor, ранние24 UI wrappers,
оригинальный control.txt, prefix с фоном, updater4236d0, body42712c и dispatch4275cb.
Из естественного EAX0 он продолжает427915 через главное меню и42873e до
настоящего ret4 в428805. CPU, стек, загруженные bitmap и глобальное состояние
не заменяются между этими участками. Настоящий пролог4246b0 был выполнен ещё
родителем; сохранённые регистры, SEH и cookie принадлежат этому же вызову.

Прежние [MAIN_MENU.md](MAIN_MENU.md) и [MENU_PRESENTATION.md](MENU_PRESENTATION.md)
подставляли условные bitmap handles и останавливали43f010 на границе запроса.
Новая цепочка использует25 живых ресурсов раннего экрана и исполняет настоящие
43f010/43ef70 до COM Blt и возвратов. Конечные snapshots сохраняют весь World,
globals и все bitmap records с байтами, масками и состоянием владения.

Поздние пункты меню и tail entries — **явные caller controls**. Для них заново
исполняется SEH/cookie prologue4246b0..4246eb, после чего задаётся объявленная
точка входа427915 или42873e. Это не полные повторные screen iterations.
Последние два случая соединяют выбор первого пункта меню с последующим
**полным4246b0 при World=1**, включая423910/43ef50/free и переход World=2.
Сам первый41bc90 при World=2 здесь ещё не выполняется.

## Переиспользование нативного кода

`OriginalMainMenu.run` выделен из `OriginalMatchPreparation.runMainMenu`:
ему нужны только World, globals, CRT и платформенные ответы. Каталог боя для
раннего главного меню не требуется. Старый API подготовки делегирует тому же
обработчику; правила пяти пунктов и network helpers не переписаны отдельно.

`FrontScreenAlternateReference.onNatural` передаёт собственное проверенное
native состояние и ресурсы. Native completion продолжает их, не используя
ожидаемые after snapshots как входы. Общие `OriginalMenuPresentation`,
`OriginalBitmapDrawing`, `OriginalSurfaceText` и `OriginalCRTRandom` работают
на тех же данных. Сравниваются события и состояния после main-menu dispatch
и после настоящего возврата; сохранённая память освобождённых ресурсов не теряется.

Ownership/presentation хранит сырые COM tokens в bitmap+0. Для drawing этот
единственный известный word преобразуется в установленный формат1/0, а исходный
token отдельно передаётся в draw input. BitmapDrawing восстанавливает его перед
арифметикой отрицательных индексов. Произвольные указатели и прочие поля не
нормализуются; изменение представления не заимствует ожидаемые bytes.

Первое сравнение выявило ошибку именно этого адаптера: raw ownership record был
передан API drawing, который требует canonical+binding. Исправлен адаптер;
исходный и ожидаемый корпуса ради прохождения не изменялись.

## Реальные дочерние вызовы

| Исходные адреса | Результат композиции |
| --- | --- |
| `427932/4279eb/427a8b/427b97/427bf1/427c53 → 43f010` | Главное меню и подсветка используют реальные ранние wrappers/rectangles |
| `428773 → 43f010` | Cursor whole-image и возможный второй frame draw; оба clipping paths исполняются |
| `427a2c/427a71 → 422ac0` | По3000 actual VC80 rand; состояние PTD+14 сохраняется между пунктами меню |
| `427ac6 → 402b60/402ad0/402a60` | Исходный Winsock init/address selection до объявленных OS responses, actual sprintf в той же VM |
| `428779 → 4028a0/402810/401f30/401290` | Overlay, volume, QueryInterface, audio/GDI события, actual sprintf |
| `428784 → 43e940` | Mode1/2 flip и mode3 Blt с фактическими COM аргументами |
| `4287b2/4287b7/4287bc → 4019b0/401d30/43d2a0` | Shutdown с пустыми replay pointers и объявленными device handles |
| `424703 → 423910/43ef50` | Освобождается настоящий ранний фон4511ac; его record сохраняется как dead, surface+0 и global4511ac обнуляются |
| `424717 → 43f010` | MENU_WAIT рисуется с реальным ресурсом, затем World+0=2 |

Первый PTD получен прежним actual_initptd; RNG state=1, без придуманного seed.
Это стадия до восстановления полного процесса startup/srand, а не доказательство
начального seed Windows. Между новыми menu cases состояние PTD не сбрасывается.
Нативное сравнение проверяет каждый rand result/before/after, таблицы и конечные globals.
Fprintf здесь не подменяет sprintf: оригинальные DLL инструкции форматирования
выполняются на общем стеке для адресов и notices.

Сетевые ответы используют прежний `MainMenu.menu_imported`. Реального соединения,
ShellExecute или Sleep нет: это события на границе платформы. Enabled optional
panel423b00 остаётся открытым; новый корпус использует исходный отсутствующий panel.
Повторный held-tail сохраняет44d060, поэтому shutdown не повторяется без нового клика.
Null/error network paths идут напрямую в4287de и не обновляют previous через tail.

## Неинициализированные bitmap поля

LF2_CURSOR и MENU_WAIT сохраняют исходные untouched fields. В частности count+0c
не задаётся их constructor. В A5 корпусе он отрицательный, в ramp — положительный.
43f010 при frame−1 сначала рисует whole image, а затем **отдельно** сравнивает
frame<count и может выполнить ещё один frame path. Его координаты могут читать
другие raw header words. Нативная композиция сохраняет этот уже восстановленный
общий механизм, поэтому число clips/Blt в двух корпусах различается.

Это доказательство зависимости от предоставленного allocator backing, а не
сведения о реальной Windows heap initialization. Обнуление count для удобства
рисования изменило бы поведение EXE. Происхождение этих bytes в Windows остаётся W.

## Результаты D

Оба raw и оба packed корпуса прошли независимое сравнение до принятия fixtures.
[Основной отчёт](../evidence/front-menu-completion.json) и
[control](../evidence/front-menu-completion-control.json) фиксируют по403 ret4:
393 main-menu,395 tail,1 World1→2 и7 network error exits. Первые два числа
пересекаются: успешное главное меню продолжает tail в том же вызове.

| Показатель | A5 | Ramp |
| --- | ---: | ---: |
| Helper returns |3300|3696|
| События |9716|12232|
| Bitmap calls |961|961|
| Raw bitmap reads |5631|7483|
| Clips |961|1357|
| Blt |657|925|
| RNG tables / actual rand |39 /117000|39 /117000|
| Actual sprintf |74|74|
| Освобождение фона / quit request |1 /1|1 /1|
| Полные records / bytes+masks |21493 /197893536|21493 /197893536|

Итого806 возвратов,6996 helper returns,21948 событий,234000 actual DLL rand,
42986 records/395787072 bytes+masks. Отличия числа рисунков соответствуют
разным сохранённым allocator backing, а не разным native правилам.
Все78 прежних fixtures неизменны; raw/packed SHA и полная распаковка двух новых
проверены. Новый pin inventory содержит80 файлов.

Пять целевых XCTest прошли за139.941с: новые completion7.656с, прежние
alternates13.327с и исторический MainMenu118.958с. Последний заново проверяет
1020 probes/450 mouse messages, затем50 цепочек match preparation/recording;
выделение общего runner не изменило этот результат. Release NTSDNative собран за2.49с.

## Воспроизведение

```
uv run tools/oracle_front_menu_completion.py
uv run tools/oracle_front_menu_completion.py --control
swift build --package-path native -c release --product NTSDCatalogCheck
native/.build/release/NTSDCatalogCheck --front-menu-completion build/original/front-menu-completion.json
native/.build/release/NTSDCatalogCheck --front-menu-completion build/original/front-menu-completion-control.json
uv run tools/oracle_front_menu_completion.py --accept
swift test --package-path native --filter 'Original(FrontMenuCompletion|FrontScreenAlternate|MainMenu)Tests'
swift build --package-path native -c release --product NTSDNative
```

Оба raw и затем оба packed корпуса должны пройти независимое native сравнение
до записи fixtures. SwiftPM-команды выполняются последовательно.

## Открытые границы

Тестовые platform/device responses, ранний PTD lifecycle/seed, enabled panel,
прочие selectors и повторные полные screen iterations, World2→41bc90 и последующее
меню выбора персонажей остаются открытыми. Фактические пиксели/звук/сеть, запуск
под Windows и UI приложения этим исследованием не проверены. Caller scratch
главного меню/overlay не объявляется полностью перенесённым побайтно: здесь
проверяются ABI, события, World/globals и retained bitmap storage.192 local bytes
раннего body по-прежнему проверены его родительским корпусом.

Следующий шаг — соединить повторный ранний dispatch/prefix/body/alternates с
проверенным возвратом, затем продолжить World2 с настоящими загрузчиками.
