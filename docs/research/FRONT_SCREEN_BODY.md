# R02.1/R15 — продолжение раннего экрана

Эталон — EXE SHA-256
`3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c`;
VC80 DLL SHA-256
`c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d`.
Участок `42712c..4275cb` продолжает свежие World/resources/settings/prefix и
[обновление панели](MENU_PANEL_UPDATE.md) на том же CPU, стеке и памяти.
Остановка — перед selector dispatch в `4275cb`; альтернативные экраны не
исполняются этим корпусом. Первое обновление панели естественно имеет status0.

`OriginalFrontScreenBody` использует существующие `OriginalBitmapDrawing`,
`OriginalMatchPrelude.confirmationSound` и общий `OriginalSurfaceText`.
Последний выделен из `OriginalMenuPresentation`, которое теперь вызывает
тот же обработчик для прежних уведомлений. Native заново проверяет собственного
родителя через `MenuPanelUpdateReference.onNatural`. Ожидаемые после-снимки не
становятся входным состоянием native. Ни один персонаж не получает новый handler.

## Строки и стек

Сначала оригинал копирует 28, 31 и 29 байт из `4498d8`, `4498b8` и `449204`
в caller stack+`48`, `84` и `64`. Первые28 байт каждой строки копируются по
четыре; хвост31-byte строки — word и byte, хвост29-byte — byte. После этого
stack+`14` получает signed32 `45757c + 491` с переполнением.

Три строки последовательно декодируются вычитанием `index & 3` из каждого
байта. Длина до NUL заново вычисляется после каждой записи. Сохранены исходные
байты констант, размер копии и порядок всех записей. Получаются:

- `by Marti Wong, Starsky Wong`
- `1999-2008, all rights reserved`
- `http://www.LittleFighter.com`

Это буквальные подписи EXE, включая регистр; они не заменяются новой подписью
порта. Весь192-byte caller local region сохраняется между контролируемыми
входами и сравнивается с масками записи. Первый backing наблюдается после
настоящего родителя; нетронутые байты не обнуляются. Caller EBX здесь равен0.
Другие BL/повреждённые строковые константы не входят в объявленный корпус.

## Текст, ссылки и клик

Три вызова настоящего `401290` имеют x591 и y=`base`, `base+20`, `base+40`,
где base=`45757c+491`. Background COLORREF=`602010`, foreground=`d07750`.
Подсветка меняет только foreground на`ffffff`. Все сложения и сравнения
сохраняют signed32/wrap семантику; координаты не приводятся к экранным границам.

| Область | Условие наведения | Подсвечиваемый текст |
| --- | --- | --- |
| Сайт | x>591, y>base+30, затем y<base+60 **или** `45757c==0` | Полная третья строка, x591/ybase+40 |
| Marti | 611<x<686, base<y<base+20 | Копия первой строки с байта3 через NUL, затем отдельный NUL на stack+ae; x611 |
| Starsky | x>692, base<y<base+20 | Копия первой строки с байта15 через NUL, затем отдельный NUL на stack+b0; x694 |

Обе временные копии начинаются на stack+a4. Байты после отдельно поставленного
NUL сохраняются: native не заменяет эти операции созданием новой короткой строки.
При нулевом смещении область сайта не имеет верхнего ограничения y после первой
проверки; эта особенность не исправляется. Три условия идут последовательно.

Клик принимается только при previous `44d060==0` и held `457580==1`.
Сначала held очищается, затем настоящий `401a30(455610,0)`, Sleep300 и
ShellExecute(open, исходный URL, show1). Адреса строк URL:
`44989c` — littlefighter.com, `449884` — martiwong.com,
`44986c` — lf2.net/starsky. В стенде Sleep/ShellExecute — наблюдаемые запросы,
ссылки не открываются и внешние сообщения не отправляются.

Весь `401290` исполняется: GetDC, при неотрицательном HRESULT — background,
foreground, lstrlenA, TextOutA и ReleaseDC. Возвращается исходный GetDC HRESULT,
результаты остальных вызовов его не меняют. При отрицательном GetDC нет GDI
и ReleaseDC, но родитель продолжает обработку наведения/клика.
`OriginalSurfaceText` сохраняет это правило и допускает разные координаты,
сырые цвета и byte strings, необходимые другим экранам.

## Кнопка и bitmap children

После ссылок Enter(`4554a4`), чтение `458424`, Leave. Статусы1/2 показывают
frame11 ресурса `451188` в725,5. Для остальных статусов setting`450be8==0`
выбирает frame6, любое ненулевое — frame8. При x>=725 и y<18 рисуется
frame7/9; нижних ограничений координат нет. Принятый клик очищает held,
записывает selector`44d064=-3`, затем играет звук.

Последний draw использует `4511a0`, x155, y=`453da4+96`, frame1. Все вызовы
имеют key1/mirror0 и берут target из настоящего caller stack+20. Полные
`43f010` и `43ef70` исполняются до Blt/ret24. Сравниваются все чтения bitmap,
клиппинг, запросы Blt и исходные размеры, без замены child на готовый request.
Ресурсы берутся из собственного свежего native parent; raw surface tokens
восстанавливаются из его объявленных constructor/device inputs, не из after-state.

Все25 ранних bitmap wrappers, World и globals проверяются после каждого случая.
Нет новых выделений и нет изменений bitmap records. Последний контроль с null
text target останавливается **до** разыменования`401295`, сохраняя уже записанные
строки/local bytes. Это явно ограниченная остановка, не успешный пропуск текста.

## Проверка и границы

Два корпуса по571 случаю: A5/прямые ранние ресурсы и ramp/обратные. Первый путь
непрерывен от World constructor; следующие входы явно задают caller registers,
mouse/worker/settings, viewport и device responses, сохраняя собственные globals,
local bytes и ресурсы. Это не полные следующие итерации UI.

| Наблюдение на корпус | Число |
| --- | ---: |
| Helper returns | 4 325 |
| Text requests / completed401290 | 1 871 / 1 870 |
| Bitmap draws / clip returns / Blt | 1 196 / 1 196 / 1 152 |
| Bitmap reads | 8 328 |
| Sound requests / ShellExecute | 63 / 19 |
| Ordered events / local writes / global writes | 90 443 / 64 080 / 107 |
| Full records / bytes и masks | 15 989 / 142 078 968 |
| Null-text boundaries | 1 |

Проверены строгие границы наведения, крайние signed координаты и смещения,
все статусные ветви, настройки, held/previous, disabled/null/live sound,
положительные и отрицательные HRESULT, пустые/отрицательные viewport и повторный
клик без вмешательства во внутреннее состояние. Source проверяет сохранение
nonvolatile registers и ESP каждого child, native — конкретные call/return sites.

```sh
uv run tools/oracle_front_screen_body.py
uv run tools/oracle_front_screen_body.py --control
uv run tools/oracle_front_screen_body.py --accept
swift test --package-path native --filter 'Original(FrontScreenBody|MenuPanelUpdate|MenuPresentation)Tests'
swift build --package-path native -c release --product NTSDNative
```

Оба raw и оба packed корпуса совпали с release CLI; fixtures приняты только
после двух успешных packed сравнений. Сохранены33 прежних pinned fixtures;
для двух новых проверены SHA raw/packed и полная распаковка. Пять XCTest прошли
за150.890 s: новый body6.062 s, прежний panel parent12.507 s и прежняя полная
menu-presentation цепочка132.322 s. Последняя проверяет выделение общего text
helper на старых уведомлениях и переходах. Release NTSDNative собран за2.37 s.
Отчёты: [основной](../evidence/front-screen-body.json),
[контрольный](../evidence/front-screen-body-control.json).

COM/GDI/lstrlen/Sleep/ShellExecute — объявленные границы. Sound handles в
контролях заданы явно: происхождение реального startup audio не доказывается.
Пиксели, системный шрифт, actual audio, worker/конкурентность, WinMain/Windows
и интеграция с оконным интерфейсом остаются открытыми.

Следующая задача — `4275cb`: selector−3 с анимацией/настройкой панели и
зависимостью settings writer`423230`, затем selector−1`4277f3`, их переходы
к main-menu`427915` и общему tail`42873e`. R02.1 и полный матч не завершены.
