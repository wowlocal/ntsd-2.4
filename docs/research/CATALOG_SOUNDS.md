# R02.1 / R03.1 / R14 — полный каталог с загрузкой звука

Эталон EXE SHA-256:
`3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c`.
Новый корпус соединяет [полный каталог](LOADED_CATALOG.md) и
[WAV loader](WAVE_LOADING.md) в **одном CPU и на настоящем стеке caller**.
`4122f0` вызывает реальные Object/BG/Stage loaders; Frame и weapon paths
вызывают настоящий4014e0, возвращаются к нему и выполняют SetVolume.
Прежние корпуса с отключённым звуком не изменены.

Нативный общий путь использует тот же DAT parser, byte cache и WAV loader.
Загрузчик не содержит обработчиков звука по персонажам. Платформенные MMIO,
DirectSound, allocator и file/CRT границы остались явными; это не запись
выхода Windows и не подключение звука к игровому окну.

## Два caller и общий реестр

| Путь | Индекс и кэш | WAV / дальнейший вызов |
| --- | --- | --- |
| Frame `sound:` | `41097b` сначала пишет index=-1; lookup `41098e..4109f3`; новая запись получает count в410a1e | Call4014e0 в410a48; return410a4d; SetVolume в410a65 |
| Weapon helper40bd90 | Lookup `40bdb0..40bdef`; при совпадении пишет найденный index. Новый index только если destination всё ещё-1 | Call4014e0 в40be18; return40be1d; SetVolume в40be35 |

Оба пути используют count458438, path cache455638 с шагом20 и buffer slots
452948+4*index. После назначения нового индекса:

1. При ненулевом44eecc вызывают WAV helper с адресом соответствующего slot.
2. Полученный buffer получает SetVolume(+3c, **-10000**).
3. Копируют весь путь с NUL в455638+20*index.
4. Увеличивают458438.

При отключённом устройстве пропускаются первые два шага. Cache hit не
загружает WAV повторно и не меняет громкость. У оружия неприсутствующий в
кэше новый путь при прежнем index!=−1 сохраняет этот index и тоже не добавляет
запись; исходная строковая аллокация/поле пути при этом уже заменены caller.
Эта особенность ранее проверена в Object control stream.

SetVolume вызывается **до** копирования пути и увеличения count. Его HRESULT
не проверяется: новый корпус передаёт-1 и выполняет дальнейшие инструкции.
Никакого Release буфера в этих caller нет. Восстановление/копирование PCM и
освобождение временного payload выполняет общий4014e0.

### Повторные пути не равны повторным буферам

Кэш не является словарём уникальных строк. Весь путь записывается без
усечения до20 байт. Например, `data\SNDDATA_0552.wav` занимает21 байт плюс NUL:
следующая запись перекрывает конец предыдущей. Позднейший lookup может больше
не найти исходную строку и повторно загрузить тот же WAV в новый slot.

В полном исходном проходе получены **400 загрузок для365 разных файлов**:
386 Frame calls и14 weapon calls. Повторные загрузки сохраняются вместе с
индексами, полными bytes cache и отдельными device tokens. Объединение этих
буферов только по пути меняло бы поведение реестра.

## Что выполняется и сравнивается

[oracle_catalog_sounds.py](../../tools/oracle_catalog_sounds.py) расширяет
прежний LoadedCatalog. Общий WaveLoader adapter подключается к его Unicorn
instance без пересоздания CPU, подстановки дочернего результата или замены
родительского стека. MMIO/COM stubs имеют отдельный диапазон адресов; hooks
маски стека и контроля инструкций включаются только на время4014e0.
Существующий allocator hook передаёт WAV payload calls тому же adapter.
Сам WAV helper по-прежнему исполняется до настоящего ret4/cookie.

На каждом таком вызове сохраняются path/source SHA, тип caller, Object path,
index, полный cache до загрузки, platform inputs, stack/registers, globals,
format/descriptor, обе области PCM и временная allocation с bytes/masks.
После возврата проверяются все четыре nonvolatile registers и ESP=entrySP+8.
SetVolume должен получить именно результат этой загрузки и-10000 при ещё
неизменённом count. Final buffer array сохраняется целиком.

[OriginalSoundRegistry](../../native/Sources/NTSDCore/OriginalFrameLoader.swift)
назначает index синхронно до `onNewSound`, затем вызывает device часть,
копирует cache path и увеличивает count. Этот callback проходит через общий
Frame/Object loader и OriginalLoadedCatalog. Для прежнего disabled-audio
контракта callback по умолчанию пустой; правила lookup не изменены.

[OriginalRegisteredSoundLoading](../../native/Sources/NTSDCore/OriginalRegisteredSoundLoading.swift)
вызывает OriginalWaveLoader и сохраняет полные результаты по index. При
device0 пропускает helper; при enabled audio передаёт source bytes от provider
и запрашивает SetVolume. Native ссылки — явно предоставленные UInt32 tokens,
никогда не host pointers. Cache commit остаётся у регистратора.
Внешние эффекты callback не входят в откат внутреннего value-state Object
loader. Владелец загрузочного сеанса должен отдельно учитывать audio buffers;
атомарность всего сеанса или произвольных ошибок DAT здесь не доказана.

[CatalogSoundsReference](../../native/Sources/NTSDReferenceChecks/CatalogSoundsReference.swift)
запускает полный LoadedCatalogReference с новым callback. Входы — исходные
DAT/WAV, allocator/device outputs и объявленное backing. Ожидаемые PCM или
загруженные Object не подаются как входы native. Проверяются полные записи
каталога прежним сравнением; на каждой native registration дополнительно
сверяются cacheBefore, index, caller kind/Object path, вся WAV storage,
порядок событий и конечные buffer slots.

BeforeGlobals дочернего WAV сохраняет остальной контекст родителя: он служит
проверке отсутствия посторонних записей4014e0, не заменяет происхождение
полных globals будущего первого41bc90. Native cacheBefore получается из
собственного parser/registry, а не копируется из этих globals.

| Корпус | Каталог | Новые WAV calls / файлы | Audio bytes/masks | Catalog bytes/masks | Audio events / Restore |
| --- | --- | --- | ---: | ---: | --- |
| Исходный text/a5 |137 Object,17 BG,25 Stage/138 phases,15388 Frame occurrences|400 /365|66210142|112063739|6426 /80|
| Pein→District→Pein→Sasuke→District |3 Object,2 BG,25 Stage/138 phases,720 occurrences|29 /28|4157380|82089953|466 /6|

Итоговые checksum —31475378 и1496213 соответственно. У повторного Pein
новых WAV calls нет. В контрольном проходе SNDDATA_0552 загружается дважды
из-за исходного перекрытия cache, а не из-за принудительной очистки стендом.

Lossless fixture разделён на полный каталог и WAV transport, чтобы сохранить
все данные без увеличения старого envelope limit. SHA-256 обоих raw captures
и fixtures указан в [основном отчёте](../evidence/catalog-sounds.json) и
[контроле](../evidence/catalog-sounds-interleaved.json). Обе release-проверки
прошли **до** принятия новых fixtures. Исторический WAV oracle после refactor
заново воспроизвёл все431 случая,3 initial-sound passes и **все blobs точно**.

Восемь выбранных XCTest прошли за250.754s: новые full/control catalog sounds
96.688s, прежняя подготовка с полным каталогом75.488s, четыре проверки Object
и сырых Frame56.560s, исторический WAV corpus22.018s. Это проверка новых и
затронутых путей, не всех режимов игры. Release-сборка NTSDNative прошла
за16.80s; прежние fixtures не изменены. Приложение остаётся Practice0.4.0.
После уточнения границы последнего частичного cache slot повторены оба новых
сравнения на окончательном native-коде:96.614s, без ошибок. Это проверка
отсутствия регрессии в исходном каталоге; заполнение до последнего cache slot
не входит в corpus400 исходных загрузок.
Итоговая release-сборка приложения также прошла, за14.34s.

```sh
uv run tools/oracle_catalog_sounds.py --check-wave-parent
uv run tools/oracle_catalog_sounds.py
uv run tools/oracle_catalog_sounds.py --interleaved
uv run tools/oracle_catalog_sounds.py --accept
swift test --package-path native --filter '(OriginalCatalogSoundsTests|OriginalObjectTests|OriginalMatchPreparationTests|OriginalWaveLoaderTests)'
```

## Неисследованные отказы и следующий шаг

S: после обычного return0 WAV helper caller всё равно разыменовывает buffer
в410a5a/40be2a. Он не пропускает ресурс и не отменяет регистрацию штатной
ветвью. Native отмечает null buffer/invalid create continuation как выход
за восстановленный домен; не выполняет выдуманное успешное продолжение.
Новый joined corpus использует доступные исходные файлы и успешный create;
полные fault-path traces этих caller пока не сняты. Изолированные ошибки
самого WAV loader остаются в прежнем отдельном корпусе.

Настоящие WINMM/DirectSound DLL и вывод микшера не исполняются. VC80 scanf,
его file/TLS границы и ограничения общего `%lf` остаются прежними. Полная
загрузка экранов, произвольные аллокационные/IO отказы и владение weapon-string
heap ещё открыты; этот этап не меняет границы Practice.

Теперь соединить18 [общих звуков](WAVE_LOADING.md), этот enabled catalog,
реальный400-slot pool и10 [UI bitmap](INITIAL_INTERFACE.md) в первом41bc90.
Получить исходные globals/44d05c=0 и затем путь ввода/паузы/меню к429730.
Windows W, полный матч и проверка готового приложения на чистой macOS открыты.

S следующего входа: пролог41bc90 выравнивает стек до64 байт; local+38 хранит
результат проверки450bfc==1 и восстанавливается в EDI после UI. Два локальных
буфера+434..43d и+440..449 обнуляются до проверки44d05c. При450b84!=0 и
отсутствии этой паузы перед загрузкой вызывается43dc50. Участок41c01a..41c04b
относится к более ранней playback/camera ветви, а не к продолжению каталога:
обычный возврат4122f0 в41c018 сразу переходит на41c052. Не соединять участки
только по возрастанию адресов и не переносить supplied EDI из UI-контроля
как окончательный флаг паузы полного входа.

Продолжение выполнено в [INITIAL_LOADING.md](INITIAL_LOADING.md): настоящий
первый41bc90..41c581 соединяет все четыре компонента и сбрасывает44d05c.
Новый полный вход также сохраняет ненулевые globals внутри sound-cache span
и выполняет исходные callbacks BMP-progress. Старые корпуса этого документа
сохраняют свои исходные границы.
