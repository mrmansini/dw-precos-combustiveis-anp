# dw-precos-combustiveis-anp

Data warehouse dimensional em PostgreSQL sobre a série histórica de preços de
combustíveis por posto revendedor da ANP. Três milhões de observações, dimensão
de postos versionada por SCD Tipo 2, fato particionado por trimestre, e a camada
analítica que responde o que o modelo foi construído para responder.

---

## O que faz

Carrega os arquivos semestrais da pesquisa de preços da ANP — texto bruto, com
CNPJ ora mascarado ora não, preço com vírgula decimal e linhas de lixo de
exportação — e produz um modelo estrela consultável, onde cada observação está
ligada à bandeira, ao endereço e ao município que o posto tinha **naquela data**,
não aos atuais.

Essa distinção é o ponto do projeto. Um posto que largou a bandeira Ipiranga em
março de 2024 aparece como Ipiranga nas observações de fevereiro e como sem
bandeira nas de abril. Sem isso, qualquer análise de bandeira reescreve o passado
com a informação de hoje.

**Números do estado atual:** 3.029.551 observações entre 02/01/2023 e 29/06/2026,
14.059 postos em 462 municípios, 17.631 versões de posto, 1.960 trocas de
bandeira identificadas, 56 bandeiras canônicas.

---

## O resultado principal

Postos que largam a bandeira reduzem o preço em relação ao próprio mercado.

| Grupo | Casos | Efeito sobre o preço | Abaixo do mercado |
|---|---:|---:|---:|
| Desbandeiramento | 443 | −2,94 centavos | 60,3% |
| Bandeiramento | 343 | −0,84 centavos | 55,1% |
| Troca de distribuidora | 36 | +0,33 centavos | 55,6% |
| Grupo de controle | 12.193 | +0,41 centavos | 48,7% |

O efeito é medido contra a variação da mediana do próprio município no mesmo
período, e validado por um grupo de controle de postos que nunca mudaram atributo
algum, aos quais se atribuíram datas de evento falsas. O controle veio limpo —
48,7% abaixo do mercado é a moeda justa —, o que sustenta os números dos eventos:
o desbandeiramento fica a 5,9 erros padrão do controle.

A hipótese original estava errada. Esperava-se que os sinais se invertessem entre
desbandeiramento e bandeiramento; os dois reduzem o preço, e o desbandeiramento
reduz 3,5 vezes mais. O efeito é robusto estatisticamente e modesto
economicamente: três centavos em uma gasolina de seis reais.

Detalhamento, ressalvas de desenho e o segundo resultado — a paridade
etanol/gasolina, que reproduz a geografia da produção de cana sem que essa
informação esteja em lugar algum do modelo — em [`docs/resultados.md`](docs/resultados.md).

---

## Arquitetura

```
CSV semestral (ANP)
   │
   ├── etl.source_files ─────── catálogo: encoding, delimitador, layout, janela
   │
   ▼
staging.stg_price_survey ────── espelho textual, truncado a cada arquivo
   │                            staging.stg_rejects ── linhas recusadas, com motivo
   ▼
staging.v_price_survey_clean ── camada única de normalização e classificação
   │
   ├──► core.fn_apply_station_scd2() ──► core.dim_station   (SCD Tipo 2)
   │
   └──► core.fn_load_facts() ──────────► core.fct_price_observation
                                          (particionado por trimestre)
   │
   ▼
analytics.mv_weekly_price ───── rollup semanal por município e produto
   │
   └──► views de análise ────── série, dispersão, paridade, evento, cobertura
```

`ops` acompanha tudo: `load_runs` registra cada etapa de cada carga,
`v_load_health` expõe duração e taxa de rejeição, `v_stuck_runs` denuncia execução
interrompida e `v_partition_health` mostra volume e tamanho por partição.

---

## Modelo de dados

O núcleo dimensional. As camadas de carga (`staging`, `etl`) e de operação (`ops`),
mais a view materializada de `analytics`, estão no
[modelo completo](docs/modelo.md).

```mermaid
erDiagram
  CORE_DIM_DATE ||--o{ CORE_FCT_PRICE_OBSERVATION : "data da coleta"
  CORE_DIM_PRODUCT ||--o{ CORE_FCT_PRICE_OBSERVATION : "produto"
  CORE_DIM_STATION ||--o{ CORE_FCT_PRICE_OBSERVATION : "versao vigente"
  CORE_DIM_BRAND ||--o{ CORE_DIM_STATION : "bandeira"
  CORE_DIM_CITY ||--o{ CORE_DIM_STATION : "municipio"
  CORE_FCT_PRICE_OBSERVATION {
    date collection_date PK "chave de particao"
    bigint station_key PK
    smallint product_key PK
    numeric sale_price
  }
  CORE_DIM_STATION {
    bigint station_key PK
    char cnpj "chave natural"
    text legal_name
    int brand_key FK
    int city_key FK
    date valid_from "SCD tipo 2"
    date valid_to "infinity se vigente"
    boolean is_current
  }
  CORE_DIM_BRAND {
    int brand_key PK
    text brand_name UK
    boolean is_unbranded "BRANCA"
  }
  CORE_DIM_CITY {
    int city_key PK
    text city_name
    char uf
    char region
  }
  CORE_DIM_DATE {
    int date_key PK
    date full_date UK
    int survey_week_key "grao analitico"
    date week_start_date
  }
  CORE_DIM_PRODUCT {
    smallint product_key PK
    text product_name
    text unit_of_measure "litro ou m3"
  }
```

**`dim_station` é a única dimensão com duas chaves.** `station_key` é a substituta e
`cnpj` é a natural. É isso que permite ao mesmo posto ter várias linhas — uma por
período de vigência — sem que o fato precise saber disso.

**A bandeira não toca o fato.** Ela chega por `dim_station` e vem sempre na versão
correspondente à data da observação. Ligada direto ao fato, seria a bandeira atual
em todo o histórico.

O fato tem cinco colunas — as três da chave, o preço e a origem. Bandeira e
município ficam de fora de propósito: são atributos da versão do posto, e
replicá-los criaria duas fontes de verdade para o mesmo dado.


---

## Decisões apoiadas em medição

Três exemplos, com os números completos em
[`docs/decisoes.md`](docs/decisoes.md) e [`docs/performance.md`](docs/performance.md).

**Alias de bandeira.** Comparando os extremos da janela, 1.784 de 5.071 postos
apareciam com bandeira diferente. Medindo as transições, 64% eram renomeação de
rótulo: `VIBRA ENERGIA` para `VIBRA` levou 1.012 postos de uma vez, `ALESAT` para
`ALE` levou 139. Sem tratamento, o versionamento abriria cerca de 1.150 versões
falsas e a análise de evento viraria ruído.

**Grão desempatado por regra declarada.** A carga revelou 20 casos em que a fonte
repete o mesmo posto e produto na mesma data, quatro deles com preços diferentes.
Prevalece o menor, aplicado por `DISTINCT ON` na carga. Antes disso, quem
desempatava era a ordem de leitura do arquivo.

**Um índice secundário, não quatro.** Quatro consultas medidas em quatro cenários
de índice. O BRIN em `collection_date` teve efeito nulo, porque compete com o
particionamento e este age primeiro. O B-tree por produto custaria 91,5 MB para
render 5%. Só o B-tree `(station_key, collection_date)` foi aceito: 2,15x na
análise de evento por 46 MB, e é o único que atende um padrão de acesso que a
chave primária estruturalmente não serve.

---

## Aprendizados

**A semana ISO não pertence a um mês.** O rollup semanal foi escrito agrupando
por semana e por mês, e o índice único recusou: a semana 18 de 2026 tem dias em
abril e em maio. O mês passou a ser derivado por regra explícita — a semana
pertence ao mês da sua segunda-feira. Numa camada analítica sem essa constraint,
o erro produziria linhas duplicadas em silêncio.

**Idempotência precisa do teste difícil.** A primeira versão do reconhecimento de
intervalos já aplicados comparava datas de início por igualdade. Passava ao
recarregar o mesmo arquivo em seguida, e falhava ao recarregar um arquivo antigo
com o warehouse completo — porque um posto que muda no meio do semestre gera um
intervalo que repete atributos de uma versão aberta antes, com data de início
anterior. A comparação correta é por contenção de vigência.

**Medir antes de otimizar, e medir de novo antes de concluir.** A chave primária
media 181 MB logo após uma recarga, o que justificaria migrar `station_key` de
`bigint` para `int`. Um `REINDEX` devolveu 64 MB: o excesso era padrão de
preenchimento de páginas, não característica do modelo. A migração de tipo teria
custado meia hora para resolver o que dois minutos de manutenção resolveram.

**Nem todo gargalo é acesso a disco.** Os planos mostravam ordenação em disco,
sinal clássico de memória de trabalho insuficiente. Elevar `work_mem` eliminou o
transbordo e rendeu 9%. O tempo estava na CPU: das consultas de agregação, a
leitura do fato consome 70 ms de 450. Índice ajuda a localizar linha, não a
agregar linha.

**Duas hipóteses derrubadas pelo próprio dado.** A de que o CNPJ de comprimento
irregular tinha perdido zero à esquerda — eram linhas inteiramente vazias, lixo
de exportação de um arquivo específico. E a de que o efeito da troca de bandeira
era artefato do método — o grupo de controle mostrou que não era.

**A fonte é reprocessada.** O CNPJ vem mascarado em 2023 e sem máscara em 2025;
um arquivo traz 9.114 linhas vazias que nenhum outro tem; a unidade do GNV muda
de grafia. Nada disso está documentado na origem, e cada um foi descoberto por
uma carga que quebrou ou por um número que não fechou.

---

## Limitações conhecidas

- **Posto que sai da amostra permanece vigente.** A carga encerra versão quando
  atributos mudam, nunca quando o posto desaparece da pesquisa. Consultas sobre
  postos ativos hoje devem filtrar por presença recente no fato.
- **A amostra encolhe 13% ao longo da janela.** Comparação plurianual sem painel
  balanceado mede rotatividade, não preço.
- **Sem preço de compra**, logo sem margem: a coluna existe no layout da fonte e
  vem vazia em todos os arquivos.
- **GNV não é comparável** aos demais, por estar em R$/m³ contra R$/litro.
- **A carga é manual**, sem agendamento.
- **A verificação cobre estrutura, não conteúdo analítico**: 19 checagens, cinco
  delas negativas, confirmando que as constraints recusam dado inválido.

A lista completa está em [`docs/decisoes.md`](docs/decisoes.md).

---

## Como reproduzir

**Requisitos.** PostgreSQL 15 ou superior — 18 no ambiente de referência —, com
`btree_gist` disponível. Python 3.11+. Aproximadamente 420 MB de armazenamento.

```bash
git clone https://github.com/mrmansini/dw-precos-combustiveis-anp
cd dw-precos-combustiveis-anp

python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt

echo 'DATABASE_URL=postgresql://usuario:senha@host/banco?sslmode=require' > .env

python src/migrate.py         # aplica as 12 migrações
python src/verify_schema.py   # 19 checagens de estrutura e garantias
python src/verify_access.py   # 16 checagens de separação de papéis
```

Baixe os arquivos semestrais da
[série histórica da ANP](https://www.gov.br/anp/pt-br/centrais-de-conteudo/dados-abertos/serie-historica-de-precos-de-combustiveis),
descompacte em `data/raw/` e renomeie no padrão `ca-AAAA-SS.csv`. Depois:

```bash
python src/load.py 2023-01 2023-02 2024-01 2024-02 2025-01 2025-02 2026-01
python src/report_load.py
```

A ordem cronológica é obrigatória e verificada: o versionamento reconstrói
vigências em sequência. A carga completa leva cerca de seis minutos e é
idempotente — reexecutar não duplica nada nem abre versões novas.

Para reproduzir a medição de desempenho, derrube antes o índice criado pela
migração 010; os números publicados foram obtidos sem ele.

```bash
python src/benchmark.py
python src/benchmark_workmem.py
```

---

## Estrutura

```
sql/
  001..012_*.sql          migrações numeradas e idempotentes
  queries/                consultas analíticas, uma por pergunta
src/
  migrate.py              aplica migrações, com ledger e checksum
  load.py                 carga de um ou mais semestres
  verify_schema.py        checagens de estrutura e de garantias
  report_load.py          balanço da carga e reconciliação
  benchmark.py            medição de índices
  benchmark_workmem.py    medição de memória de trabalho
  profile_source.py       perfil dos arquivos brutos
  check_grain.py          checagens que definem o grão
  check_duplicates.py     duplicatas na origem
  inspect_staging.py      inspeção do conteúdo em staging
docs/
  decisoes.md             decisões de modelagem, com a evidência de cada uma
  resultados.md           achados analíticos
  performance.md          medição de índices, com planos completos
  performance-memoria.md  medição de work_mem
  perfil-fonte.md         perfil dos arquivos
  perfil-grao.md          checagens de grão e transições de bandeira
```
