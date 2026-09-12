# Сохранённые поля bitmap между War menu и подготовкой

Приняты в указанной семантической границе два
сохранённых normal returned вызова s10/00 и s11/00; девять source faults остаются
отдельными исходами. Полная нативная игра и первый полный матч ещё не приняты.

## Вопрос и эталон

При отказе GetObject или surface description оригинал иногда использует поля,
записанные предыдущими вызовами. Нужно восстановить их собственное время жизни
в Native, сохранив размеры bitmap, последовательность API, владельцев арены,
запись повтора и общий откат War/внешнего меню.

Использованы только готовые результаты закреплённых NTSD EXE/lib/VC80 в
контролируемой Unicorn-среде, CW023f, C locale и с объявленными API responses.
Это не реальная Windows, куча или графическое устройство. Новый EXE/DLL,
эмулятор, producer, capture или исторический auditor не запускались.

Опора — [инвентаризация ошибок](LIB_WAR_PREPARATION_ERRORS.md),
[preflight](LIB_WAR_PREPARATION_NATIVE_PREFLIGHT.md),
[матрица](LIB_WAR_PREPARATION_MATRIX.md) и независимый сохранённый review
`build/research/lib-war-preparation/war-music-errors-native-20260912/next-boundaries-review.json`.
Полный план, две поправки, кандидаты и проверки находятся в
`build/research/lib-war-preparation/war-retained-scratch-native-20260912/` на X5.
Исходный `plan.json` остаётся неизменным.

## Собственные производители и потребители

В accepted bound0001 `war-ready`, последнем BATTLETROOPS:

- Stores363/364 от memset собственного CreateSurface descriptor задают
  descriptor[72..<80]. Они становятся loader width/height при подготовке.
- Store417 записывает объявленный getDC#13.output, store418 — его result.
  Эти слова становятся copy height/width при подготовке.

До производителей все 16 исходных байт A5/unknown. Prefix0002..0009 сохраняет
их байты и masks. API output производится счётчиком собственных запросов,
`37000000 + 16 × ordinal`; значение не задаётся как размер изображения.
Native получает descriptor и ответ платформы от собственных операций.
Исходные stack bytes и ожидаемые after-state не служат входами Native.

Menu loader/copy и preparation loader/copy имеют разные подтверждённые глубины
вызывающего кода. Поэтому новый preparation GetDC не заменяет прежнее поле,
которое в этом месте читается как copy height. Следующие собственные GetObject
и description writes обновляют те же canonical fields между constructors.
Current-helper request masks остаются неизвестными до фактических writes,
независимо от уже определённых lifetime fields.

`OriginalWarMenuMemory.bitmapScratch` содержит два семантических поля по восемь
байт с масками. Они входят в общую транзакцию War и внешнего caller. Прямые
публичные bitmap load/copy/construct по-прежнему начинают с unknown scratch.

| Случай | Объявленный ответ | Наблюдаемый эффект |
| --- | --- | --- |
| s10/00 | getObject#27=0, без writes | Wrapper получает 0/0 от прежнего descriptor; copy GetObject получает реальные 384/383 |
| s11/00 | description#14=-1, без writes | Wrapper остаётся 384/383; Stretch destination использует прежние GetDC output/result |

Оба вызова возвращаются нормально, создавая по пять живых wrappers. Сравнение
сохраняет 2 638 whole-caller events, 150 graphics API requests и 32 numeric
checkpoints, полные собственные записи/маски, globals, recording и owners.
Две Native-цепочки выполняют по десять prefix calls; это 20 исполнений,
перекрывающих десять ранее принятых исходных случаев.

## Граница после загрузки арены

Первоначальная гипотеза о сохранении loader field до outer return оказалась
неверной. Независимый review и первый кандидат обнаружили следующий producer:
preparation music форматирует `%s\graph.log`. Stores14099/14100 заменяют
loader bytes аргументом/адресом возврата sprintf; поздние stores14442/14443 —
аргументом/адресом возврата RenderFile. Эти исходные bytes/masks остаются
известными private ABI. Их нельзя импортировать как собственные размеры bitmap.

Наблюдаемая граница — whole event920/bodyMusic14 `.format`, после helper401da0.
`resumePreparationMusic` в Core завершает семантическое loader lifetime именно
на этом фактическом запросе, выставляя явный marker и убирая доступные размеры.
Пути без форматирования, включая пропущенную и кэшированную музыку, сохраняют
поля. Copy field [9,37] остаётся сопоставимым до outer return.

Новая проверка сравнивает 16 байт через prefix и каждый из десяти arena
constructor returns в двух успешных вызовах; вместе с повторениями в rollback
trials выполняются 40 таких сравнений. После format проверяется окончание loader lifetime,
явный marker и сохранённые known source masks; copy bytes/masks продолжает
сравнивать полностью. Это не совпадение с восемью поздними private ABI bytes.
Сохранённый аудит не находит dimension consumer после музыки до возврата
в выбранных двух случаях; пересекающиеся CRT reads принадлежат самому sprintf.

Поздний GetObject без новых writes или с неполными полями отвергается Native
с откатом; полный собственный metadata output восстанавливает размеры.
Отсутствующее изображение сохраняет marker и отсутствие поля после двух
попыток загрузки. Следующий исходный consumer музыкальных ABI words остаётся
отдельной неподдержанной границей; этот контракт не моделирует частный стек.

## Проверка и сохранность

Объявлены десять связанных rollback trials: два поздних menu producer events
(38/773), два выбранных graphics API events (811/818), format (921 в обоих),
recording и outer beforeReturn для обоих случаев. Семь дополнительных Native
guard controls проверяют no-op/disabled/cached music, отсутствие изображения,
отсутствующие/частичные metadata и полное восстановление восьми байт/масок.
Это дополнительные Native-проверки, не новые совпадения с оригиналом.

Первый кандидат скомпилировался, но получил 60 ошибок позднего loader comparison
за 17.370с. Ошибочная гипотеза, candidate1, план и лог сохранены. Второй кандидат
прошёл raw за 17.681с/build278.82с; reviewer затем уточнил инвариант отсутствующего
изображения. Candidate2 и его результат также сохранены. Expected не менялись.

Финальный candidate3: raw прошёл за 17.523с/build281.21с. Семь bundled War-тестов прошли за 389.629с, десять shared-тестов — за 477.643с; всего 17 уникальных bundled методов. На одном frozen candidate проверены matrix256/preflight22, все прежние error cards, direct bitmap unknown-field rejections, общие menu tests и 574+192+40 War setup calls. Raw override в bundled запуске отсутствует. Все пять фактически начатых Native jobs терминальны; первый диагностический отказ сохранён отдельно.

Два lossless transports занимают 9 564 884 bytes и восстанавливают
71 386 144 исходных bytes, весь JSON и все 1 436 blob entries; 721 blob уникален.
Проверены 20 normalized/raw prefix links. Все 34 source pins и 359 прежних
fixtures сохранены; текущий Native содержит 361 fixture и 808 регулярных файлов.

Архив Native (3989606400 bytes) содержит ровно 808 проверенных файлов. Архив доказательств (231127040 bytes, 115 members) сохраняет исходные данные, prefix producers, планы/поправки, прежние изменённые кандидаты и терминальные результаты. Все members прочитаны и сверены; staged Git blobs совпадают с финальным Native manifest. [Машинная приёмка](../evidence/lib-war-retained-scratch.json).

Три прежних safety incidents остаются открытыми. Заблокированные операции не
повторялись; новая Native-карточка их не разрешает и не закрывает.
Полный error corpus, собственные startup/catalog/library/outer loop/app,
43a860 gameplay, все матчи/содержимое/сеть и Windows/device/clean-Mac проверки
остаются отдельными задачами. Следующая карточка — девять Native rejections
с полным rollback по сохранённым source faults; они не считаются matches.
