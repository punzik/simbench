# Простой бенчмарк HDL симуляторов (преранняя версия)

Для оценки скорости запускается симуляция 1024 софт-процессоров
[PicoRV32](https://github.com/YosysHQ/picorv32) с программой вычисления хэш-суммы MD5
от блока 64кБ. Данные в каждом блоке инициализируются разными значениями.

В папке `source` находятся исходники RTL и программы. Верхний модуль - `testbench` с
единственным входным сигналом `clock`. Генерация клока во внешнем модуле сделана для
совместимости с верилятором, который не позволяет генерировать клок в верилоге.

В папках `test-*` находятся скрипты для запуска бенчимарка на конкретном
симуляторе. Скрипты называются `__build.sh` (для сборки проекта) и `__run.sh` (для
запуска симуляции).

Скрипт `run.sh` запускает бенчмарк из выбранной папки или все тесты, если параметром
указать `all`. В параметрах можно указать сразу несколько папок с тестами. Результаты
бенчмарка записываются в файл `results.txt`.

## Результаты для 1024 процессоров

- Xeon E5-2630v3 @ 2.40GHz
- Verilator 5.011 devel rev v5.010-98-g15f8ebc56
- Icarus Verilog 13.0 (devel) (s20221226-127-gdeeac2edf)
- ModelSim SE-64 2020.4 (Revision: 2020.10)
- QuestaSim 64 2021.1 (Revision: 2021.1)
- Vivado 2021.1

Время выполнения бенчмарка:
```
    Icarus Verilog: TBD
    ModelSim: TBD
    QuestaSim: TBD
    Verilator: TBD
    XSIM: TBD
    Xcelium: TBD
```
