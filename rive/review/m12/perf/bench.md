# CLI bench per scene and tier (M11 ruling 15)

`rive <scene> --bench=1200 --data=tier=<t>` (rive 1.8.0, headless, 1080x1920 @1x), 5 repeats per scene x tier, tiers interleaved; each value is the median over the repeats, `p95 / ultra` the best p95 of the tier over the best of ultra (interference only adds time). Times in ms. The host is a shared, often loaded Mac: compare tiers within a scene, not across runs. A run with render p95 > 2.0 x its p50 was preempted and is redone (`redone`); each scene waits for the 1-min load to fall to 0.6 x the cores first (`load`: where it started).

Host load (1 / 5 / 15 min) before: 1.66 / 2.15 / 2.52; after: 3.54 / 2.75 / 2.66.

Gate (every scene, at rest): low p95 <= 0.8 x ultra, high p95 <= 1.02 x ultra (above it, a FAIL only when every paired repeat is over ultra: identical files measure 0.97-1.04 here). A scene whose gate fails is measured once more after the load wait and fails only if the re-run fails too (M12 ruling 4: the table shows the re-run, its gate line says `retried`).

### At rest (rain 0)

| scene | tier | render mean | render p50 | render p95 | p95 / ultra | advance mean | advance p95 | load | redone |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
| beach | ultra | 0.456 | 0.459 | 0.584 | 1.000 | 0.068 | 0.087 | 1.7 | 0 |
| beach | high | 0.456 | 0.459 | 0.585 | 0.990 | 0.069 | 0.087 | 1.7 | 0 |
| beach | low | 0.258 | 0.247 | 0.354 | 0.608 | 0.063 | 0.078 | 1.7 | 0 |
| cafe | ultra | 0.652 | 0.655 | 0.795 | 1.000 | 0.076 | 0.099 | 1.8 | 0 |
| cafe | high | 0.653 | 0.657 | 0.808 | 1.010 | 0.075 | 0.098 | 1.8 | 0 |
| cafe | low | 0.402 | 0.402 | 0.520 | 0.633 | 0.045 | 0.064 | 1.8 | 0 |
| campfire | ultra | 0.725 | 0.728 | 0.883 | 1.000 | 0.122 | 0.152 | 2.3 | 0 |
| campfire | high | 0.729 | 0.733 | 0.891 | 1.014 | 0.118 | 0.156 | 2.3 | 0 |
| campfire | low | 0.432 | 0.434 | 0.547 | 0.620 | 0.083 | 0.103 | 2.3 | 0 |
| deepSpace | ultra | 0.721 | 0.725 | 0.882 | 1.000 | 0.047 | 0.065 | 2.3 | 0 |
| deepSpace | high | 0.719 | 0.723 | 0.872 | 0.994 | 0.049 | 0.067 | 2.3 | 0 |
| deepSpace | low | 0.378 | 0.380 | 0.484 | 0.557 | 0.027 | 0.034 | 2.3 | 0 |
| forestCabin | ultra | 0.719 | 0.719 | 0.882 | 1.000 | 0.066 | 0.100 | 2.1 | 4 |
| forestCabin | high | 0.704 | 0.709 | 0.864 | 1.009 | 0.076 | 0.102 | 2.1 | 4 |
| forestCabin | low | 0.467 | 0.468 | 0.595 | 0.692 | 0.051 | 0.064 | 2.1 | 4 |
| library | ultra | 0.506 | 0.508 | 0.632 | 1.000 | 0.095 | 0.122 | 3.4 | 0 |
| library | high | 0.507 | 0.509 | 0.630 | 0.995 | 0.095 | 0.119 | 3.4 | 0 |
| library | low | 0.357 | 0.358 | 0.457 | 0.721 | 0.072 | 0.085 | 3.4 | 0 |
| livingRoom | ultra | 0.780 | 0.784 | 0.944 | 1.000 | 0.059 | 0.080 | 2.7 | 0 |
| livingRoom | high | 0.777 | 0.782 | 0.945 | 0.993 | 0.064 | 0.087 | 2.7 | 0 |
| livingRoom | low | 0.476 | 0.479 | 0.610 | 0.644 | 0.038 | 0.050 | 2.7 | 0 |
| mountainHut | ultra | 0.553 | 0.554 | 0.694 | 1.000 | 0.036 | 0.052 | 2.7 | 0 |
| mountainHut | high | 0.553 | 0.552 | 0.698 | 0.997 | 0.041 | 0.057 | 2.7 | 0 |
| mountainHut | low | 0.367 | 0.365 | 0.479 | 0.671 | 0.028 | 0.044 | 2.7 | 0 |
| rooftop | ultra | 0.692 | 0.696 | 0.879 | 1.000 | 0.083 | 0.108 | 3.0 | 0 |
| rooftop | high | 0.722 | 0.721 | 0.897 | 1.002 | 0.048 | 0.061 | 3.0 | 0 |
| rooftop | low | 0.367 | 0.368 | 0.473 | 0.546 | 0.051 | 0.062 | 3.0 | 0 |
| trainCompartment | ultra | 0.685 | 0.689 | 0.823 | 1.000 | 0.080 | 0.129 | 3.5 | 0 |
| trainCompartment | high | 0.681 | 0.685 | 0.824 | 0.999 | 0.086 | 0.135 | 3.5 | 0 |
| trainCompartment | low | 0.458 | 0.460 | 0.585 | 0.705 | 0.058 | 0.088 | 3.5 | 0 |

### Gates

- bench beach: low render p95 0.354 ms = 0.608 x ultra 0.584 ms (<= 0.8; load 1.7, 0 redone) ok
- bench beach: high render p95 0.585 ms = 0.990 x ultra 0.584 ms (<= 1.02; load 1.7, 0 redone) ok
- bench cafe: low render p95 0.520 ms = 0.633 x ultra 0.795 ms (<= 0.8; load 1.8, 0 redone) ok
- bench cafe: high render p95 0.808 ms = 1.010 x ultra 0.795 ms (<= 1.02; load 1.8, 0 redone) ok
- bench campfire: low render p95 0.547 ms = 0.620 x ultra 0.883 ms (<= 0.8; load 2.3, 0 redone) ok
- bench campfire: high render p95 0.891 ms = 1.014 x ultra 0.883 ms (<= 1.02; load 2.3, 0 redone) ok
- bench deepSpace: low render p95 0.484 ms = 0.557 x ultra 0.882 ms (<= 0.8; load 2.3, 0 redone) ok
- bench deepSpace: high render p95 0.872 ms = 0.994 x ultra 0.882 ms (<= 1.02; load 2.3, 0 redone) ok
- bench forestCabin: low render p95 0.595 ms = 0.692 x ultra 0.882 ms (<= 0.8; load 2.1, 4 redone) ok
- bench forestCabin: high render p95 0.864 ms = 1.009 x ultra 0.882 ms (<= 1.02; load 2.1, 4 redone) ok
- bench library: low render p95 0.457 ms = 0.721 x ultra 0.632 ms (<= 0.8; load 3.4, 0 redone) ok
- bench library: high render p95 0.630 ms = 0.995 x ultra 0.632 ms (<= 1.02; load 3.4, 0 redone) ok
- bench livingRoom: low render p95 0.610 ms = 0.644 x ultra 0.944 ms (<= 0.8; load 2.7, 0 redone) ok
- bench livingRoom: high render p95 0.945 ms = 0.993 x ultra 0.944 ms (<= 1.02; load 2.7, 0 redone) ok
- bench mountainHut: low render p95 0.479 ms = 0.671 x ultra 0.694 ms (<= 0.8; load 2.7, 0 redone) ok
- bench mountainHut: high render p95 0.698 ms = 0.997 x ultra 0.694 ms (<= 1.02; load 2.7, 0 redone) ok
- bench rooftop: low render p95 0.473 ms = 0.546 x ultra 0.879 ms (<= 0.8; load 3.0, 0 redone) ok
- bench rooftop: high render p95 0.897 ms = 1.002 x ultra 0.879 ms (<= 1.02; load 3.0, 0 redone) ok
- bench trainCompartment: low render p95 0.585 ms = 0.705 x ultra 0.823 ms (<= 0.8; load 3.5, 0 redone) ok
- bench trainCompartment: high render p95 0.824 ms = 0.999 x ultra 0.823 ms (<= 1.02; load 3.5, 0 redone) ok
