# Planck firmware input

This directory is intentionally empty in Git. It must contain firmware extracted
from a device the operator owns, or firmware obtained under terms that permit
redistribution.

Use (can be run multiple times for vendor-firmware and `/usr/lib/firmware`;
`.zst` and `.xz` compressed files are decompressed automatically):

```sh
bash scripts/import-firmware.sh --source /path/to/vendor-firmware
bash scripts/import-firmware.sh --source /usr/lib/firmware
```

Expected layout after import:

```text
qcom/sdm850/HUAWEI/AL09/         (ADSP/CDSP/SLPI/MSS/IPA/Venus/GPU zap + wlanmdsp.mbn)
ath10k/WCN3990/hw1.0/            (board-2.bin, firmware-5.bin, wlanmdsp.mbn)
qca/                             (crbtfw21.tlv, crnv21.bin for WCN3990 Bluetooth)
qcom/a630_sqe.fw
qcom/a630_gmu.bin
```

Notes from PAK-AL09 bring-up (`matebook-e2019-archlive`):

- `ath10k/WCN3990/hw1.0/board-2.bin` from `linux-firmware` already includes the
  `Huawei_Planck` calibration entry; do not replace it with Windows `bdwlan.*`.
- PAK-AL09 MSS/QMI expects the legacy `wlanmdsp.mbn` at
  `qcom/sdm850/HUAWEI/AL09/wlanmdsp.mbn` (the experimental `shikra`
  `WLAN.HL.3.3.7.c5-00226` firmware times out on PAK-AL09 cold boot).
- Missing firmware does not prevent Android userspace from starting, but the
  corresponding hardware (Wi-Fi, Bluetooth, Adreno GPU, DSPs) will not work.
