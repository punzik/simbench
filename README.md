# Простой бенчмарк HDL симуляторов (версия альфа)

Для оценки скорости запускается симуляция 1024 софт-процессоров
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

- 2 x Xeon E5-2630v3 @ 2.40GHz (no HT), 64GB RAM
- NixOS 24.11 Linux Kernel 6.6.67

- GCC 13.3.0
- Verilator 5.028 2024-08-21 rev v5.028
- Icarus Verilog 13.0 (devel) (s20221226-127-gdeeac2edf)
- QuestaSim 64 2021.1 (Revision: 2021.1)
- Vivado 2021.1
- [OSS CVC](https://github.com/cambridgehackers/open-src-cvc) (rev. 782c69a)

Время выполнения бенчмарка на блоке 1кБ (чч:мм:сс):
```
| Симулятор             | Build    | Run      |
+-----------------------+----------+----------+
| CVC                   | 00:00:05 | 00:57:15 |
| Icarus Verilog        | 00:00:23 | 16:15:02 |
| QuestaSim (+acc)      | 00:00:00 | 01:06:54 |
| QuestaSim (-O5)       | 00:00:00 | 00:06:50 |
| VCS                   | 00:00:25 | 00:04:12 |
| Verilator (1 thread)  | 00:09:23 | 00:02:45 |
| Verilator (8 threads) | 00:09:02 | 00:00:50 |
| XSIM                  | 00:00:29 | 02:06:16 |
| Xcelium               | TBD      |          |
```

Удалось протестировать Xcelium на другом оборудованиии и привести время выполнения
бенчмарка к остальным симам. Время сборки на этих симуляторах примерно соответствует
времени сборки на XSIM.

В таблице ниже показано относительное время выполнения теста, приведенное к времени
выполнения на многопоточном Вериляторе. Вериляторы 5.028 и 4.120 показали практически
одинаковую скорость, разность в пределах погрешности. Но в 5.028 была включена опция
`--timing`, а клок формировался в верилоге.

"По просьбе выживших, имена были изменены. Из уважения к погибшим, остальное было
рассказано в точности так, как это произошло."

```
| Симулятор             | Run  |
+-----------------------+------+
| CVC                   |   69 |
| Icarus Verilog        | 1170 |
| QuestaSim (+acc)      |   80 |
| QuestaSim (-O5)       |  8.2 |
| VCS                   |  5.0 |
| Verilator (1 thread)  |  3.3 |
| Verilator (8 threads) |    1 |
| XSIM                  |  152 |
| Xcelium               |   ~4 |
```
