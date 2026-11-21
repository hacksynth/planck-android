# Prebuilt boot inputs

`scripts/build-kernel.sh` writes the following files here:

```text
Image
vmlinuz.efi
dtb/sdm850-huawei-planck-android.dtb
dtb/sdm850-huawei-matebook-e-2019.dtb
```

`Image` is consumed by Android `boot.img`. The EFI-capable kernel and DTBs are
consumed by `scripts/package-esp.sh`. `modules/` is populated only when
`PLANCK_BUILD_MODULES=1` is set; first-boot display, touch, storage,
power-management and WCN3990 drivers are built into the kernel.

