# thp-stats.sh — Transparent Hugepage Statistics

`thp-stats.sh` is a small Bash script that displays kernel Transparent Hugepage (THP) and sub-THP statistics in a readable format.

It collects data from `/sys/kernel/mm/transparent_hugepage/` and `/proc/meminfo`, summarising THP configuration, `khugepaged` activity, per-size hugepage usage, and total THP-backed memory.

## Features

- Prints the current THP policy and configuration
- Summarises `khugepaged` background activity
- Displays a per-size breakdown of hugepage allocation and usage
- Shows total THP-backed memory and its share of system RAM
- Optional verbose explanations for each metric

## Usage

```bash
./thp-stats.sh              # Default concise output
./thp-stats.sh -v           # Verbose mode with explanations
```

## Example output

```
-----------------------------------------------------------------------------------
size      alloc       fb   succ     nr   nr_bytes   sh_al   sh_fb   splits   sp_def
-----------------------------------------------------------------------------------
8k            0        0   0.0%      0        0 B       0       0        0        0
16k       6.43M       16 100.0%   1052  16.44 MiB       0       0   57.79k  368.23k
32k       5.18M        1 100.0%    396  12.38 MiB       0       0   45.49k  302.23k
64k       8.36M  118.58k  98.6%    249  15.56 MiB       0       0  178.22k  622.74k
128k      1.92M        0 100.0%     78   9.75 MiB       0       0   33.43k  317.87k
256k      1.47M  230.71k  86.4%     40  10.00 MiB       0       0   86.99k  125.62k
512k    409.44k    2.61k  99.4%     27  13.50 MiB       0       0   14.44k   22.09k
1024k   466.66k  196.65k  70.4%     10  10.00 MiB       0       0   30.44k   41.38k
2048k   710.35k  172.90k  80.4%   1133   2.21 GiB  33.47k     323    1.56k    4.44k

Current THP-backed memory
-----------------------------------------------------------------------------------
AnonHugePages    1.96 GiB
ShmemHugePages  56.00 MiB
FileHugePages         0 B
THP / RAM        2.01 GiB / 30.72 GiB (6.6%)
-----------------------------------------------------------------------------------
```

## License

This script is released under the CC0 1.0 Universal (Public Domain Dedication).

You are free to copy, modify, and distribute it, with or without attribution.
