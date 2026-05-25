# BLu85 AES-GCM Source Provenance

Upstream repository: `https://github.com/BLu85/AES-GCM-128-192-256-bits`

Imported revision: `7f6f43a971362ccaf4bb5416bc7ff96a63119005`
(`master`, inspected on 2026-05-25).

The imported `src/*.vhd` files are upstream source files. The imported
`src/gen_rtl/*.vhd` files were produced from that revision with:

```sh
cd config
python3 gcm_config.py --mode 256 --size M --pipe 0
```

This selects AES-256-GCM with a medium seven-round physical AES datapath and
no added internal pipeline registers for the first ZCU111 functional
integration milestone.

The upstream README is preserved as `UPSTREAM-README.md`. It states that all
files in the repository are licensed under Apache License 2.0 via a link to
the Apache 2.0 text. The inspected source snapshot did not contain a separate
`LICENSE` file.
