# ZCU111 Linux CoreMark Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a manually-run Linux CoreMark binary to the existing ZCU111 BusyBox initramfs.

**Architecture:** Reuse `test-11-busybox-initramfs` so the current Linux shell remains the entry point. Build CoreMark as a static RISC-V Linux executable, copy it to `/root/coremark`, and do not execute it from `/init`.

**Tech Stack:** CVA6 ZCU111 DDR4 Linux, BusyBox initramfs, bundled CoreMark sources under `verif/tests/custom/coremark`, `riscv64-linux-gnu-gcc`.

---

## Task 1: Add Rootfs Verification

- [x] Create `corev_apu/fpga/tests/test-11-busybox-initramfs/check-rootfs.sh`.
- [x] Run it against the current rootfs and verify it fails because `/root/coremark` is missing.

## Task 2: Build CoreMark For Linux

- [x] Add Linux CoreMark port files under `corev_apu/fpga/tests/test-11-busybox-initramfs/coremark/`.
- [x] Extend `run.sh` to compile CoreMark statically and install it as `build/rootfs/root/coremark`.
- [x] Keep `/init` unchanged so CoreMark is only launched manually.

## Task 3: Verify And Document

- [x] Run `bash -n` for the updated scripts.
- [x] Run `run.sh --check-only`.
- [x] Build the rootfs and verify `check-rootfs.sh` passes.
- [x] Update READMEs with `cd /root && ./coremark`.
