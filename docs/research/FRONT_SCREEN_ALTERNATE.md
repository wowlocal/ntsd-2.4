# Ранний диалог настроек и экран ожидания

Карточки: R02.1/R15. Продолжение [FRONT_SCREEN_BODY.md](FRONT_SCREEN_BODY.md).
Исходный EXE: `3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c`;
MSVCR80 8.0.50727.6195: `c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d`.

## Граница и происхождение состояния

Исследуемый участок — `4275cb..42790f`. Выходы: `427915` в главное меню,
`427ca7` к остальным selectors, `42873e` в общий presentation tail.
Он выбирает ветвь по **EAX вызывающего кода**, а не по новому чтению `44d064`.
EBX=0, EDI — поверхность, переданная исходным caller. Пробы с разными EAX и
`44d064` отделяют эту зависимость от обычного случая равных значений.

Источник заново исполняет World constructor, раннюю загрузку 24 UI wrappers,
чтение оригинального control.txt, первый prefix с фоном, updater4236d0 и
тело42712c. Всё остаётся на одном CPU/стеке; первый естественный EAX=0 ведёт
сразу в427915. Последующие позиции мыши, нажатия, selectors, таймеры, состояния
worker, FILE и ответы устройств — явно предоставленные входы. Повторные
вызовы анимации сохраняют globals; между ними presentation tail не исполняется.

Native заново строит и проверяет тот же родитель через
`FrontScreenBodyReference.onNatural`, затем продолжает **своё** состояние.
Ожидаемые снимки после операций не подставляются в native. Сохраняются World,
все25 уже загруженных bitmap и192 байта caller stack с масками. Адрес drawTarget
в stack+20 — входной сырой token; его чтение не делает маску инициализации true.
Только известное поле bitmap+0 нормализуется в1/0, прочие указатели остаются сырыми.

## Selector −3: панель настроек

`4511f4` хранит состояние анимации. При0 локальный EBP становится96, сама
глобальная переменная остаётся0. Иначе исходный код считает:

```
t = Int32(y + 90)                       // переполнение32бит
high = high32(Int64(-715827883) * t)     // signed imul
y = Int32(y + high + (UInt32(high) >> 31))
4511f4 = y
```

Это перенесено буквально, с сохранением порядка и переполнений. Первые рисунки:
`4511a0` при(155,y), frame1; `451188` при(75,y+100), frame0.

| Область | Hitbox | Рисунок |
| --- | --- | --- |
| Включить | `UInt32(x−209)<=233`, `y+174<mouseY<y+203` | (209,y+174), frame3 |
| Выключить | `UInt32(x−465)<=87`, те же строгие границы Y | (465,y+174), frame4 |
| Раскрыть описание | Только при4511f4=0; `UInt32(x−203)<=358`, `y+240<mouseY<y+262` | **(202,y+240)**, frame5 |

Новый клик требует44d060=0 и457580=1. Включение: held=0,450be8=1,
**полный423230 через caller427688**, selector=0,4511f4=0, звук455610,
полный4237e0/43c450. Выключение: held=0,450be8=0, **полный423230 через427704**,
selector=0,4511f4=0, звук455614. Worker при выключении не вызывается.
Локальный y после обнуления4511f4 не меняется: последующий рисунок всё ещё
использует позицию текущей анимации. Это отдельно проверяют animated-choice пробы.

Раскрытие очищает held, задаёт4511f4=−17 и проигрывает455614. При нулевом
состоянии окончание — frame1 в(75,y+261). При ненулевом — frame2 в(75,y+262),
затем frame1 в(75,y+542). Все эти выходы ведут в42873e.

## Общие дочерние обработчики

Bitmap43f010 и clip43ef70 исполняются до реального Blt/ret24; native использует
существующий `OriginalBitmapDrawing` на тех же загруженных ресурсах.
Sound401a30 продолжает три вызова COM даже при ошибочных HRESULT.

Сохранение использует [общий writer](SETTINGS_WRITING.md) с реальными
VC80 fprintf/fclose, включая промежуточные globals/FILE/buffer. Файл на диске
не изменяется: fopen, descriptor write/close — наблюдаемые границы.
Буферы1/7/64/4096, A5/ramp, короткая/ошибочная запись и close−1 предоставлены явно.
Ошибки вывода не отменяют предусмотренные оригиналом последующие действия.
Null FILE останавливает источник **до423260**, с уже изменёнными held/450be8,
до сброса selector/анимации, звука и worker. Это не безопасный false-return.
Child entrySP=1000effc, нормальный возвратSP=1000f000; null FILE SP=1000efdc.

`OriginalMenuWorkerRequest` выделен из раннего prefix и используется обоими
настоящими callers. Gate допускает44d788=−99, первые четыре байта даты `now\0`
или unsigned-byte CString4527b0<=451d48. Enter4554a4 → read458424 → Leave;
только status0 запрашивает CreateThread43c240. Null handle вызывает GetLastError.
Worker body и конкурентное изменение globals остаются внешними границами.
43c450 достигается tail jump из4237e0: оба helper имеют returnPC4276a9.

## Selector −1: ожидание

Сначала45117c рисуется в(258,205), frame5. Если младший бит байта4511f0 сброшен,
код делает **DWORD OR1**, вызывает timeGetTime и сохраняет4511ec. Ещё один вызов
таймера выполняется всегда. При unsigned разности `now−4511ec > 150`:

1. Увеличить4511e8 с переполнением32бит, взять **signed remainder14**.
2. Снова вызвать таймер и записать именно этот ответ в4511ec.

Для положительного4511e8 исполняется столько415160, сколько задаёт счётчик:
первый x284, шаг20, y290, width5,height12,color577fd7. Никакого clamp к13 нет;
проба с14 и непросроченным таймером действительно рисует14 элементов.
Нативный helper `OriginalSurfaceFilling` пишет только размер100 и color+50
в DDBLTFX; остальные92 байта берутся из наблюдаемого stack backing до вызова,
маски остаются false. Fill flags1000400, target455608; он отличается по
происхождению от EDI для bitmap. Null target останавливается до4151b6.

Cancel hitbox: `331<=x<482`, `320<=y<346`; highlight frame6 в(331,320).
При новом клике **сначала звук455614**, затем held=0 и selector=0.
Независимо от клика4511e4 увеличивается с переполнением, выход42873e.

## Проверки и воспроизведение

D: оба корпуса заново получены из EXE и сравнены с native до принятия fixtures.
На каждый приходится533 случая,3421 helper returns,15955 parent и5552 writer
события;1250 draws,8682 bitmap reads,1247 clips,1200 Blt,674 fills,
85 sounds,512 timer calls и13 worker requests.82 settings calls включают74
возврата и8 null-FILE boundaries;3996 actual fprintf,1326 descriptor writes,
18 коротких/ошибочных записей. Ещё три null-bitmap и один null-fill дают12
остановок до разыменования на корпус. Сравнены31828 records/394472552 bytes/masks.
Итого1066 случаев/63656 records/788945104 bytes/masks. Отчёты:
[основной](../evidence/front-screen-alternate.json),
[control](../evidence/front-screen-alternate-control.json).

Шесть целевых XCTest прошли за20.817с: alternates12.441с, прежнее тело5.935с,
prefix2.441с. Release NTSDNative собран за2.44с. Default-preserving hooks Python
observer отдельно проверены: оба прежних body корпуса полностью воспроизвели
по571 случаю и676 blobs. Все76 прежних fixtures неизменны; raw/packed SHA и
полная распаковка обоих новых проверены. Итоговый pin inventory содержит78 файлов.

Первая native проверка остановилась на чтении stack+20 через API, требующий
инициализированную маску. Это ошибка reference: исходный caller token предоставлен
до наблюдения body, его bytes доступны, а маска намеренно false. Проверка читает
сырые bytes, сохраняя маску; ожидаемые данные не менялись ради прохождения.

Инструменты:

```
uv run tools/oracle_front_screen_alternate.py
uv run tools/oracle_front_screen_alternate.py --control
swift build --package-path native -c release --product NTSDCatalogCheck
native/.build/release/NTSDCatalogCheck --front-screen-alternate build/original/front-screen-alternate.json
native/.build/release/NTSDCatalogCheck --front-screen-alternate build/original/front-screen-alternate-control.json
uv run tools/oracle_front_screen_alternate.py --accept
swift test --package-path native --filter 'OriginalFrontScreen(Alternate|Body|Prelude)Tests'
swift build --package-path native -c release --product NTSDNative
```

Принятие сначала сравнивает **оба** сжатых корпуса с native, затем записывает
fixtures/reports. SwiftPM-команды выполняются строго последовательно.

## Оставшийся объём

Сквозной screen loop, соединение с главным меню и общим presentation tail,
остальные selectors/выбор персонажей, loading/gameplay, device pixels/audio,
реальная файловая запись, worker и Windows ещё открыты. Это общий нативный
обработчик ранних экранов и сравнительная проверка; окно Practice не изменено.
Null draw target, неограниченный no-NUL writer и переполнение границ памяти
сохраняют прежние ограничения соответствующих общих исследований; новый
корпус не объявляет их дополнительным покрытием. Следующий шаг — продолжить
эти живые ранние ресурсы/состояние через427915 и42873e до полного возврата меню.
