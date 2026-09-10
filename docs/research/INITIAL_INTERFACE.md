# R02.1 / R13 / R15 — изображения интерфейса после загрузочного пула

Эталон — исходный EXE, SHA-256
`3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c`.
Восстановлен участок `41c2f5..41c581` и весь конструктор bitmap
`43ee50..43ef41`, включая сообщения ошибок и освобождение поверхности.
Новый корпус выполняет этот участок непосредственно после настоящего
[создания пула](BOOTSTRAP.md) `41c052..41c2f5`.

Это часть первой загрузки, которая нужна перед полным World=2. Сброс
`44d05c` теперь получается из исходного порядка операций. Сам по себе этот
участок ещё не соединяет звуки, каталог, ввод и меню в непрерывный запуск.

## Ресурсы и порядок

Это имена встроенных DIB-ресурсов EXE, а не пути внешних BMP. Проверены
исходные bytes/SHA-256 и размеры каждого DIB. Язык всех десяти —1028.

| № | Ресурс | Размер | Global bitmap pointer | Call43ee50 |
| --- | --- | --- | --- | --- |
| 0 | PAUSE |84×23| `44ff8c` | `41c31b` |
| 1 | DEMO |84×23| `44f8f8` | `41c35e` |
| 2 | SCORE_BOARD1 |490×61| `44fcb4` | `41c39e` |
| 3 | SCORE_BOARD2 |490×45| `44fd8c` | `41c3de` |
| 4 | SCORE_BOARD3 |490×32| `44f88c` | `41c41e` |
| 5 | SCORE_BOARD4 |490×45| `44f87c` | `41c45e` |
| 6 | WIN_ALIVE |53×11| `44fd90` | `41c49e` |
| 7 | WIN_DEAD |53×11| `44fd94` | `41c4de` |
| 8 | LOSE_DEAD |53×11| `44fb64` | `41c51e` |
| 9 | BARS |150×51| `44fd7c` | `41c55e` |

Для каждого ресурса caller запрашивает `0x1f50` байт. Ненулевой malloc
вызывает общий конструктор с flags=`0x40`, optional=0. Нулевой malloc
пропускает конструктор и записывает0 в соответствующий global. Остальные
ресурсы всё равно загружаются. Прежний global pointer на этом пути не
освобождается: caller просто заменяет его новым результатом.

Последняя запись pointer выполняется в `41c572`, затем **`41c577` безусловно
записывает `44d05c=0`**. Это верно и при недоступных ресурсах, ошибке
SetColorKey или нулевых аллокациях. Ошибка отдельного bitmap не является
условием продолжения/отмены этого прохода.

## Общий конструктор43ee50

`this` указывает на wrapper размером8016 байт. Конструктор копирует имя
в локальную строку и запрашивает `43ed10(device457578, flags, 0, &width,
&height)`. Байты имени передаются через EDI. В данном исследовании43ed10 —
явная граница загрузки устройства; её внутренние файловые/DirectDraw пути
не исполняются. Размеры предоставляются из оригинального DIB.

При наличии поверхности wrapper получает raw surface pointer в+0,
width/height в+4/+8. Остальные8004 байта сохраняют исходные байты и маску.
Затем конструктор вызывает метод поверхности+74: SetColorKey с flags8
и двумя нулевыми UInt32 ключа. Проверяется **знак HRESULT**:0 и положительные
значения продолжают обычный возврат; любой отрицательный результат:

1. Запрашивает MessageBoxA с текстом `Couldn't set the color key.` и title Error.
2. Запрашивает OutputDebugStringA с тем же текстом и LF.
3. Вызывает surface Release(+8), игнорирует его результат.
4. Обнуляет только wrapper+0. Уже записанные размеры сохраняются.

Если43ed10 вернул null, +0 получает0; width/height остаются нетронутыми.
При optional=0 следуют MessageBoxA `Couldn't create art surface.` с именем
ресурса в title и соответствующий OutputDebugStringA с LF. Release здесь нет.
Конструктор всё равно возвращает адрес wrapper, поэтому global остаётся
ненулевым. Возвраты MessageBoxA/OutputDebugStringA не управляют продолжением.
В данном caller optional всегда0. Исторические optional-mirror случаи
сохраняются в проверках Object loader; новый корпус не расширяет их домен.

Возврат проходит настоящий `ret12` и проверку cookie. Сохраняются
EBX/EBP/ESI/EDI; EAX равен this. В первом конструкторе ESI ещё содержит
catalog[0], в следующих —ffffffff после исходного `41c324`.

## Нативная модель и сравнение

[OriginalInitialInterfaceLoading.swift](../../native/Sources/NTSDCore/OriginalInitialInterfaceLoading.swift)
содержит caller и общий `OriginalBitmapConstructor`. Записи wrapper строятся
через общий `OriginalLoadedBitmap.constructionStorage`, используемый также
прежними Object/BG loaders. Их прежний контракт отсутствующего обязательного
ресурса сохранён; новый constructor переносит исходные сообщения/возврат.

Global pointers сохраняют явно предоставленные UInt32 allocation tokens.
Только поле surface+0 нормализуется в1/0 после проверки фактического pointer.
Остальные байты/маски не нормализуются. `input.present` описывает результат
43ed10; после ошибки SetColorKey input остаётся present, но **storage+0 уже0**.
Потребителю поверхности нужно учитывать её текущее состояние.

Native сначала вызывает прежний `OriginalWorldBootstrap`, затем общий новый
caller. Ожидаемые записи EXE не используются как входы native. Сравниваются:

- Полные globals после каждой из десяти записей и после сброса44d05c.
- Все выделенные wrappers, их нетронутые байты и masks; oracle также проверяет guards.
- Все400 Actor и World после UI-прохода, с прежними доказанными ordinal bindings.
- Порядок malloc/constructor/load/COM/OS requests, размеры, строки, ret12 и registers.

13 сценариев: четыре шаблона памяти × два размещения; все/чередующиеся null
bitmap allocations; недоступность всех ресурсов; ошибки всех SetColorKey;
смешанные отказы. Успешные HRESULT включают0,1 и7fffffff. Второе размещение
меняет адреса и физический порядок Actor и bitmap. Исходные DIB не изменяются:
отказы задаются на границе устройства/allocator.

Release-сравнение перед принятием fixture: **114 bitmap constructors,
5304 Actor constructors,5470 записей,13029720 байт/масок,519 событий**;
16 null allocations,23 MessageBox и12 Release. Каждый из13 проходов достигает
41c581 с44d05c=0. В этой точке ESP равен исходному1000f000, а EDI восстановлен
из supplied local+38. Это граница внутри функции, не её полный возврат.

Raw corpus SHA-256:
`5d9d32e14628c7b9298bf5e57aa1ff7bf3d64046b2cd1af5b0315263feb90089`.
Packed fixture SHA-256:
`be6051502123296f2d3f8242f81b010f6847ee34767ff6e64a643bab4433af88`
(578668 байт). Полные DIB и записи сохраняются с lossless DEFLATE.

Шесть выбранных XCTest прошли за137.528s: новая проверка3.917s, два прежних
bootstrap tests1.681s и три полных catalog tests131.930s. Последние проверяют
общую запись bitmap в исходных Object/BG и interleaved-контроле после её
выделения в constructionStorage. Release-сборка NTSDNative прошла за2.24s.
Все прежние fixtures сохранились без изменений; полного тестирования игры
или подключения нового пути к Practice эти результаты не означают.

Артефакты: [oracle_initial_interface.py](../../tools/oracle_initial_interface.py),
[InitialInterfaceReference.swift](../../native/Sources/NTSDReferenceChecks/InitialInterfaceReference.swift),
[initial-interface.json](../evidence/initial-interface.json).

```sh
uv run tools/oracle_initial_interface.py
uv run tools/oracle_initial_interface.py --accept
swift test --package-path native --filter '(OriginalInitialInterfaceTests|OriginalLoadedCatalogTests|OriginalBootstrapTests)'
```

## Следующий участок и границы

Соединить [18 общих звуков](WAVE_LOADING.md), полный каталог, этот пул и UI
в исходном первом проходе41bc90. [Enabled catalog sounds](CATALOG_SOUNDS.md)
теперь выполняет общий WAV loader из Frame/weapon registry и SetVolume(-10000)
в одном полном каталоге. Прежний disabled corpus остаётся отдельным;
непрерывный первый41bc90 ещё не проверен.

Здесь catalog[0]/Object+90 и внешний frame предоставлены как входы; настоящая
загрузка каталога не подменяется, а остаётся перед границей данного корпуса.
Prologue41bc90, ввод/пауза и дальнейший путь к429730 ещё не соединены.
43ed10, COM/OS outputs, allocator и memset — платформенные границы. Пиксели,
реальный DirectDraw/Windows, звук, игровой матч и чистая macOS не доказаны.
В окно Practice этот новый путь пока не подключён.

The newer [bitmap surface loader](BITMAP_SURFACE_LOADING.md) separately implements
whole43ed10/4013d0 and composes them in the own front-resource path. It preserves
dimensions written before failed CreateSurface, which the older explicitly
supplied image-result boundary here did not exercise. This corpus is unchanged;
its callers do not automatically acquire the newer own loader composition.
