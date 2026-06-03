# test-12-yocto-jtag-boot

Boots the ZCU111 Yocto image through the same OpenOCD/GDB path used by the
earlier Linux smoke tests.

This test expects a Yocto deploy directory containing:

- `fw_jump.elf`
- `Image-initramfs-cv64a6-zcu111.bin`
- `cv64a6_zcu111.dtb`

The initramfs is bundled into the kernel image. This avoids depending on
`linux,initrd-start` and `linux,initrd-end` in `/chosen`, because the OpenSBI
version currently built by the CVA6 Yocto flow removes those properties before
entering Linux.

Default deploy path:

```text
/home/carlos/projects/CHAOS/riscv-cores/cva6-yocto/build/tmp-glibc/deploy/images/cv64a6-zcu111
```

Override it with:

```bash
YOCTO_DEPLOY_DIR=/path/to/deploy/images/cv64a6-zcu111 ./run.sh
```

Expected UART evidence:

```text
OpenSBI
Linux version
Yocto userspace init/login messages
```

After boot, validate:

```sh
/root/mmio-test
/root/irq-test
/root/aes-gcm-test
```
