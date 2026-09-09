# R02.1 / R05 / R10 / R11 — полный физический проход World

Эталон: NTSD 2.4 EXE SHA-256
`3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c`.

[OriginalWorldPhysics](../../native/Sources/NTSDCore/OriginalWorldPhysics.swift)
переносит весь `41e634..41eed1`: общий [Actor physics](ACTOR_PHYSICS.md),
деактивацию, возрождение, создание998 и обратное превращение. Он продолжает
собственный [WORLD_CONTROL](WORLD_CONTROL.md), сохраняя каталог, ресурсы и replay.

## Правила caller

| Участок | Порядок и условие |
| --- | --- |
| `41e634..41e657` | Слоты0..<400, любой ненулевой activity, настоящий40e490 |
| `41e657..41e684` | Итоговый state9998 деактивирует текущий слот |
| `41e684..41e7d8` | State14/HP<=0 и нужные owner/team/slot/counter;314>0 восстанавливает участника |
| `41e7d8..41e96f` | Первый свободный слот50..<400 и первый каталог sourceID998, реконструкция и активация |
| `41e96f..41ec66` | Недостаточно lives — деактивация; иначе lives−1 и respawn около средней позиции команды |
| `41ec66..41eed1` | Обратная подмена Object по324, связанные объекты и продолжение цикла |

После40e490 все условия читают уже изменённый Actor/Frame. State9998
деактивирует слот, но не пропускает последующую обратную подмену. World-таблица
может несколько раз ссылаться на одну Actor-аллокацию. Записи сохраняют этот
alias; поздний активированный слот получает свою физику в этом же проходе.

Смерть обрабатывается при state14 и HP<=0, если owner2f4>=0 **либо** team364==5
**либо** slot>=20, и счётчик8 строго в1..4. При314>0:30c=310, MP308=0,
maxHP304=314, redHP300=304, HP2fc=300;314/310 очищаются, team=1. Source ID30..36
ставит318=140. Frame219, wait88=0, freezeB4=10. Семь ID проверяет сам EXE;
это сохранённое исходное исключение, не обработчики по именам персонажей.

Далее ищется первый неактивный слот от50 и первый Object с ID998. Нет места
или ID — все предыдущие записи возрождения остаются. Новый Actor проходит
общий конструктор с сохранением provenance нетронутых полей; получает Object,
durability из Object90 и исходные binary defaults580/−200/300, затем координаты
и команду текущего Actor. Integer z=source.z+1, но binary z копируется без+1.
**Frame6 получает созданный Actor через ESI**, возрождённый остаётся219.
Все три скорости/facing обнуляются, activity=1; owner не назначается.
При alias источник перечитывается после реконструкции, поэтому копировать его
заранее нельзя. Слот до текущего не получает повторную физику в этом проходе.

При314<=0 и lives30c<2 слот деактивируется. Иначе lives уменьшается и считается
средняя integer x/z остальных Object типа0 той же команды. Здесь activity
требуется **ровно1**, HP не фильтруется, текущий номер слота исключён.
Суммы сохраняют Int32 overflow; среднее делится со знаком к нулю. Сначала
настоящий RNG(tag144,51), затем binary x=average+result−26; затем
RNG(tag145,31), binary z=average+result−16. Константа26 взята из4492b0.
MP=500, redHP/HP=maxHP, counter8=20, frame212, integer и binary y=−300,
vy=0. Integer x/z не обновляются, vx/vz сохраняются до следующих стадий.

Нулевое число подходящих союзников приводит в оригинале к idiv fault41eb98
**после** первого RNG и уменьшения lives. Воспроизводимый
[source-only отчёт](../evidence/world-physics-no-allies.json) сохраняет этот
путь, включая RNG index/counter1 и lives1. Native возвращает явную ошибку и
откатывает весь World/pool/globals. Откат — политика неподдержанного пути порта,
он не выдаётся за состояние Windows после сбоя. Придуманная безопасная точка
возрождения не добавляется.

Обратная подмена требует324>-1, combo byteDC==3, integer iy==0, HP>0.
DC очищается до поиска, даже при пустом каталоге или отсутствии ID. Первый
source ID324 становится новым Object ordinal, frame245,324=−1. Все активные
живые Actor с owner2f4=текущему номеру слота также получают Object и frame212
при integer iy<0, иначе0. Цикл включает текущего при его owner==slot;
поэтому его245 может быть заменён. Поздние связанные слоты проходят физику
с новой привязкой. Каталожные ordinals и исходные ID не объединяются.

## Сравнение с оригиналом

[oracle_world_physics.py](../../tools/oracle_world_physics.py) исполняет весь
caller с настоящими40e490/4061d0/417170/416fb0/417090/4450d0. Синтетические
входы явно задают400 Actor, четыре Object, Frame, globals и CW037f/legacy ftol2.
Прежний constructor memset остаётся объявленной границей. У игровых helpers
нет заглушек; каждый возврат проверяет стек и сохраняемые регистры, pool —
маски чтений/границы аллокаций, World — только допустимые activity-записи.

515 сценариев:240 death gates,32 restore/spawn,64 respawn,168 revert,
4 deactivate/revert,5 catalog counts, полный400-slot physics и пустой World.
8329 helper returns,916 уникальных выполненных инструкций. Сравниваются SHA
всех424408 pool bytes/масок и46144 globals, порядок RNG/constructor/sound.
Первое Native сравнение выявило неверного адресата frame6 в четырёх обычных
spawn cases. Инструкции41e929/41e932 подтвердили ESI/созданный слот; исправлен
Native, исходный корпус не менялся. При alias записи совпадали и до исправления,
поэтому такие случаи не заменяют проверки разных аллокаций.

Синтетический отчёт: [world-physics](../evidence/world-physics.json).
Отдельный тест отката использует свою таблицу RNG из единиц и видит result2;
source-only fault witness использует заявленную ramp-таблицу и result3.
Это разные входы; оба сохраняют порядок первого RNG перед ошибкой.

## Собственный запуск матча

`MatchLaunchReference.compare(...gameplayControl:,gameplayPhysics:true)` заново
строит и проверяет полную родительскую цепочку: загрузку, меню, выбор участников,
District, музыку, preparation/recording, возврат и следующий целый4246b0.
С собственного41e339 выполняется WORLD_CONTROL, затем WORLD_PHYSICS до41eed1.
Ни Actor, ни phase/RNG, ни ожидаемые snapshots не задаются как новые входы.

Используются два прежних source GAMEPLAY_ENTRY, каждый после свежего полного
родителя на том же CPU/стеке. Сравниваются все pool/globals/маски, ранние ресурсы
и CRT,101 BG,854 bitmap, музыка/аллокации и весь replay630e18, а также оба
Actor на control-return и physics-return41e657. Два физические helper returns
на запуск сохраняют SP/nonvolatile registers. Ненаблюдённые промежуточные
префиксы не объявляются дополнительными native checkpoints.

В результате оба бойца получают frame219: Naruto x442.1/y0/z504.1,
Sasuke289.1/0/519.1; integer x/z442/504 и289/519, скорости0. Это результат
настоящих конструкторских скоростей0.1, не ручное присвоение landing frame.
HP500, MP200, teams10/11, RNG index39/counter0, phase1/tick1, музыка
bgm\boss2.wma и полная recording ownership сохранены. End SP1000e9bc,
**до первого Z/contact pass**; внешний4246b0 ещё не вернулся.

Оба первых own comparison прошли за35.179с. Вместе с полными секциями
MATCH_LAUNCH/control/physics они сравнили56330 записей /512207004 байта
с масками,906 helpers и58 checkpoints. Новые собственно physics-секции
добавляют4 helper returns и4 Actor checkpoints; прочие родители не считаются
новыми проходами ещё раз. [a5 отчёт](../evidence/gameplay-physics.json),
[ramp/reverse addresses](../evidence/gameplay-physics-control.json).

```sh
uv run tools/oracle_world_physics.py
uv run tools/oracle_world_physics.py --fault
python3 tools/accept_physics.py
swift test --package-path native -c release --filter 'Original(ActorPhysics|WorldPhysics|GameplayPhysics|ActorControl|ActorInput|WorldControl|GameplayControl|MatchLaunch)Tests'
```

Общий acceptor сначала проверяет raw SHA/размеры, parent fixture и все
внутренние blobs собственной цепочки, затем Native, потом пишет новые fixtures.
Прежние GAMEPLAY_ENTRY evidence сохраняют source-only область, прежние
GAMEPLAY_CONTROL fixtures/checks сохраняют остановку41e634. Новые lossless
fixtures сравнивают обе секции; их expected states не становятся входами Core.

Финальный raw acceptance прошёл6 XCTest за64.517с, release build97.67с.
После публикации все новые packed fixtures и прежние ActorInput/ActorControl/
WorldControl/GameplayControl/MATCH_LAUNCH, включая четыре rollback checks,
прошли вместе:17 XCTest/161.849с, release build98.21с. Эта сборка также
скомпилировала и связала NTSDNative; это проверка сборки приложения, не его UI.
Все процессы завершены. SHA112 прежних fixtures неизменны, у пяти новых
проверены raw/packed SHA/размеры и полное распакованное содержимое JSON.
117 pins сохранены в `build/research/world-physics-fixture-pins.json`.

Следом на этом же собственном World: начальная Z-обработка417f80, контактные
проходы/создание предметов, связи, вывод/камера, планировщик/восстановление и
возврат всего такта. Windows/startup FPU, альтернативные режимы/CPU, непрерывные
техники, оконный UI, законченный матч и чистая macOS остаются открытыми.

Продолжение [WORLD_LINKS](WORLD_LINKS.md) теперь переносит всю417f80 и первый
собственный caller до41eed8. Это не только Z: внутри второй400-slot проход
с использованием/размещением/бросками удерживаемых предметов. Далее419380;
старые physics fixtures сохраняют остановку41eed1.
