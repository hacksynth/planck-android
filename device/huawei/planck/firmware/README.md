# Planck firmware input

This directory is intentionally empty in Git. It must contain firmware extracted
from a device the operator owns, or firmware obtained under terms that permit
redistribution.

Use:

```sh
bash scripts/import-firmware.sh --source /path/to/firmware-root
```

Expected layout after import:

```text
qcom/sdm850/HUAWEI/AL09/
ath10k/WCN3990/hw1.0/
qcom/a630_sqe.fw
qcom/a630_gmu.bin
```

At minimum, Wi-Fi requires the AL09 ADSP/CDSP/SLPI/IPA firmware, WCN3990
`wlanmdsp.mbn`, `board-2.bin`, and `firmware-5.bin`. Missing firmware does not
prevent Android userspace from starting, but the corresponding hardware will
not work.

