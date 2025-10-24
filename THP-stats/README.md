# thp-stats.sh — Transparent Hugepage Statistics

`thp-stats.sh` is a small Bash script that displays kernel Transparent Hugepage (THP) and sub-THP statistics in a readable format.

It collects data from `/sys/kernel/mm/transparent_hugepage/` and `/proc/meminfo`, summarising THP configuration, `khugepaged` activity, per-size hugepage usage, and total THP-backed memory.

## Features

- Prints the current THP policy and configuration
- Summarises `khugepaged` background activity
- Displays a per-size breakdown of THP allocation and usage

## Usage

```bash
./thp-stats.sh      # Default concise output
./thp-stats.sh -v   # Verbose mode with explanations
```

## Example output

```
Allocated THP pages
-----------------------------------------------------------------------------------
size      alloc       fb   succ     nr   nr_bytes   sh_al   sh_fb   splits   sp_def
-----------------------------------------------------------------------------------
8k            0        0   0.0%      0        0 B       0       0        0        0
16k      39.08M      126 100.0%    895  13.98 MiB       0       0  459.09k    2.43M
32k      32.45M   11.44k 100.0%    431  13.47 MiB       2       0  340.14k    2.15M
64k      34.89M  135.47k  99.6%    288  18.00 MiB       1       0  564.19k    3.07M
128k     12.73M   17.11k  99.9%     74   9.25 MiB       0       0  281.22k    2.12M
256k      4.63M  250.19k  94.9%     22   5.50 MiB       1       0  206.17k  402.99k
512k      2.38M   25.45k  98.9%     17   8.50 MiB       0       0   74.86k  129.14k
1024k     2.22M  218.86k  91.0%     12  12.00 MiB      34       0  173.63k  206.35k
2048k     5.76M  427.17k  93.1%    790   1.54 GiB 301.47k   6.73k   44.93k   28.18k

In-use THP-backed memory
-----------------------------------------------------------------------------------
AnonHugePages    1.42 GiB
ShmemHugePages 226.00 MiB
FileHugePages         0 B
THP / Used RAM   1.64 GiB / 9.34 GiB (17.6%)
-----------------------------------------------------------------------------------
```

## License

This script is released under the [CC0 1.0 Universal (Public Domain Dedication)](https://creativecommons.org/publicdomain/zero/1.0/).

You are free to copy, modify, and distribute it, with or without attribution.
