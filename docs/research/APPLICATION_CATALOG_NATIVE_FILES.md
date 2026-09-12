# Собственные файлы и общий загрузчик каталога

Карточка завершения сохранённых Native-изменений, 2026-09-12. Код связывает
существующие DAT/Object/BG/Stage loaders с собственными потоками и общими
владельцами ресурсов. Проверяемая граница — порядок загрузки, файловые байты,
возвраты дочерних loaders и откат кандидата при ошибке наблюдателя.
Полный собственный каталог и возврат приложения остаются открытыми.

Работа использует только сохранённые результаты. Оригинал, CRT и Unicorn
заново не исполняются. План, исходный dirty-срез и журналы текущей проверки:
[pending-completion-20260912](../../build/research/pending-completion-20260912/).
Порядок приёмки задаёт [WORKFLOW](WORKFLOW.md).

## Контракт Native

[OriginalLoadingFiles](../../native/Sources/NTSDCore/OriginalLoadingFiles.swift)
владеет raw/logical input, текущей позицией, EOF, output/pending bytes,
последовательностью потоков и содержимым временного файла. Token и buffer —
объявленные идентификаторы стенда, не указатели в память macOS и не структура
Windows `FILE`. В same-CPU файловых проекциях ёмкость 65 536 и read limit
4 096 передаются явно; это не универсальные параметры остальных стендов.

DAT `4148a0/414a30` пропускает полный 123-байтный заголовок, использует общий
декодер и закрывает input перед последней выгрузкой output. Перевод CRLF
сохраняется отдельно от декодирования. Возврат output close сохраняется в
`decoderReturns`; заявленные `0` и `-1` не превращаются в Native exception.

Object `40ef70` и BG `40c160` выбирают encrypted/plain input по восстановленной
ветке имени. Stage `40c910` всегда декодирует фиксированный `data\stage.dat`.
Parser читает собственный произведённый текст; продвижение scanner вызывает
чтения живого потока. Cleanup записывает `Do not erase this file.` и закрывает
его. Expected temporary bytes используются только для сравнения результата.

[OriginalLoadedCatalog](../../native/Sources/NTSDCore/OriginalLoadedCatalog.swift)
соединяет эти операции в `loadWithFiles`: сохраняет порядок registry/children,
checksum, sound cache, bitmap/Frame/weapon allocations и final Stage cleanup.
Каждая строка weapon path получает отдельное `strlen+1` хранилище с NUL;
замена поля сохраняет предыдущие выделения у Object. Повторный путь не даёт
основания объединять владельцев. Полные байты и masks сравниваются отдельно.

Observers передают последовательность progress, checksum, sound, message,
scanner и overlay store в существующую композицию. Они не поставляют Native
expected after-state или неизвестную private storage. Файловая транзакция
публикуется после её завершения; вызывающий код также обязан стадировать
внешние ресурсы и эффекты observer до общего commit. Откат такой транзакции
не означает возможность отменить произвольный уже выполненный внешний IO.

## Состав завершения

Исходные 16 pending-файлов распределяются так:

| Область | Файлы |
| --- | --- |
| Потоки и loaders | `OriginalLoadingFiles`, `OriginalDATDecoder`, `OriginalFrameLoader`, `OriginalObjectLoader`, `OriginalBackgroundLoader`, `OriginalStageLoader`, `OriginalCatalogRegistry`, `OriginalLoadedCatalog` |
| Существующая композиция наблюдений | `OriginalLibLoadingProgress`, `OriginalRegisteredSoundLoading`, `OriginalMenuPresentation` |
| Reference checks | `LoadedCatalogReference`, `ObjectReference` |
| Retained приложение | `OriginalApplicationLoadingPrefixTests` |
| Сохранённые producers | `oracle_application_catalog_file_failure.py`, `oracle_application_catalog_close_failure.py` |

Новые постоянные проверки находятся в
[OriginalLoadedCatalogFilesTests](../../native/Tests/NTSDCoreTests/OriginalLoadedCatalogFilesTests.swift)
и [OriginalLoadingFilesTests](../../native/Tests/NTSDCoreTests/OriginalLoadingFilesTests.swift),
общая распаковка — `OriginalLoadingFilesFixture.swift`. Это девять тестов:
три каталога, поздний Stage cleanup, повторный weapon path с откатом,
целый DAT с откатом, Object lifecycle с cleanup rollback, целая файловая
транзакция с поздним отказом и контроль четырёх отрицательных close responses.

## Текущие эталоны и область сравнения

Три прежних полных каталога из [LOADED_CATALOG](LOADED_CATALOG.md) исполнялись
в контролируемом стенде с отдельным CRT scanner. Они не являются собственным
полным запуском приложения. Новые тесты используют `useLoadingFiles=true` и
сохраняют полные прежние game records, дополнительно проверяя file/image order.

| Корпус | Object / BG | Stage / phases | Frames / bitmaps / Frame allocations | Game bytes + masks | File events |
| --- | --- | --- | --- | --- | --- |
| text/a5 | 137 / 17 | 25 / 138 | 15 388 / 829 / 14 586 | 112 063 739 | 1 242 |
| raw/00 | 137 / 17 | 25 / 138 | 15 388 / 829 / 14 586 | 112 063 739 | 1 242 |
| Interleaved/repeated ID | 3 / 2 | 25 / 138 | 720 / 26 / 744 | 82 089 953 | 50 |

Ожидаемые checksum: 31 475 378, 31 461 560 и 1 496 213. Каждый полный проход
сохраняет 130 weapon-path allocations / 1 700 байт; interleaved не содержит их.
Отдельный исходный Object control проверяет два последовательных выделения
одного weapon slot, сохранение обоих хранилищ и поздний rollback.

Файловая проекция nominal probe8 проверяет 25 событий DAT, 72 102 logical
output bytes и 74 271 произведённый temporary raw byte. Object lifecycle
проверяет 49 событий и 23-байтный cleanup. В каждой проекции сохранены все
51 file events с исходными ordinal, пять файлов, decoder, virtual files и
28 связанных blobs. Два внешних события registry предшествуют выбранной границе.
Parser/progress/WAV/output interleaving и private CRT ABI проекция не сравнивает.

Отдельный `file-close-negative1` задаёт четыре ответа `-1`: два read fclose
и два output descriptor close. Native allocator связывает их по исходным
`closeResponses`, file token, path и kind. DAT возвращает `ffffffff`; все
файловые байты и порядок остальных запросов остаются номинальными.
Эти ответы не моделируют произвольную ошибку диска, errno или Windows cleanup.

## Сохранность и публикация

[Упаковщик](../../tools/package_loading_files_references.py) проверяет SHA всех
шести исходных JSON до обработки. Четыре envelope сохраняют полные raw bytes:
три каталога, включая scans/events, и `objects-probe.json`. Два других — явно
ограниченные файловые проекции first Object с исходными raw SHA. Их нельзя
выдавать за транспорт полного Object/caller trace. Старые fixtures не изменены.

[package-verification2.json](../../build/research/pending-completion-20260912/catalog-tests/package-verification2.json)
фиксирует все пути, размеры, SHA и точные DEFLATE roundtrips: шесть файлов,
28 198 719 packed bytes, 200 724 673 raw/projection bytes. Первая проверка и
версии тестов до negative-close сохранены рядом; они не переписаны под новый тест.

Оба pending producer сохраняются как материалы уже выполненного исследования,
без перезапуска: file failure SHA `c647cf431769420aabb8d6f8a109ae12fb1d54778fa618ab05afad1bf3974d11`,
close failure SHA `eb35ac6d01e893fdfc670c78e93aad052fe2269abde0f48d5c04dd35aa91ddc4`.
Reference EXE SHA `3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c`,
VC80 SHA `c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d`.
First-Object проекции сохраняют также SHA lib.dll; среда — controlled Unicorn,
не реальная Windows. Исходные failures, producers, expected bytes и masks неизменны.

## Историческая опора и открытые границы

[Guarded20 evidence](../evidence/application-catalog-guarded20-completion.json)
уже содержит отдельную историческую проверку 20 собственных Object prefixes:
53 566 record comparisons / 59 581 783 bytes+masks, semantic events/globals,
полный trace/final/intermediate/read audit. Private parent registry/ABI там
не принят. Прежние first-Object comparisons трёх родителей и negative-close
сохраняются в [work record](../../build/research/application-catalog-work.json).
Эти результаты не складываются с новыми тремя legacy-каталогами как новая
полнота собственного приложения.

Текущий packaged release-прогон прошёл 40 тестов за 288.070 с, сборка 328.90 с.
После добавления negative-close все четыре файловых теста прошли за 0.549 с,
сборка 142.49 с. Между прогонами изменились только новый тестовый файл и добавленный
fixture; Core и остальные проверки совпадают. Итого 44 исполнения / 41 уникальный
тест, без ошибок и raw overrides. В общий прогон вошли исходные loader/catalog,
sound/loading, scheduler/prefix, bound War preparation и matrix регрессии.
Контракт, новые тесты и транспорт проверены отдельным reviewer; замечание о
постоянном отрицательном close-контроле закрыто. Приёмка и сохранность опубликованы
в [completion evidence](../evidence/pending-native-completion-2026-09-12.json).
NTSDNative связан release-сборкой; это не проверка окна или устройства.

`fileOpenNullEntry` остановлен перед неисполненным `feof(NULL)`; fault там не
наблюдалась. Следующий сохранённый CRT control завершился на неподдержанном
стендом `TlsGetValue`. Native rejection с rollback не совпадение с этим путём.
Полный собственный каталог candidate5 терминален на storage limit после 28 Objects,
не имеет полного возврата; старое слово «running» в evidence описывает прошлое.
Состояние очереди уточняет [CURRENT_WORK](CURRENT_WORK.md). Полные каталог/приложение,
матч, Windows/device/clean-Mac checks и прежние safety incidents остаются открытыми.
