# R02.1/R15 — сохранение настроек

Эталон — EXE SHA-256
`3f7ac67c5890ef979ee24a6dae5528056e7f631725c292cf9cb0a928ebeff71c`;
VC80 DLL SHA-256
`c3ac989c8489a23bb96400b1856f5325ffc67e844f04651ea5d61bc20a991c6d`.
Перенесён весь `423230..423475`, включая настоящие VC80 `fprintf`/`fclose`
и мутации общих строк. Статические callers раннего экрана — `427688/427704`.
Этот корпус исследует helper отдельно; непрерывный menu caller остаётся следующим
этапом после [FRONT_SCREEN_BODY.md](FRONT_SCREEN_BODY.md).

`OriginalSettingsWriting` использует тот же `OriginalBufferedTextOutput`, что
и [запись данных панели](MENU_INFO_WRITING.md). Новый общий `printFormat`
сохраняет границы sign/value/literal в CRT; оба родителя используют его.
В runtime нет вызовов Windows DLL или исполнения исходного EXE.

## Порядок операций

1. Fopen `data\control.txt`, режим`w`.
2. Четыре группы по11 signed32 чисел начиная с`44fb70`, шаг группы`50`,
   шаг числа4. Каждое число — отдельный `fprintf("%d ")`, после группы —
   отдельный `fprintf("\n")`. Между группами остаются нетронутые padding bytes.
3. В четырёх строках с базами`44fcc0+11*i` заменить исходную обратную кавычку
   `60` на апостроф`27`, иначе пробел`20` на обратную кавычку`60`.
   Строки сканируются через NUL, длина пересчитывается после каждой итерации.
4. Пустые имена получают только UInt16`"1\0".."4\0"`. Затем один
   `fprintf("%s %s %s %s\n")` для четырёх текущих строк.
5. Пустые profile name`44fd18`, info`44f900`, email`44f890` получают
   соответственно `<No name>\0`, `<No info>\0`, `<No email>\0` из исходных
   констант`449134/449120/449660`. Записи идут4/4/2 байта, у email ещё byte.
6. Отдельные `%d\n` для`450be8`, затем`450be4`. Затем `%s\n` для profile name,
   `%s\n` для email и `%s` для info, **без финального перевода строки**.
7. Fclose. После его возврата снова пройти четыре имени, заменяя только`60`
   на пробел. Апострофы не преобразуются обратно. Ошибки printf/close не отменяют
   эту часть. EAX — последняя вычисленная длина четвёртого имени, не fclose result.

Шаг11 не ограничивает длину имени. Первое длинное имя может проходить через
следующие три строки и metadata. Следующие проходы снова преобразуют уже
записанные байты. Поэтому пробел в пересекающихся строках может сначала стать
обратной кавычкой, затем апострофом и остаться им после сохранения. Пустые
metadata поля заполняются после вывода имён и тоже могут менять видимую длину
перекрывающего их имени. Native сохраняет общую память и исходный порядок.

## Границы форматированного вывода CRT

Функция DLL`78141712` получает управление из `fprintf` в`7813ee3d`.
Существенные адреса для используемых обычных `%d/%s`:

| Адрес | Поведение |
| --- | --- |
| `78141871` | Перед следующим байтом формата проверить shared output count<0 |
| `78141671..781416a3` | Один byte: успешная запись увеличивает count, ошибка устанавливает−1 |
| `781416c8..78141711` | Вывод последовательности: начать независимо от прежнего count, после byte остановиться при−1 (EILSEQ42 отдельно, вне корпуса) |
| `78141f51..78141f62` | Отдельно вывести prefix, в этих форматах — минус отрицательного числа |
| `78141fd8..78141fe4` | Затем независимо войти в вывод digits/string value |

Контроль `io-1-error-10` обнаружил расхождение прежнего плоского вывода:
при попытке вывести знак числа−2147483648 flush предыдущего пробела не удаётся.
Знак всё равно остаётся в buffer[0], count становится−1. Затем original
продолжает цифры; первая успешная цифра увеличивает count до0, остальные до9,
следующий пробел — до10. `fprintf` возвращает10, а не−1, сохраняя FILE error bit.
То же подтверждено для zero/short write. Обобщённый `printFormat` переносит
границы prefix/value и общий count; отдельного исключения для настройки нет.

Прежние `printBytes`/`_flsbuf`/close правила не меняются. Новая операция
ограничена ASCII format literals и обычными `%d/%s` без flags/width/precision.
Строковые значения сохраняют произвольные исходные bytes, включая high bytes;
проценты внутри `%s` не становятся форматами. Append/wide/EILSEQ42, другие
conversion modes и полная Windows CRT initialization остаются открытыми.

## Корпуса и проверка

Два прохода по226 случаев используют A5 или ramp backing буфера вывода.
Начальное состояние — объявленная PE/BSS память; первый набор полей явно
извлечён из исходного `data/control.txt`, а не получен из Windows startup.
SHA-256 этого файла —
`cc7f84872d9b95fe64c1c95cc7895b3e2c0a52a3ae0f7f7970f0b3c56b7037c0`.
Первый результат совпадает с исходным файлом целиком после заявленной CRLF→LF
трансляции. Следующие вызовы сохраняют собственные globals; только объявленные
stimulus bytes и новые FILE/output-buffer inputs изменяются извне.

Проверены все44 numeric positions с signed limits, два settings integers,
пустые имена/metadata, пробелы/кавычки/табуляции/переводы строк/high bytes,
имена до511 байт с перекрытиями, повторное сохранение, capacities1/7/64/4096,
неудачные и короткие writes, положительные и отрицательные close results.

| Наблюдение на проход | Число |
| --- | ---: |
| Полные возвраты / null FILE / unterminated name | 221 / 4 / 1 |
| Actual fprintf / fclose | 11 982 / 221 |
| Descriptor writes / failed или short | 36 813 / 54 |
| Ordered events / parent global writes | 53 533 / 4 070 |
| Full records / bytes и masks | 149 067 / 2 307 985 161 |

Сравниваются globals, все32 FILE bytes и полный пользовательский buffer с masks
на каждом CRT return и descriptor boundary, затем после всего helper.
Source проверяет actual CRT returns, ESP и nonvolatile registers; native сверяет
call sites и конечное значение. Буфер не очищается при ошибке или закрытии.
Никакой ожидаемый after-state не используется для следующего native вызова.

В EXE нет проверки null после fopen: четыре таких контроля останавливаются
**до** первого `fprintf` call`423260`. Продолжение через CRT invalid-parameter
handler не исполнено и не заменено безопасным false-return. Последний контроль
не имеет NUL до конца объявленных globals: остановка перед первым выходящим
чтением`423297`. Предыдущие44 числа/4 перевода строки уже записаны, FILE не
закрывается. Native сохраняет такое же частичное состояние и явную границу.

```sh
uv run tools/oracle_settings_writing.py
uv run tools/oracle_settings_writing.py --control
uv run tools/oracle_settings_writing.py --accept
swift test --package-path native --filter 'Original(SettingsWriting|MenuInfoWriting|MenuPanelUpdate)Tests'
swift build --package-path native -c release --product NTSDNative
```

Оба raw и оба packed корпуса совпали с release CLI; fixtures приняты после
двух успешных packed сравнений. Сохранены SHA всех35 прежних pinned fixtures,
для двух новых проверены raw/packed SHA и полная распаковка. Шесть XCTest
прошли за84.404 s: новый settings writer67.138 s, прежние menu-info4.925 s
и joined panel12.341 s. Эти регрессии проверяют общий изменённый printf helper.
Release NTSDNative собран за2.69 s. Отчёты:
[основной](../evidence/settings-writing.json),
[контрольный](../evidence/settings-writing-control.json).

Fopen supplies FILE flags102, `_write/_close/_isatty` и CRT thread services
остаются объявленными границами. Исходный файл не меняется; логические LF bytes
проверены до реальной Windows file translation. Следом — соединить helper
с selector−3`4275cb`, затем selector−1`4277f3` и main-menu/tail. Оконный UI,
worker, полная игра/Windows и чистая macOS остаются открытыми; R02.1 не закрыта.
