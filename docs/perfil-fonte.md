# Perfil da fonte — ANP, levantamento de precos por posto

## `ca-2023-01.csv`

- encoding detectado: `utf-8-sig` · delimitador: `;`
- colunas (16): `regiao_sigla, estado_sigla, municipio, revenda, cnpj_da_revenda, nome_da_rua, numero_rua, complemento, bairro, cep, produto, data_da_coleta, valor_de_venda, valor_de_compra, unidade_de_medida, bandeira`
- linhas: 431,576
- linhas no escopo (gasolina comum / etanol / S-10): 175,441
- CNPJs distintos: 8,875 · municipios: 460
- CNPJ com mascara: 431,576 (amostra bruta: `00.003.188/0001-21`)
- data da coleta: `01/02/2023` a `31/05/2023`
- valor de venda vazio: 0 (0.0%)
- valor de compra vazio: 431,576 (100.0%)
- unidades de medida: {'R$ / litro': 422525, 'R$ / m³': 9051}

| produto | linhas |
| --- | ---: |
| GASOLINA | 110,824 |
| ETANOL | 95,201 |
| GASOLINA ADITIVADA | 86,201 |
| DIESEL S10 | 80,240 |
| DIESEL | 50,059 |
| GNV | 9,051 |

## `ca-2025-02.csv`

- encoding detectado: `utf-8-sig` · delimitador: `;`
- colunas (16): `regiao_sigla, estado_sigla, municipio, revenda, cnpj_da_revenda, nome_da_rua, numero_rua, complemento, bairro, cep, produto, data_da_coleta, valor_de_venda, valor_de_compra, unidade_de_medida, bandeira`
- linhas: 384,208
- linhas no escopo (gasolina comum / etanol / S-10): 153,562
- CNPJs distintos: 7,842 · municipios: 413
- CNPJ com mascara: 0 (amostra bruta: `04431113000100`)
- data da coleta: `01/07/2025` a `31/12/2025`
- valor de venda vazio: 0 (0.0%)
- valor de compra vazio: 384,208 (100.0%)
- unidades de medida: {'R$ / litro': 375476, 'R$ / m3': 8732}

| produto | linhas |
| --- | ---: |
| GASOLINA | 101,605 |
| ETANOL | 85,155 |
| GASOLINA ADITIVADA | 80,111 |
| DIESEL S10 | 68,407 |
| DIESEL | 40,198 |
| GNV | 8,732 |

## Teste de SCD Tipo 2

- CNPJs presentes em **todos** os arquivos analisados: 5,071
- mudaram de **bandeira**: 1,874 (37.0%)
- mudaram de **razao social**: 359 (7.1%)
- mudaram de **endereco**: 468 (9.2%)

> Limite inferior: comparando so os extremos da janela, trocas de ida e volta e mudancas nos semestres intermediarios nao aparecem.

## Orcamento de armazenamento (estimativa)

- linhas no escopo por ano (aprox.): 329,003
- projecao para 3,5 anos (2023-01 a 2026-01): 1,151,510
- heap do fato a ~80 B/linha: 92 MB
- com ~30% de indices: 120 MB (teto do Neon free: 500 MB)
