# Простой бенчмарк HDL симуляторов (версия альфа)

Для оценки скорости запускается симуляция 1024 софт-процессора
[PicoRV32](https://github.com/YosysHQ/picorv32) с программой вычисления хэш-суммы MD5
от блока 1кБ. Данные в каждом блоке инициализируются разными значениями. Размер блока
по-умолчанию равен 1кБ, но с помощью параметра `+dlen=NNN` можно установить
произвольный размер.

В папке `source` находятся исходники RTL и программы. Верхний модуль - `testbench` с
единственным входным сигналом `clock`. Генерация клока во внешнем модуле сделана для
совместимости с верилятором, который не позволяет генерировать клок в верилоге.

В папках `test-*` находятся скрипты для запуска бенчимарка на конкретном
симуляторе. Скрипты называются `__build.sh` (для сборки проекта) и `__run.sh` (для
запуска симуляции).

Скрипт `run.sh` запускает бенчмарк из выбранной папки или все тесты. В параметрах
можно указать количество софт-ядер, размер блока, количество потоков симуляции (пока
только для верилятора) и список бенчмарков:

```
  $ ./run.sh -h
  Usage: ./run.sh [OPTION]... [SIM...]
  Run simulator benchmark. Calculates MD5 hash from a block data
  on an array of soft-cores PicoRV32.

  Options:
    -c [COUNT]    Soft CPU count in simulation. Default: 1024
    -s [SIZE]     Data block size in bytes. Default: 1024 bytes
    -t [COUNT]    Simulation threads count. Default: 1
                  (so far only for Verilator)
    -l            List of available benchmarks
    -h            This help

  The SIM parameter is the name of the simulator from the list of
  option -l. If the parameter is not specified, benchmarks for all
  simulators will be performed. Be careful, some simulators take
  a very long time to benchmark.
```

## Результаты для 1024 процессоров

- Xeon E5-2630v3 @ 2.40GHz
- Verilator 5.011 devel rev v5.010-98-g15f8ebc56
- Icarus Verilog 13.0 (devel) (s20221226-127-gdeeac2edf)
- ModelSim SE-64 2020.4 (Revision: 2020.10)
- QuestaSim 64 2021.1 (Revision: 2021.1)
- Vivado 2021.1

Время выполнения бенчмарка на блоке 1кБ (чч:мм:сс):
```
  | Симулятор             | Build    | Run      |
  +-----------------------+----------+----------+
  | Icarus Verilog        | 00:00:27 | 19:04:37 |
  | ModelSim              | 00:00:00 | 01:33:14 |
  | QuestaSim             | 00:00:00 | 01:29:38 |
  | Verilator (1 thread)  | 00:12:03 | 00:02:57 |
  | Verilator (8 threads) | 00:18:45 | 00:01:33 |
  | XSIM                  | 00:00:29 | 02:08:54 |
  | Xcelium               | TBD      |          |
```
