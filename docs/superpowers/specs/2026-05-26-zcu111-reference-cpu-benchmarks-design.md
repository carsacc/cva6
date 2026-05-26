# ZCU111 Reference CPU Benchmarks Design

Date: 2026-05-26

## Objective

Provide CPU performance measurements on the CVA6 ZCU111 Linux platform that
can be compared against measurements already produced by the customer's
`cpu_benchmark` package.

The customer's snapshot is the reference baseline. This work does not replace
it with a newer upstream release, repair it to match an included manifest, or
change the measured workload. Platform-specific compilation flags and
frequency values are reported explicitly because the target ISA and operating
frequency necessarily differ.

## Existing Problem

The current ZCU111 `/root/coremark` is not a strictly comparable instance of
the benchmark used in `cpu_benchmark`. It sources CoreMark from
`verif/tests/custom/coremark` and its `coremark_main.c` includes an additional
unmeasured `iterate(&results[0])` call before the measured run. That call
changes pre-measurement cache and microarchitectural state.

The current result is useful as a CVA6 functional/performance smoke test, but
it must not be used as the formal comparison against the customer's reference
machine results.

## Authoritative Baseline

The authoritative input is the snapshot currently stored under:

```text
/home/carlos/projects/CHAOS/cpu_benchmark/
```

Its behavior takes precedence over upstream CoreMark or Dhrystone sources,
because this is the exact benchmark package previously executed on the
customer's reference systems.

The CVA6 test will vendor a local, immutable copy of the required baseline
files under its BusyBox initramfs test directory. The copy will include a
provenance file listing the source path and SHA-256 checksums below.

### CoreMark Baseline Files

```text
17884c93c5b94378eb0ff02b4df3725756cf2addb9b8cbcaa6200a4649ff5ca7  core_main.c
ca00e4e010ece47d7f040cb92aa50a95345a00d3171b59d088f6b243be06ce7b  core_list_join.c
ecdff717b5a5c4907d221a606760e25499899cbf617582c05d40db71c91351e4  core_matrix.c
f4b84bb0a3452c45a4daa664ab502bfdccbd31cb57d93e9ac490c60937717a4e  core_state.c
a3fbfcb9bb943b638624b8ece01c5836dd56a96d7bcde2697b248d077447327f  core_util.c
42642b9a06c7ed2b3bd9eda971b7c3868c4f5d27bf7ef6c4bba11291a0c2598a  coremark.h
f2b48f062058d528a5907e339ffd05d98f64d59e7c40d500fe05563eb5247ad0  posix/core_portme.c
a40e90ef4c5a5626d438afee1f8da628c2800105d4c3b5318e8810b34be554f2  posix/core_portme.h
1dc67b5c1b9c773cccc740b911d708333d3bf154c3313f77b8a52e18209eda59  posix/core_portme_posix_overrides.h
```

The snapshot contains an included `coremark.md5` file. Its five benchmark
`.c` entries verify successfully, while its `coremark.h` entry does not match
the stored header. This discrepancy is a recorded property of the customer
baseline and will not be corrected in the CVA6 copy.

### Dhrystone Baseline Files

```text
442e47760cd43c1e6d87cfc0c03134101d97110d417e11a29b5ed42c0eb4767b  dhry_1.c
7954383013caead70e8283375b249ecbaa1aaf092b526acbcac3f187a015c108  dhry_2.c
6593c6e4e8fe3a483925b2fb6e100d9e65451633da5f519cc40ba49b93859010  dhry.h
```

## CoreMark Execution Contract

The ZCU111 initramfs will replace the current modified CoreMark executable with
one built from the vendored baseline sources and the baseline POSIX port. Since
the test runs under Linux, the POSIX port is applicable and avoids target-side
changes to `core_main.c`.

The target build uses:

```text
riscv64-linux-gnu-gcc -static -O3 -march=rv64gc -mabi=lp64d \
  -DPERFORMANCE_RUN=1 -DITERATIONS=0 \
  -DFLAGS_STR="-static -O3 -march=rv64gc -mabi=lp64d -DPERFORMANCE_RUN=1 -DITERATIONS=0 -lrt" \
  -lrt
```

These flags are the target-platform analogue of the customer's host flags and
must be printed with results. They cannot be identical to
`-march=native -mtune=native`, since the CVA6 binary targets RISC-V rather than
the customer's host CPU.

The raw execution command is identical in parameters to `cpu_benchmark`:

```sh
/root/coremark 0x0 0x0 0x66 0 7 1 2000
```

This preserves the original performance seeds, `ITERATIONS=0` auto-sizing, and
2000-byte memory setting. The acceptance evidence is the raw benchmark output,
including:

```text
2K performance run parameters for coremark.
seedcrc          : 0xe9f5
[0]crclist       : 0xe714
[0]crcmatrix     : 0x1fd7
[0]crcstate      : 0x8e3a
Correct operation validated.
```

The expected final CRC for the unmodified customer baseline is also recorded
from the customer run as:

```text
[0]crcfinal      : 0xa14c
```

`CoreMark/MHz` is not added to CoreMark source code. The separate reporting
script parses `CoreMark 1.0` and divides it by the fixed CVA6 clock of
`50 MHz`, preserving the raw benchmark executable.

## Dhrystone Execution Contract

The ZCU111 initramfs will add `/root/dhrystone` built from the vendored
Dhrystone 2.1 sources.

The customer's runner performs two source preparation edits solely to compile
the old C source with a modern compiler:

```sh
sed -i '/extern char     \*malloc ();/d' dhry_1.c
sed -i '/extern  int     times ();/d' dhry_1.c
```

The target build will apply those same two edits to build-directory copies,
leaving the vendored baseline sources unchanged. It will compile with:

```text
riscv64-linux-gnu-gcc -std=gnu89 -static -O3 -march=rv64gc -mabi=lp64d \
  -DHZ=100 -include string.h -include stdlib.h
```

`dhry.h` uses `TIMES`, and Linux exposes process clock ticks as 100 ticks per
second for this interface; this is the Linux target value corresponding to the
customer runner's `getconf CLK_TCK` build parameter.

The reporting script will reproduce the customer's autotune policy:

1. Start at `20,000,000` runs.
2. Pass the number of runs through stdin to `/root/dhrystone`.
3. If output says `Measured time too small`, double the run count.
4. Stop when output contains `Dhrystones per Second`.

The primary Dhrystone metric is the raw line emitted by the original program:

```text
Dhrystones per Second: <value>
```

The reporting layer computes the same derived metrics used by the customer:

```text
DMIPS = Dhrystones/sec / 1757
DMIPS/MHz = DMIPS / 50
```

## Linux Image Contents And User Workflow

This remains a manually invoked test inside the existing BusyBox initramfs.
No benchmark will execute automatically during boot.

The root filesystem will contain:

```text
/root/coremark
/root/dhrystone
/root/run-reference-benchmarks
```

`/root/coremark` and `/root/dhrystone` are the raw benchmark executables.
`/root/run-reference-benchmarks` executes the agreed protocol and reports
normalised values without modifying benchmark source or timed regions.

The existing diagnostic utilities, memory stress tests, MMIO/IRQ tests, and
AES-GCM KAT remain unchanged.

## Verification Criteria

Implementation is accepted when all of the following are demonstrated:

1. The vendored benchmark files match the recorded SHA-256 baseline.
2. The initramfs contains static RISC-V Linux binaries for CoreMark and
   Dhrystone plus the external reporting script.
3. Raw CoreMark on the ZCU111 reports the standard 2K performance CRCs and
   final CRC `0xa14c`, with no modified pre-measurement iteration.
4. Raw Dhrystone completes with valid final-variable checks and emits
   `Dhrystones per Second`.
5. The external runner emits `CoreMark/MHz`, `DMIPS`, and `DMIPS/MHz` using
   the fixed CVA6 clock of 50 MHz.
6. Documentation explicitly distinguishes the earlier non-comparable CVA6
   CoreMark result from the new reference-compatible result.

## Branch And Milestone Policy

This is a software/initramfs refinement and does not change FPGA hardware.
Development remains on `zcu111-aes-gcm`, after the validated hardware tag
`zcu111-aes-gcm-kat`.

After hardware execution validates both reference benchmarks, create a new
software milestone tag:

```text
zcu111-linux-reference-benchmarks
```

The AES-GCM hardware tag remains the immutable fallback for the previously
validated accelerator milestone.
