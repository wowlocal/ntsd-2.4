# Выбор персонажей и готовность человеческих мест

Продолжение [MENU_CYCLE.md](MENU_CYCLE.md), R02.1/R04/R15.
EXE SHA-256: `3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c`.
MSVCR80 SHA-256: `c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d`.

**Проверено D против Native Core в собственной последовательности выбора.**
Оба свежих34-case корпуса совпали и приняты. `OriginalCharacterScreen`
переносит общий human-seat обработчик; правил по имени Naruto/Sasuke в Core нет.
Таблица ниже также содержит S ветви, ещё не покрытые этой последовательностью:
альтернативные modes, left/up/jump, исключение команды при7 готовых, границы
countdown. Оконный UI и выбранный матч открыты.

## Собственная цепочка

`oracle_character_screen.py` заново исполняет и сверяет pinned loading,
startup, первый mode/return и все четыре MENU_CYCLE calls. Его первый вход
продолжает собственный429e5a/menu3, Actor0+d1=1 и acquired J=117. Именно
menu3 задаёт восемь latch=1; стенд не очищает текущую команду вручную.

Дальнейшие кадры вновь входят через целый4246b0/World2→41bc90 и проходят
local/control/received/replay/round/music/resources. На вход разрешены только
внешний ABI и acquired keyboard bytes100/117, разрешённые через собственные
status450b4c+4*seat и control.txt config44fb20+80*status. Ни status, ни selected,
ни team, ни Actor/Object binding не задаются ожидаемым снимком.

Последовательность: отпустить VS, присоединить первые два места, переместить
оба от Random к первой разрешённой записи, ещё четыре раза переместить второе,
подтвердить персонажей и команды. Ожидаемые ordinal17/21 (Naruto/Sasuke)
проверяют сценарий, но не участвуют в алгоритме обхода. Каждый edge проходит
приобретение/применение нажатия и приобретение/применение отпускания через
собственные чередующиеся phase1/0. Все завершённые экраны доходят до42e0d2
и настоящих ret12/ret4/ret4, сохраняя CPU, стек и SEH.

Стенд сохраняет полные World/400 Actor/globals и маски, retained wrappers,
command buffers, все предыдущие input/music/resource checkpoints, вызовы
рисования и фактические bitmap read/clip/Blt, GDI и sound helper, ABI дочерних
и внешних возвратов. Для выбора есть checkpoints перед общим телом, после
очистки team, перед каждым из8 мест, после мест и перед эпилогом. Внутренние
счётчики сравниваются по пяти значащим caller locals; это не полная проверка
каждого байта x86 scratch stack.

## Статические правила

| Адрес | Поведение |
| --- | --- |
|429f09..42a0ae | Menu3:8 status0, selected−1, latch1; Stage ставит team1 первым20, War задаёт команды1/2 base/seat+10; selection0 и menu1 |
|42a114..42a1bc | Счётчик451224=(wrapped(old+1)) signed%30; проверить все400 team, значения вне0..4 заменить0 |
|42a1be..42a258 | Black fill794×550, CHARMENU(40,33), посчитать свободные места при selection0, иначе локальный счётчик−1 |
|42a25a..42a3c7 | Сначала имя места: собственное имя при status1..10, Computer при>=11, пульсирующее Join? для незанятого при selection0, иначе ---- |
|42a3ca..42a518 | Незанятое место рисует CMA/CMA2 либо CM1..5 по общему countdown; attack при latch0 и44d074=0 присоединяет; jump при всех8 свободных возвращает menu10 и вызывает настоящий431c70 |
|42a518..42a651 | Status1 рисует портрет из текущего Actor Object+6fc либо RFACE для selected<0; имя берёт из Object+25324 либо литерала Random |
|42a651..42a899 | Приоритет right,left,up,attack,jump; down/defend сами по себе очищают эту защёлку. Перемещение идёт по ordinal, type0, signed ID/10 groups3/5 gated458428==1 |
|42a670..42a7d6 | Right после последней записи даёт−1; left ниже−1 оборачивается к count−1. Sentinel сохраняет прежний Actor Object pointer; только разрешённая запись меняет binding |
|42a814..42a899 | Attack выбирает status3 для Stage/mode1, status2 иначе; jump возвращает status0. Новое состояние может обрабатываться ещё в этом же вызове, уже с latch1 |
|42a899..42aa8b | Status2 считает все8 status ровно3. При7 готовых в mode0/4 исключает общую ненулевую команду остальных ready seats (status signed%10==3), если такая команда единственная |
|42aa8b..42ade8 | Рисует портрет и имя, затем проверяет team: исключённая команда пропускается; в War допустимы только1/2. Team label пульсирует, имя уже белое |
|42ade8..42af85 | Mode2 принудительно team0, attack1,latch0. Приоритет right,left,attack,jump; команды обходятся0..4 с теми же исключениями; attack→3, jump→1 |
|42af85..42b1f7 | Status3 рисует белые имя/team. При selection0 jump на countdown150 возвращает к status1(Stage)/2; при меньшем countdown вместо этого просит ускорение−30 |
|42b1f7..42b284 | Все8 World activity bytes явно обновляются по итоговому status==3. Если есть готовые и все места либо0, либо3, countdown−1 и опционально−30; все8 готовы→0. Иначе countdown150 |
|42b284..42b959 |44d074 получает selection; стадии1/2/3 идут к следующим интерфейсам, ещё открытым в этом исследовании |
|42e0b6..42e0d2 | При countdown<=0 и selection0 перейти к selection1, затем общий эпилог |

Pulse color использует signed counter/6, умножения младших байтов и wrap:
`p=UInt8((counter/6)*76+counter*30)`,
`((UInt32(p+70)|0xff00)<<8)|UInt32(p+25)` с UInt8 additions.
Не заменять этой формулой таймер или частоту обновления полного приложения.

Важен порядок: готовность status3 обрабатывается после подтверждения status2
в том же кадре. Если jump не нажат, этот обработчик снова очищает latch,
даже когда attack ещё удерживается. Рисунок выбора выполняется до навигации;
после смены status в одном кадре могут выполняться несколько рисунков.

## Воспроизведение и открытые границы

```sh
uv run tools/oracle_character_screen.py
uv run tools/oracle_character_screen.py --control
uv run tools/oracle_character_screen.py --accept
swift test --package-path native -c release --filter OriginalCharacterScreenTests
```

Частичные результаты в build/research/character-screen-partial*.json служат
диагностике. Их нельзя выдавать за принятые fixtures. Опциональный callback
MENU_CYCLE продолжает его собственный последний результат; прежний default
сценарий и данные не изменены. MenuReturn допускает собственный старт42e0d2
после character body, прежний mode caller по умолчанию начинается429eb7.

Первые диагностические исходные проходы обоих вариантов воспроизвели все
родители и9 полных кадров до первого выбранного Naruto. Затем guard следующего
local-input увидел ранее накопленные чтения bitmap+0c в43f04b/43f183. Это
действительные чтения незаполненного constructor field внутри43f010, уже
предусмотренные общим bitmap drawing. Observer теперь сохраняет учтённые
catalog tracker readsBeforeWrites в отдельном renderer этапе, а все read events
содержат исходные значения и defined=false. Ни значение, ни маска поля
не исправляются. Оба свежих исходных прохода после этого заново исполнили
всех родителей и34 полных кадра до готовности обоих участников.

Первая попытка Native acceptance выявила ошибку проверки метаданных: общий
loader tracker охватывает catalog allocations, а draw events также охватывают
menu allocations. Сравнение исправлено на соответствующие области:
readsBeforeWrites проверяется по catalog draws, все read events по-прежнему
сравниваются с нативным bitmap helper. В control menu records остаются также
неопределённые элементы прямоугольников при повторном frame−1 draw; прежний
общий bitmap helper воспроизводит их значения, маски, clipping и Blt.
Core правила и ожидаемые снимки при этих исправлениях не менялись.

Диагностическое Native сравнение обоих прежних9-case prefixes прошло:
по92549 records/124060144 bytes+masks. Оно не принимает fixture и не доказывает
поздние team/ready кадры. Старые2 release OriginalMenuCycleTests прошли25.187s
после сборки87.59s, включая полные прежние mode/return родители.

Для последующего соединения с WinMain подтверждены только S источники пяти
звуковых слотов43d0b5..43d0fb:45560c=m_join.wav,455610=m_ok.wav,
455614=m_cancel.wav,455618=m_pass.wav,45561c=m_end.wav. Каждый передаёт
соответствующий data\\ путь в общий4014e0. Текущий собственный parent этих
WinMain загрузок ещё не исполняет; нельзя объявлять слышимый звук доказанным
только по soundRequest данного corpus.

Следом: расширение проверок общих
left/up/jump, countdown/team/locked roster; затем собственные computer count,
arena/settings и подготовка полного Naruto/Sasuke District матча. Включённый
WinMain menu sound/device output, OS keyboard acquisition, Windows raster,
физическая задержка и проверка полного приложения остаются открытыми.

## Принятый результат

| После полных проверенных родителей | A5 | Ramp/reverse |
| --- | --- | --- |
| Character screens / полные ret12+ret4+ret4 |34 /34 |34 /34 |
| Новые внешние4246b0 входы |33 |33 |
| Checkpoints / events / helpers |908 /4795 /1086 |908 /6587 /1342 |
| Records / bytes+masks |359924 /482678794 |359924 /482678794 |
| Character draw / clip / Blt |312 /312 /312 |312 /568 /568 |
| Raw / packed bytes |8666757 /2213495 |8988659 /2336747 |

Итого68 экранов,66 новых внешних входов,68 полных возвратов,
1816 checkpoints/11382 events/2428 helpers,719848 records/965357588 bytes+masks.
Первый экран каждого корпуса завершает последний вход родителя MENU_CYCLE;
его нельзя повторно считать новым4246b0. Каждый corpus обрабатывает8 мест
на34 экранах, делает34 fills,354 text calls и6 soundRequest. Внутри каждого
последующего outer call сохраняются все прежние проверки пролога, команд,
Winsock, music и retained resources.

Отчёты: [A5](../evidence/character-screen.json),
[control](../evidence/character-screen-control.json). Raw scope оставлен
историческим описанием до принятия; результат D отмечен nativeCompared и
nativeComparison. SHA/размеры raw и packed, полная распаковка проверены;
все100 прежних fixture hashes сохранены,102 pins в
build/research/character-screen-fixture-pins.json.

Оба новых release XCTest прошли28.747s после сборки87.12s; они также
сравнивают полные прежние родители. Со старой регрессией25.187s пройдены
4 теста/53.934s. Release CatalogCheck55.57s, окончательная acceptance
с пересборкой reference53.89s. Предыдущая диагностическая сборка89.29s и
два9-case prefix comparisons не заменяют окончательное сравнение обоих34 cases.
Release NTSDNative32.46s. Все source/SwiftPM/comparison процессы завершены
до промежуточного коммита.

Последнее собственное состояние после полного возврата: World2, menu1,
mode0, selection4512c8=0, countdown44d078=147, pulse451224=4; первые два
selected ordinal17/21, status3/3, team0/0 и latch0/0. Acquired attack уже117
и текущий attack отпущен после собственного phase0. Дальнейшая стадия должна
продолжить этот World через следующий настоящий внешний вызов. Не задавать
selection1 или countdown0 вручную, чтобы перескочить ожидание.

Свежий библиотечный вход в человеческий экран и actualret4 отдельно сравнен
в [FRESH_CHARACTER_MENU](FRESH_CHARACTER_MENU.md). Он использует Random-only
контролируемые места и не заменяет собственную последовательность выбора.
