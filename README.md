# MKOSystems

Рекомендованная версия Delphi: 11

#### Сборка и запуск
1. Откройте группу проектов.
2. Соберите группу проектов (ProjectGroup\Build All)
3. Запуск shell_win_vcl.exe

#### Компоненты

##### shell-win-vcl

Оболочка для загрузки "ядра" динамических библиотек. Реализует интерфейс логирования и простейшие элементы управления.
Конфигурация: shell_win_vcl.ini
```
[Core]
; Путь к ядру
File=core.dll
```

##### Core

"Ядро" - менеджер динамических библиотек (plugins). Обеспечивает безопасную загрузку / выгрузку библиотек. Предоставляет необходимые интерфейсы для взаимодействия компонентов системы.
Конфигурация: core.ini
```
[Main]
;Load modules from path. If 0 then from modules section.
LoadModulesFromPath = 0
;Module Extension
ModuleExt = ".dll"
;Modules path (relative)
Path = modules\
HWID=1C89E11C-0338

;In case of load modules from path, some modules can be skipped
[Skip]
; FileName = 1/0, 1 is for skip

[Modules]
; Order is Important !!!
; Modules will be loaded Ascend
; Modules will get Notify AllModulesLoaded Ascend
; Modules will be Notify Delete (Before Detroy) Descend
; Modules will be Unloaded Descend
; Path = 1/0, 1 is Active

; Log
modules\ulog_txt_file.dll = 1
; Others
modules\file_analysis.dll = 1
modules\shell_exec.dll = 1

```

##### file-analysis
Библиотека класса: General plugin.
**Функции:**
- Поиск файлов в заданном каталоге с использованием регулярных выражений Regex.
- Поиск данных в файле по последовательностям (ключам).

Задачи формируются в конфигурационном файле.
Конфигурация: file_analysis.ini
```
[FileSearcher]
; Path = Regex
C:\Windows = win.ini|notepad.exe|explorer.exe
C:\Windows\System32 = calc.exe|ntfs.sys

[FileContentScanner]
; FilePath = Sequences comma splitted
TestData\leaks.txt = System,EdgeController
TestData\VMSEngineLog.txt = CREATE
```
*Важно: При такой системы конфигурации key не может повторяться.*

#####  shell-exec
Библиотека класса: General plugin.
**Функции:**
- Запуск Sell команды с ожиданием результата а отдельном потоке.

Задачи формируются в конфигурационном файле.
Конфигурация: shell_exec.ini
```
[Main]
;How many tasks we have
Count = 3

[Cmd_0]
; Task1
ping=ya.ru

[Cmd_1]
; Task2
ping=mail.ru

[Cmd_2]
; Task3
ping=hh.ru
```
