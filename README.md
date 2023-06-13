# Простой бенчмарк HDL симуляторов (преранняя версия)

Для оценки скорости запускается симуляция софт-процессора
[PicoRV32](https://github.com/YosysHQ/picorv32) с программой вычисления первых 200
знаков числа Пи.

В папке `source` находятся исходники RTL и программы. Верхний модуль - `testbench` с
единственным входным сигналом `clock`. Генерация клока во внешнем модуле сделана для
совместимости с верилятором, который не позволяет генерировать клок в верилоге.

В папках `test-*` находятся скрипты для запуска бенчимарка на конкретном
симуляторе. Скрипты называются `__build.sh` (для сборки проекта) и `__run.sh` (для
запуска симуляции).

Скрипт `run.sh` запускает бенчмарк на всех симуляторах и сохраняет время исполнения в
файл `results.txt`. Можно запустить бунчмарк на одном симуляторе, для чего в
параметрах скрипта `run.sh` нужно указать папку с бенчмарком.

## Результаты для 50 знаков Пи

- Xeon E5-2630v3 @ 2.40GHz
- Verilator 5.011 devel rev v5.010-98-g15f8ebc56
- Icarus Verilog 13.0 (devel) (s20221226-127-gdeeac2edf)
- ModelSim SE-64 2020.4 (Revision: 2020.10)

Время в миллисекундах:
```
    test-iverilog: 210540
    test-modelsim: 25555
    test-verilator: 1289
```

## Результаты для 200 знаков Пи

Вычисление 200 знаков на Icarus Verilog занимает непозволительно много времени, по
этому перед запуском всех бенчмарков рекомендую переименовать папку `test-iverilog` в
`notest-iverilog`.

Результаты для 200 знаков на том же процессоре:
```
    test-iverilog: 3257116
    test-xsim: 938296
    test-modelsim: 359562
    test-verilator: 20816
```

## Предварительные результаты по симуляторам "Big 3"

Коллеги прогнали бенчмарк на Xcelium, VCS и Modelsim. Примерные оценки показали
следующие результаты (приведено к скорости Xcelium):

```
    test-verilator: 0.35
    test-xcelium: 1
    test-vcs: 1.37
    test-modelsim: 5.95
    test-xsim: 15.5
    test-iverilog: 58
```

Конечно, нужно учитывать то, что Verilator - это cycle-accurate симулятор, и что он
не поддерживает состояния X и Z.
