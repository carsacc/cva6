# Customer CPU Benchmark Baseline

This directory vendors the benchmark snapshot previously executed on the
customer reference systems:

```text
/home/carlos/projects/CHAOS/cpu_benchmark/third_party/
```

The source files are copied without workload changes, including their original
whitespace. The local `.gitattributes` prevents Git whitespace checks from
requesting byte-changing cleanup. Verify the copy with:

```sh
../check-reference-benchmark-sources.sh
```

The included CoreMark `coremark.md5` verifies its five `.c` workload files but
does not match the included `coremark.h`. That mismatch exists in the customer
snapshot and is deliberately preserved here for comparable measurements.

Dhrystone is copied without changes. During compilation only the same two
obsolete `extern` declarations removed by the customer runner are removed
from generated build copies of `dhry_1.c`.
