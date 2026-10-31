# CLI bench per scene and tier (M11 ruling 15)

`rive <scene> --bench=1200 --data=tier=<t>` (rive 1.8.0, headless, 1080x1920 @1x), 5 repeats per scene x tier, tiers interleaved; each value is the median over the repeats, `p95 / ultra` the best p95 of the tier over the best of ultra (interference only adds time). Times in ms. The host is a shared, often loaded Mac: compare tiers within a scene, not across runs. A run with render p95 > 2.0 x its p50 was preempted and is redone (`redone`); each scene waits for the 1-min load to fall to 0.6 x the cores first (`load`: where it started).

Host load (1 / 5 / 15 min) before: 2.14 / 2.68 / 3.07; after: 3.55 / 3.70 / 3.40.

Gate (every scene, at rest): low p95 <= 0.8 x ultra, high p95 <= 1.02 x ultra (above it, a FAIL only when every paired repeat is over ultra: identical files measure 0.97-1.04 here).

### At rest (rain 0)

| scene | tier | render mean | render p50 | render p95 | p95 / ultra | advance mean | advance p95 | load | redone |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
| beach | ultra | 0.450 | 0.455 | 0.577 | 1.000 | 0.070 | 0.097 | 2.1 | 0 |
| beach | high | 0.449 | 0.453 | 0.575 | 1.004 | 0.069 | 0.094 | 2.1 | 0 |
| beach | low | 0.254 | 0.236 | 0.357 | 0.621 | 0.067 | 0.096 | 2.1 | 0 |
| cafe | ultra | 0.651 | 0.658 | 0.781 | 1.000 | 0.075 | 0.100 | 3.1 | 0 |
| cafe | high | 0.657 | 0.662 | 0.785 | 1.009 | 0.069 | 0.096 | 3.1 | 0 |
| cafe | low | 0.399 | 0.403 | 0.512 | 0.657 | 0.050 | 0.070 | 3.1 | 0 |
| campfire | ultra | 0.725 | 0.730 | 0.870 | 1.000 | 0.121 | 0.154 | 2.4 | 0 |
| campfire | high | 0.727 | 0.733 | 0.864 | 1.004 | 0.117 | 0.153 | 2.4 | 0 |
| campfire | low | 0.429 | 0.435 | 0.542 | 0.632 | 0.083 | 0.110 | 2.4 | 0 |
| deepSpace | ultra | 0.726 | 0.730 | 0.858 | 1.000 | 0.043 | 0.063 | 2.8 | 0 |
| deepSpace | high | 0.724 | 0.728 | 0.861 | 1.000 | 0.043 | 0.061 | 2.8 | 0 |
| deepSpace | low | 0.375 | 0.378 | 0.481 | 0.552 | 0.028 | 0.040 | 2.8 | 0 |
| forestCabin | ultra | 0.715 | 0.720 | 0.847 | 1.000 | 0.063 | 0.089 | 2.9 | 0 |
| forestCabin | high | 0.714 | 0.718 | 0.856 | 0.995 | 0.064 | 0.088 | 2.9 | 0 |
| forestCabin | low | 0.466 | 0.469 | 0.581 | 0.681 | 0.049 | 0.071 | 2.9 | 0 |
| library | ultra | 0.505 | 0.510 | 0.619 | 1.000 | 0.092 | 0.122 | 2.7 | 0 |
| library | high | 0.506 | 0.509 | 0.618 | 0.984 | 0.093 | 0.121 | 2.7 | 0 |
| library | low | 0.376 | 0.380 | 0.485 | 0.760 | 0.075 | 0.100 | 2.7 | 0 |
| livingRoom | ultra | 0.818 | 0.788 | 1.247 | 1.000 | 0.064 | 0.120 | 3.4 | 0 |
| livingRoom | high | 0.820 | 0.788 | 1.268 | 1.020 | 0.069 | 0.139 | 3.4 | 0 |
| livingRoom | low | 0.495 | 0.469 | 0.806 | 0.628 | 0.045 | 0.063 | 3.4 | 0 |
| mountainHut | ultra | 0.555 | 0.546 | 0.799 | 1.000 | 0.045 | 0.063 | 5.5 | 0 |
| mountainHut | high | 0.558 | 0.552 | 0.806 | 0.963 | 0.043 | 0.063 | 5.5 | 0 |
| mountainHut | low | 0.405 | 0.397 | 0.580 | 0.722 | 0.029 | 0.044 | 5.5 | 0 |
| rooftop | ultra | 0.700 | 0.691 | 0.939 | 1.000 | 0.092 | 0.127 | 4.4 | 0 |
| rooftop | high | 0.697 | 0.692 | 0.941 | 1.002 | 0.091 | 0.130 | 4.4 | 0 |
| rooftop | low | 0.372 | 0.365 | 0.558 | 0.567 | 0.051 | 0.071 | 4.4 | 0 |
| trainCompartment | ultra | 0.689 | 0.685 | 0.909 | 1.000 | 0.091 | 0.138 | 4.0 | 0 |
| trainCompartment | high | 0.690 | 0.688 | 0.912 | 0.994 | 0.092 | 0.140 | 4.0 | 0 |
| trainCompartment | low | 0.460 | 0.457 | 0.629 | 0.676 | 0.061 | 0.101 | 4.0 | 0 |

### Rain 1 (recorded, not gated; the app never creates SceneFront at low)

| scene | tier | render mean | render p50 | render p95 | p95 / ultra | advance mean | advance p95 | load | redone |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
| beach | ultra | 0.519 | 0.523 | 0.654 | 1.000 | 0.069 | 0.096 | 2.9 | 0 |
| beach | high | 0.510 | 0.515 | 0.639 | 0.967 | 0.071 | 0.093 | 2.9 | 0 |
| beach | low | 0.311 | 0.303 | 0.429 | 0.653 | 0.067 | 0.095 | 2.9 | 0 |
| cafe | ultra | 0.676 | 0.683 | 0.809 | 1.000 | 0.069 | 0.094 | 2.7 | 0 |
| cafe | high | 0.672 | 0.677 | 0.808 | 1.001 | 0.070 | 0.095 | 2.7 | 0 |
| cafe | low | 0.412 | 0.416 | 0.530 | 0.656 | 0.050 | 0.070 | 2.7 | 0 |
| campfire | ultra | 0.785 | 0.790 | 0.938 | 1.000 | 0.102 | 0.132 | 2.7 | 0 |
| campfire | high | 0.768 | 0.773 | 0.916 | 0.975 | 0.106 | 0.139 | 2.7 | 0 |
| campfire | low | 0.458 | 0.462 | 0.582 | 0.622 | 0.081 | 0.106 | 2.7 | 0 |
| deepSpace | ultra | 0.725 | 0.730 | 0.865 | 1.000 | 0.042 | 0.061 | 2.8 | 0 |
| deepSpace | high | 0.725 | 0.728 | 0.865 | 0.991 | 0.043 | 0.062 | 2.8 | 0 |
| deepSpace | low | 0.374 | 0.377 | 0.487 | 0.551 | 0.028 | 0.041 | 2.8 | 0 |
| forestCabin | ultra | 0.783 | 0.786 | 0.927 | 1.000 | 0.070 | 0.100 | 2.8 | 0 |
| forestCabin | high | 0.778 | 0.782 | 0.917 | 1.004 | 0.064 | 0.091 | 2.8 | 0 |
| forestCabin | low | 0.534 | 0.538 | 0.649 | 0.701 | 0.053 | 0.080 | 2.8 | 0 |
| library | ultra | 0.558 | 0.561 | 0.680 | 1.000 | 0.081 | 0.111 | 2.9 | 1 |
| library | high | 0.541 | 0.545 | 0.673 | 0.968 | 0.084 | 0.113 | 2.9 | 1 |
| library | low | 0.399 | 0.398 | 0.512 | 0.750 | 0.079 | 0.110 | 2.9 | 1 |
| livingRoom | ultra | 0.817 | 0.809 | 1.043 | 1.000 | 0.060 | 0.086 | 3.9 | 0 |
| livingRoom | high | 0.815 | 0.809 | 1.041 | 0.989 | 0.060 | 0.089 | 3.9 | 0 |
| livingRoom | low | 0.500 | 0.489 | 0.720 | 0.653 | 0.041 | 0.056 | 3.9 | 0 |
| mountainHut | ultra | 0.562 | 0.554 | 0.797 | 1.000 | 0.043 | 0.061 | 4.9 | 0 |
| mountainHut | high | 0.555 | 0.549 | 0.768 | 0.980 | 0.043 | 0.062 | 4.9 | 0 |
| mountainHut | low | 0.408 | 0.403 | 0.568 | 0.723 | 0.031 | 0.046 | 4.9 | 0 |
| rooftop | ultra | 0.815 | 0.808 | 1.060 | 1.000 | 0.083 | 0.108 | 3.8 | 0 |
| rooftop | high | 0.793 | 0.787 | 1.039 | 0.965 | 0.093 | 0.128 | 3.8 | 0 |
| rooftop | low | 0.465 | 0.456 | 0.686 | 0.635 | 0.055 | 0.077 | 3.8 | 0 |
| trainCompartment | ultra | 0.718 | 0.712 | 0.928 | 1.000 | 0.086 | 0.136 | 4.1 | 0 |
| trainCompartment | high | 0.713 | 0.712 | 0.957 | 1.008 | 0.087 | 0.134 | 4.1 | 0 |
| trainCompartment | low | 0.491 | 0.483 | 0.722 | 0.734 | 0.054 | 0.094 | 4.1 | 0 |

### Gates

- bench beach: low render p95 0.357 ms = 0.621 x ultra 0.577 ms (<= 0.8; load 2.1, 0 redone) ok
- bench beach: high render p95 0.575 ms = 1.004 x ultra 0.577 ms (<= 1.02; load 2.1, 0 redone) ok
- bench cafe: low render p95 0.512 ms = 0.657 x ultra 0.781 ms (<= 0.8; load 3.1, 0 redone) ok
- bench cafe: high render p95 0.785 ms = 1.009 x ultra 0.781 ms (<= 1.02; load 3.1, 0 redone) ok
- bench campfire: low render p95 0.542 ms = 0.632 x ultra 0.870 ms (<= 0.8; load 2.4, 0 redone) ok
- bench campfire: high render p95 0.864 ms = 1.004 x ultra 0.870 ms (<= 1.02; load 2.4, 0 redone) ok
- bench deepSpace: low render p95 0.481 ms = 0.552 x ultra 0.858 ms (<= 0.8; load 2.8, 0 redone) ok
- bench deepSpace: high render p95 0.861 ms = 1.000 x ultra 0.858 ms (<= 1.02; load 2.8, 0 redone) ok
- bench forestCabin: low render p95 0.581 ms = 0.681 x ultra 0.847 ms (<= 0.8; load 2.9, 0 redone) ok
- bench forestCabin: high render p95 0.856 ms = 0.995 x ultra 0.847 ms (<= 1.02; load 2.9, 0 redone) ok
- bench library: low render p95 0.485 ms = 0.760 x ultra 0.619 ms (<= 0.8; load 2.7, 0 redone) ok
- bench library: high render p95 0.618 ms = 0.984 x ultra 0.619 ms (<= 1.02; load 2.7, 0 redone) ok
- bench livingRoom: low render p95 0.806 ms = 0.628 x ultra 1.247 ms (<= 0.8; load 3.4, 0 redone) ok
- bench livingRoom: high render p95 1.268 ms = 1.020 x ultra 1.247 ms (<= 1.02; load 3.4, 0 redone) ok
- bench mountainHut: low render p95 0.580 ms = 0.722 x ultra 0.799 ms (<= 0.8; load 5.5, 0 redone) ok
- bench mountainHut: high render p95 0.806 ms = 0.963 x ultra 0.799 ms (<= 1.02; load 5.5, 0 redone) ok
- bench rooftop: low render p95 0.558 ms = 0.567 x ultra 0.939 ms (<= 0.8; load 4.4, 0 redone) ok
- bench rooftop: high render p95 0.941 ms = 1.002 x ultra 0.939 ms (<= 1.02; load 4.4, 0 redone) ok
- bench trainCompartment: low render p95 0.629 ms = 0.676 x ultra 0.909 ms (<= 0.8; load 4.0, 0 redone) ok
- bench trainCompartment: high render p95 0.912 ms = 0.994 x ultra 0.909 ms (<= 1.02; load 4.0, 0 redone) ok
