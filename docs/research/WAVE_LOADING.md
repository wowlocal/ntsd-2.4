# R02.1/R14 — WAV loader и общие звуки при первой загрузке

Эталон EXE: SHA-256
`3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c`.
Исследование восстанавливает `4014e0..40195e` и загрузочный caller
`41be98..41bfeb`, который вызывает его для18 общих звуков. Это общий
загрузчик PCM, без обработчиков по персонажам. В нативное игровое окно
новый путь пока не подключён; микшер и выход звука здесь не проверяются.

## Почему этот участок нужен перед полным World=2

В [MENU_PRESENTATION.md](MENU_PRESENTATION.md) переход World=1→2 уже получается
из реального диспетчера. Но `44d05c` в тех корпусах остаётся1, включая снимок
после подготовки/recording. В первом настоящем `41bc90` эта единица выбирает
загрузку `41be98..41c581`:18 звуков → каталог →400 Actor →10 bitmap интерфейса.
Поэтому предыдущий снимок всё ещё нельзя считать полным состоянием перед
тактом. Нельзя просто сбросить этот флаг для обхода загрузочного прохода.

Этот этап закрывает WAV helper и первую часть caller до аллокации каталога.
Каталог/пул ранее сравнивались отдельно. Последующие10 bitmap теперь проверены
в [INITIAL_INTERFACE.md](INITIAL_INTERFACE.md); соединение всей инициализации
в настоящем `41bc90` остаётся открытым.

## Границы исполнения

| Участок | Что исполняется и сравнивается |
| --- | --- |
| `4014e0..40195e` | Все обычные инструкции загрузки, формат/descriptor, копирование, очистка и ret4/cookie |
| `4014f4..401523` | Отсутствующий audio device: return1 без записи destination и без file IO |
| `401526..401798` | WinMM caller, сообщения ошибок, payload allocation, включая утечку при short read |
| `40179e..401942` | Построение WAVEFORMATEX/DSBUFFERDESC, create/lock/restore/copy/unlock/free |
| `40185c..40187a` | Ошибочный CreateSoundBuffer: сообщение и free, остановка перед опасным продолжением |
| `41be98..41bfeb` | Draw request, очистка двух массивов,18 настоящих вызовов WAV loader, count18, настоящий43e940 |

`mmioOpen/Descend/Read/Ascend/Close`, COM, MessageBoxA и malloc/free/memcpy
имеют явно предоставленные платформенные границы. WINMM и DirectSound DLL
не исполняются. Внутреннее memcpy заменено побайтным переносом с проверкой
границ и маски; оно не придумывает исходные звуковые данные. Источник PCM —
байты оригинальных файлов, закреплённые SHA-256 в корпусе.

RIFF adapter следует документированным позициям `mmioDescend` и `mmioAscend`:
для RIFF пропускается form type, для обычного chunk позиция указывает на data,
при ascend учитывается padding. Это контракт платформенной границы, а не
доказательство исполнения WINMM в Windows. См.
[mmioDescend](https://learn.microsoft.com/en-us/windows/win32/api/mmiscapi/nf-mmiscapi-mmiodescend)
и [mmioAscend](https://learn.microsoft.com/en-us/windows/win32/api/mmiscapi/nf-mmiscapi-mmioascend).

Домен файлов — полные ограниченные RIFF chunks исходного набора и указанные
контроли. Переполненные/оборванные chunk extents не объявляются совместимыми
с WINMM: нативный adapter отклоняет их как не исследованные. Payload ограничен
2MB в этой проверке; максимальный исходный файл меньше этого предела.
Поведение MMIO при произвольной порче файла, seek errors и реальный OS IO
остаются отдельными задачами. EXE/Unicorn не входят в runtime приложения.

## Восстановленные правила

`this` — адрес32-bit destination slot, а `44eecc` — audio-device pointer.
При отсутствии устройства helper возвращает1 и сохраняет destination.
При наличии устройства destination сначала получает0. Старый buffer не
освобождается этим helper: на данном участке нет такого Release.

Open запрашивает flags10000 с null MMIOINFO. При нулевом handle показывается
`Could not Open Wave File <path>`, с path в заголовке, затем return0.
Остальные сообщения имеют null title. Возврат MessageBoxA не проверяется.

Порядок поиска и чтения:

1. Descend с FINDRIFF20, form=WAVE.
2. Следующий Descend получает ckid=`fmt `, но **flags=0**. По контракту API
   это спуск в следующий chunk, а не поиск fmt. Контроль JUNK с PCM-подобным
   payload поэтому проходит этот участок; имя chunk EXE дальше не проверяет.
3. Read запрашивает ровно18 байт. Даже у100 исходных файлов с fmt-size16
   чтение захватывает следующие2 байта файла. Требуется возврат18 и tag=1.
4. Ascend возвращает позицию к концу format chunk с padding.
5. Descend FINDCHUNK10 ищет `data`, затем выделяется ровно data.cksize байт
   и Read запрашивает этот размер. Все409 исходных WAV — PCM; у309 fmt-size18.

Read читает заданное число байт файла, а не автоматически ограничивается
размером текущего chunk. Позиции на границе исходных fmt16 учитываются в
корпусе. Контракт:
[mmioRead](https://learn.microsoft.com/en-us/windows/win32/api/mmiscapi/nf-mmiscapi-mmioread).

Любой ненулевой Descend/Ascend result — ошибка. Format read с результатом,
отличным от18, или tag, отличный от1, закрывает файл, показывает сообщение
и возвращает0. Short/failed data read также закрывает файл и возвращает0,
но **не освобождает уже выделенный payload**. Нативный результат сохраняет
эту live allocation и все её bytes/masks, включая частично прочитанные данные.
Результат mmioClose игнорируется; проверены отрицательные ответы.

### Формат и создание буфера

Выходной WAVEFORMATEX получает tag1, channels, samples/sec, avg bytes/sec,
block align и bits/sample из первых16 прочитанных байт. Следующее поле
`cbSize` не обнуляется и не копируется из файла. Оно перекрывается с ранее
сохранённым `this`: запись `401503` соответствует local+44, а выходной формат
начинается с local+34. Поэтому последние2 байта равны **low16(destination)**
и имеют определённую маску. Это не неизвестный stack padding и не основание
нормализовать их в0. Проверены в том числе low words0000/ffff и невыравненный
destination. PCM API игнорирует cbSize, что отдельно описано в
[WAVEFORMATEX](https://learn.microsoft.com/en-us/windows/win32/api/mmreg/ns-mmreg-waveformatex).

DSBUFFERDESC целиком содержит36 определённых байт: size24, flagsE0,
data size, указатель на построенный формат; остальные поля0. Только этот
целый format pointer нормализуется в0 после проверки его точного stack address.
Перекрывающееся поле внутри WAVEFORMATEX сохраняется побайтно.

CreateSoundBuffer получает null outer unknown. **Любой ненулевой** результат,
включая положительный1, показывает `Could not Create Sound Buffer.` и
освобождает payload, но EXE затем всё равно переходит к Lock. Обычного return0
на этой ветви нет. Корпус останавливается в40187a до разыменования результата
и дальнейшего чтения освобождённой памяти. Native возвращает отдельную
`invalidCreateContinuation`, не выдавая этот путь за успешную загрузку или
обычную обработанную ошибку. Это явная граница переноса данного отказа.

### Lock, Restore и копирование

Lock(+2c) получает offset0, полный data size, flags0 и четыре выходных поля.
Только точный HRESULT88780096 вызывает Restore(+50), затем второй Lock с теми
же входами. Restore result и окончательный Lock HRESULT **не проверяются**.
Контроли других ошибок предоставляют валидные output pointers/lengths явно;
это проверки ветвления EXE, а не обещание таких outputs от реального устройства.

Сначала копируется firstCount байт. При ненулевом second pointer дополнительно
копируется secondCount байт, источник начинается с payload+firstCount.
Проверены единая/разделённая область, нулевой первый размер и ненулевой
second pointer с нулевым размером. Результат Unlock(+4c) игнорируется.
После Unlock payload освобождается, destination получает buffer pointer,
helper возвращает1. Обе области, временная live/dead allocation, guards,
format/descriptor и masks сравниваются целиком; samples не преобразуются.

## Реальный загрузочный caller

`41be98` запрашивает bitmap45118c в(0,0), frame=-1, flags/mirror0.
Затем `rep stosd` обнуляет1600 байт457588 и320 байт453e10.
Последовательно загружаются18 фиксированных ресурсов в451db0+4*i:

`001, 002, 006, 010, 011, 004, 016, 017, 020, 021, 025, 032, 033, 039,
065, 066, 068, 085` из `data\NNN.wav`.

Этот список находится в EXE; он не выведен из имён персонажей. Загрузчик
один и тот же для каждого файла. Caller игнорирует обычные return0/1,
после всех вызовов ставит `45843c=18` и вызывает настоящий43e940.
Нативный caller использует общий `OriginalMenuPresentation.presentSurface`.

Три прохода покрывают present modes1/2/3, включённое/отключённое устройство
и один недоступный файл среди доступных. При отключённом устройстве все18
destination slots остаются прежними, count всё равно18. После отдельного
open failure caller продолжает следующие загрузки, оставляя соответствующий
slot0. Проверяются полные globals после каждого настоящего дочернего ret4,
порядок всех событий,18 distinct destination tokens и неизменность остальных
полей, в том числе **44d05c=1**.

Вход41be98 и target surface пока предоставлены как bounded context; полный
prologue41bc90/очередь паузы до него ещё не исполнены. Конец41bfeb — перед
аллокацией каталога. На стеке остаётся аргумент present: ESP=inputESP-4;
cleanup произойдёт после следующего malloc в41bff5. Не заменять эту границу
полным возвратом функции. Каждый вложенный WAV helper уже проходит реальный
ret4/cookie и сохраняет EBX/EBP/ESI/EDI.

## Артефакты и следующий шаг

Release-сравнение прошло перед принятием нового fixture:409 исходных файлов,
431 изолированный случай,3 загрузочных прохода /54 настоящих дочерних вызова,
75829038 байт/масок и6982 события. Включая caller:93 Restore,13 сообщений,
2 сохранённые аллокации при ошибке чтения и2 остановки на invalid create
continuation. В поле `events` читаемого отчёта6390 событий отдельных вызовов;
ещё592 находятся в трёх загрузочных проходах полного корпуса.

Raw corpus SHA-256:
`393f49749477bdd8e7d97058b32451deb1a3f9cfd6b512b44f6536936fcac89d`.
Packed fixture SHA-256:
`d4094d7b92490a66702532fe305560f1c17dfd0f9705bde50e7660f813aac8b6`
(48367340 байт). Упаковка сохраняет полные байты и маски; SHA каждого
внутреннего blob проверяется перед сравнением.

Два выбранных XCTest прошли за150.419s: новый корпус21.556s и историческая
цепочка MenuPresentation128.863s. Второй тест проверяет извлечение общей
функции43e940, включая прежние меню/подготовку/запись. Это целевая проверка
затронутых путей, не повтор всей игровой проверки. Release-сборка NTSDNative
прошла за2.30s. Все исторические fixtures остались без изменений.

- [oracle_wave_loader.py](../../tools/oracle_wave_loader.py): все исходные WAV,
  control responses, RIFF adapter и настоящий caller.
- [OriginalWaveLoader.swift](../../native/Sources/NTSDCore/OriginalWaveLoader.swift):
  общий формат, ownership и копирование до device boundary.
- [OriginalInitialSoundLoading.swift](../../native/Sources/NTSDCore/OriginalInitialSoundLoading.swift):
  фиксированный caller, shared wave/present methods и исходные globals.
- [WaveLoaderReference.swift](../../native/Sources/NTSDReferenceChecks/WaveLoaderReference.swift)
  и [wave-loader.json](../evidence/wave-loader.json): сравнение полных записей,
  источник каждого файла, SHA и упорядоченные события.

```sh
uv run tools/oracle_wave_loader.py
uv run tools/oracle_wave_loader.py --accept
swift test --package-path native --filter '(OriginalWaveLoaderTests|OriginalMenuPresentationTests)'
```

Следующий отдельный этап уже восстановил [10 интерфейсных bitmap](INITIAL_INTERFACE.md)
после реального пула: первый malloc в41c2f5, последний constructor в41c55e,
сброс флага в41c577. Далее соединить prefix/каталог/пул/bitmap в исходном
загрузочном пути. Перед этим связать звуки Object registry при включённом
устройстве с общим WAV loader: текущий полный catalog corpus использует
disabled audio boundary.
Фазы ввода/меню41bc90, реальный микшер/устройства, Windows execution и проверка
готового приложения на чистой macOS остаются открытыми.
