# Efeito de work_mem

Tempos em milissegundos, menor de três execuções. work_mem definido por sessão, sem alterar a configuração do servidor.

| consulta | 4MB | 16MB | 64MB | 256MB |
| --- | ---: | ---: | ---: | ---: |
| `01_serie_semanal_por_uf` | 499 | 456 (0.91x) | 467 (0.94x) | 443 (0.89x) |
| `02_dispersao_intramunicipal` | 658 | 730 (1.11x) | 695 (1.06x) | 651 (0.99x) |
| `03_paridade_etanol_gasolina` | 1,046 | 974 (0.93x) | 894 (0.85x) | 894 (0.85x) |
| `04_evento_troca_bandeira` | 249 | 239 (0.96x) | 239 (0.96x) | 233 (0.94x) |

## Transbordo para disco

### `01_serie_semanal_por_uf`

- **4MB**: Sort Method: external merge  Disk: 8760kB
- **16MB**: Sort Method: quicksort  Memory: 15424kB
- **64MB**: Sort Method: quicksort  Memory: 16106kB
- **256MB**: Sort Method: quicksort  Memory: 16106kB

### `02_dispersao_intramunicipal`

- **4MB**: Sort Method: top-N heapsort  Memory: 29kB; Sort Method: external merge  Disk: 9768kB
- **16MB**: Sort Method: top-N heapsort  Memory: 29kB; Sort Method: quicksort  Memory: 16089kB
- **64MB**: Sort Method: top-N heapsort  Memory: 29kB; Sort Method: quicksort  Memory: 17118kB
- **256MB**: Sort Method: top-N heapsort  Memory: 29kB; Sort Method: quicksort  Memory: 17118kB

### `03_paridade_etanol_gasolina`

- **4MB**: Sort Method: quicksort  Memory: 1957kB; Planned Partitions: 8  Batches: 9  Memory Usage: 8273kB  Disk Usage: 6672kB
- **16MB**: Sort Method: quicksort  Memory: 1045kB
- **64MB**: Sort Method: quicksort  Memory: 1045kB
- **256MB**: Sort Method: quicksort  Memory: 1045kB

### `04_evento_troca_bandeira`

- **4MB**: Sort Method: quicksort  Memory: 417kB
- **16MB**: Sort Method: quicksort  Memory: 417kB
- **64MB**: Sort Method: quicksort  Memory: 417kB
- **256MB**: Sort Method: quicksort  Memory: 417kB
