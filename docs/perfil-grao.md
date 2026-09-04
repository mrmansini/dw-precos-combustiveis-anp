## `ca-2023-01.csv`

- datas invalidas: 0
- periodo real: 2023-01-02 a 2023-06-30
- dias distintos de coleta: 129
- dias da semana (0=seg): {0: 127876, 1: 133145, 2: 103394, 3: 61358, 4: 5803}

| mes | linhas |
| --- | ---: |
| 2023-01 | 69,027 |
| 2023-02 | 62,389 |
| 2023-03 | 72,164 |
| 2023-04 | 68,616 |
| 2023-05 | 86,577 |
| 2023-06 | 72,803 |

- comprimento do CNPJ normalizado: {14: 431576}
- precos nao numericos: 0

| produto | min | mediana | max |
| --- | ---: | ---: | ---: |
| DIESEL | 3.970 | 5.690 | 7.990 |
| DIESEL S10 | 4.390 | 5.820 | 9.000 |
| ETANOL | 2.970 | 3.990 | 6.960 |
| GASOLINA | 4.090 | 5.290 | 8.190 |
| GASOLINA ADITIVADA | 3.470 | 5.490 | 8.970 |
| GNV | 3.090 | 4.650 | 6.710 |

- duplicatas por **dia** (cnpj+produto): 0 grupos, 0 linhas excedentes (0.00%)
- duplicatas por **semana ISO** (cnpj+produto): 0 grupos, 0 linhas excedentes (0.00%)

- bandeiras distintas: 46
- top 15 bandeiras: 
  - `BRANCA` — 144,415
  - `IPIRANGA` — 97,415
  - `VIBRA ENERGIA` — 91,748
  - `RAIZEN` — 59,560
  - `ALESAT` — 16,831
  - `SABBÁ` — 4,068
  - `ATEM' S` — 1,885
  - `RAIZEN MIME` — 1,639
  - `RODOIL` — 1,275
  - `STANG` — 1,124
  - `TAURUS` — 1,066
  - `CHARRUA` — 976
  - `DISLUB` — 877
  - `SP` — 864
  - `EQUADOR` — 773
- CNPJs com mais de um municipio no mesmo arquivo: 0
- unidades de medida: {'R$ / litro': 422525, 'R$ / m³': 9051}

## `ca-2025-02.csv`

- datas invalidas: 0
- periodo real: 2025-07-01 a 2025-12-31
- dias distintos de coleta: 138
- dias da semana (0=seg): {0: 152734, 1: 97073, 2: 70254, 3: 54026, 4: 9825, 5: 296}

| mes | linhas |
| --- | ---: |
| 2025-07 | 65,316 |
| 2025-08 | 53,922 |
| 2025-09 | 64,268 |
| 2025-10 | 62,859 |
| 2025-11 | 62,263 |
| 2025-12 | 75,580 |

- comprimento do CNPJ normalizado: {14: 384208}
- precos nao numericos: 0

| produto | min | mediana | max |
| --- | ---: | ---: | ---: |
| DIESEL | 5.240 | 5.990 | 8.390 |
| DIESEL S10 | 4.730 | 5.990 | 9.290 |
| ETANOL | 3.090 | 4.390 | 7.440 |
| GASOLINA | 4.990 | 6.190 | 9.290 |
| GASOLINA ADITIVADA | 5.190 | 6.390 | 9.590 |
| GNV | 3.390 | 4.590 | 6.490 |

- duplicatas por **dia** (cnpj+produto): 0 grupos, 0 linhas excedentes (0.00%)
- duplicatas por **semana ISO** (cnpj+produto): 0 grupos, 0 linhas excedentes (0.00%)

- bandeiras distintas: 48
- top 15 bandeiras: 
  - `BRANCA` — 125,359
  - `VIBRA` — 84,356
  - `IPIRANGA` — 84,165
  - `RAIZEN` — 57,489
  - `ALE` — 9,972
  - `SABBÁ` — 4,267
  - `RODOIL` — 2,083
  - `ATEM' S` — 1,844
  - `CHARRUA` — 1,805
  - `EQUADOR` — 1,393
  - `SP` — 1,081
  - `RAIZEN MIME` — 1,063
  - `STANG` — 858
  - `MAXSUL` — 822
  - `NEXTA` — 719
- CNPJs com mais de um municipio no mesmo arquivo: 0
- unidades de medida: {'R$ / litro': 375476, 'R$ / m3': 8732}

## Transicoes de bandeira

- CNPJs em ambos: 5,071
- com bandeira dominante diferente: 1,784 (35.2%)

| de | para | postos |
| --- | --- | ---: |
| VIBRA ENERGIA | VIBRA | 1,012 |
| ALESAT | ALE | 139 |
| IPIRANGA | BRANCA | 99 |
| VIBRA ENERGIA | BRANCA | 93 |
| BRANCA | IPIRANGA | 72 |
| RAIZEN | BRANCA | 72 |
| BRANCA | VIBRA | 50 |
| BRANCA | RAIZEN | 41 |
| ALESAT | BRANCA | 34 |
| RAIZEN | IPIRANGA | 15 |
| IPIRANGA | RAIZEN | 11 |
| VIBRA ENERGIA | IPIRANGA | 11 |
| VIBRA ENERGIA | RAIZEN | 11 |
| BRANCA | ALE | 10 |
| BRANCA | RODOIL | 10 |
| BRANCA | CHARRUA | 8 |
| SABBÁ | BRANCA | 6 |
| RAIZEN | VIBRA | 6 |
| IPIRANGA | VIBRA | 5 |
| VIBRA ENERGIA | ALE | 5 |
| TOTALENERGIES | NEXTA | 4 |
| SUL COMBUSTÍVEIS | SANTA LUCIA | 4 |
| BRANCA | TEMAPE | 4 |
| ALESAT | IPIRANGA | 3 |
| RAIZEN | SIM DISTRIBUIDOR | 3 |
| IPIRANGA | RODOIL | 2 |
| IPIRANGA | CHARRUA | 2 |
| IPIRANGA | ALE | 2 |
| VIBRA ENERGIA | EQUADOR | 2 |
| RAIZEN | CHARRUA | 2 |
