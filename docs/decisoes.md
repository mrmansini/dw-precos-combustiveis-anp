# Decisões técnicas

Registro das decisões de modelagem e carga, com a evidência que sustentou cada
uma. Decisão sem medição por trás está marcada como tal.

Estado de referência: sete semestres carregados (2023-01 a 2026-01),
3.029.551 observações, PostgreSQL 18.

---

## 1. Escopo e fonte

**Fonte.** Série histórica de preços de combustíveis da ANP, pesquisa semanal de
preços praticados por revendedores, publicada em arquivos CSV semestrais com
grão de posto, produto e data de coleta.

**Janela.** 2023-01 a 2026-01, sete arquivos. Recorte por espaço disponível, não
por limitação da fonte, que cobre desde 2004.

**Todos os seis produtos, não três.** Carregar gasolina comum, aditivada, etanol,
diesel, diesel S-10 e GNV custa cerca de 40% mais linhas e habilita três análises
que não existiriam de outro modo: o spread comum contra aditivada no mesmo posto
e dia, o spread diesel contra S-10, e o GNV como caso de unidade não comparável.

**Por que esta fonte.** Ela reúne, num só conjunto, volume que justifica
particionamento, uma dimensão cujos atributos mudam de verdade ao longo do tempo,
e um evento de negócio observável — a troca de bandeira — que só é analisável se
o versionamento estiver correto.

---

## 2. Arquitetura de schemas

| Schema | Papel |
|---|---|
| `staging` | Espelho textual do CSV, truncado a cada arquivo |
| `etl` | Catálogo que governa a carga |
| `core` | Dimensões conformadas e fato particionado |
| `ops` | Saúde da execução: runs, migrações, views de anomalia |
| `analytics` | Camada de consumo |

**O catálogo governa o comportamento.** Encoding, delimitador, separador decimal,
formato de data, cabeçalho esperado e janela de cada arquivo vivem em
`etl.source_files`, não em constantes do código de carga. Adicionar um semestre é
inserir uma linha; tratar um layout diferente é preencher uma coluna.

**Regra de negócio no banco, apresentação no consumo.** Constraints e views
versionadas carregam a regra; o BI não reimplementa nada.

**Identificadores em inglês, documentação em português.**

---

## 3. Modelo dimensional

### 3.1 O fato

`core.fct_price_observation`, grão de posto, produto e dia de coleta.

**Sem `purchase_price`.** A coluna `valor_de_compra` existe no layout da fonte e
vem 100% vazia em todos os sete arquivos. Sai do fato, e com ela a métrica de
margem bruta. Analisar margem exigiria cruzar com a série de preços de
distribuição, fora do escopo.

**Sem `brand_key` e `city_key`.** Bandeira e município são atributos da versão do
posto e vivem em `core.dim_station`, que já os carrega na vigência correta.
Replicá-los no fato criaria duas fontes de verdade para o mesmo atributo e
anularia a razão de existir do versionamento.

**Sem `date_key` inteiro.** A chave de partição precisa ser a data, e carregar
`collection_date` e um `date_key` derivado seria a mesma informação repetida em
três milhões de linhas. Desvio consciente da convenção de chave substituta
inteira: `core.dim_date` mantém `date_key` como chave primária e o fato
referencia `full_date`, que é única.

**`NUMERIC`, não `FLOAT`.** Preço é valor monetário exato.

### 3.2 A dimensão versionada

`core.dim_station` implementa SCD Tipo 2. Chave natural é o CNPJ, chave
substituta é `station_key`, e a vigência é `[valid_from, valid_to)` com
`infinity` para a versão corrente.

**Evidência que justificou o versionamento.** Comparando os extremos da janela,
1.784 dos 5.071 CNPJs presentes em ambos apareciam com bandeira diferente. Após a
normalização de rótulo descrita adiante, restaram trocas comerciais reais em
volume suficiente: no conjunto completo, 1.960 trocas de bandeira, sendo 1.021
desbandeiramentos, 802 bandeiramentos e 137 trocas diretas entre distribuidoras.
São 17.631 versões para 14.059 CNPJs.

**A garantia está no banco.** Uma constraint de exclusão GiST impede duas
vigências sobrepostas para o mesmo CNPJ:

```sql
EXCLUDE USING gist (cnpj WITH =, daterange(valid_from, valid_to) WITH &&)
```

Se a carga tiver defeito, ela falha na hora, em vez de produzir um histórico
silenciosamente corrompido.

**`attribute_hash` é coluna gerada `STORED`.** Não existe estado em que a versão
guarde um hash que não corresponda aos próprios atributos. No PostgreSQL 18,
coluna gerada sem qualificador passa a ser virtual — o `STORED` é explícito.

**`complement` fica fora do hash.** É texto livre e instável na fonte;
versionar por causa dele geraria versão nova sem mudança de fato.

**Primeira versão abre na primeira observação**, não no início do período do
arquivo: só se sabe que o posto existia a partir de quando foi observado.

### 3.3 Bandeira com tabela de alias

**O problema, medido.** Das mudanças de bandeira entre os extremos da janela, 64%
eram renomeação de rótulo: `VIBRA ENERGIA` para `VIBRA` levou 1.012 postos, e
`ALESAT` para `ALE` levou 139. Sem tratamento, o SCD Tipo 2 abriria cerca de
1.150 versões falsas e a análise de evento viraria ruído.

**A solução.** `core.dim_brand` guarda o nome canônico e `core.brand_alias` mapeia
cada grafia da fonte para ele, com `is_rename` distinguindo mudança de rótulo de
mudança de identidade. Bandeira desconhecida não derruba a carga: entra marcada
com `needs_review` e aparece em `ops.v_brands_to_review`.

**Um caso resolvido na curadoria.** A semente escreveu `ATEM'S`; a fonte grafa
`ATEM' S`, com espaço. A canônica ficou sem postos e a resolução automática criou
uma segunda entrada para a mesma empresa. Oitenta versões foram reapontadas e a
grafia da fonte virou alias.

**Um caso decidido contra a primeira impressão.** `NEXTA` surge em agosto de 2025
com volume próximo ao de `TOTALENERGIES`, o que sugeria renomeação. Os dados não
sustentam: só 18 dos 32 postos migraram, dez seguem com `TOTALENERGIES` vigente,
as transições se espalham por 4,5 meses em onze datas distintas, e 12 dos 30
postos `NEXTA` nunca estiveram na outra bandeira. O contraste com a renomeação
confirmada é o critério — `VIBRA ENERGIA` levou praticamente a base inteira de
uma vez. Ficam como bandeiras distintas. Se a classificação estiver errada, são
18 eventos mal classificados em 1.960, abaixo de 1%.

### 3.4 Grão e desempate

**O grão foi validado antes de fixado.** Nos arquivos perfilados, zero duplicatas
de posto e produto por dia e por semana. A chave primária é
`(collection_date, station_key, product_key)`.

**A semana é o grão analítico, o dia é o registro.** Zero duplicatas por semana
ISO significa que cada posto é pesquisado no máximo uma vez por semana; a data é
quando o pesquisador passou. A distribuição por dia da semana muda entre os
arquivos — sábados aparecem em 2025 e não existiam em 2023. Séries por data crua
capturam mudança de rota de coleta, não de preço. `core.dim_date` carrega
`survey_week_key` para agregação correta.

**Desempate declarado: fica o menor preço.** A carga completa revelou 20 casos que
o perfil não pegou — 14 em 2024-01 e 6 em 2026-01 — em que a fonte repete o mesmo
posto e produto na mesma data. Em 16 os preços são idênticos; em 4 divergem de 17
a 18 centavos. O padrão é claro: o posto inteiro replicado em duas datas
próximas, com todos os produtos de uma vez, e atributos idênticos entre as
linhas. Como o levantamento mede preço praticado ao consumidor, entre duas
medições válidas prevalece a menor. A regra é aplicada por `DISTINCT ON` na
carga; o `ON CONFLICT` volta a ser apenas proteção contra reprocessamento, e não
o mecanismo de desempate — que dependeria da ordem de leitura do arquivo.

### 3.5 Particionamento

Range mensal por trimestre, 16 partições de 2023Q1 a 2026Q4, mais `DEFAULT`.

**A `DEFAULT` deve permanecer vazia.** Linha ali é data fora do calendário, ou
seja, erro de dado. `ops.v_partition_health` sinaliza a anomalia. O custo
assumido é conhecido: com `DEFAULT` não vazia, criar partição nova exige varrê-la.

**Particionamento também é ciclo de vida.** Se o espaço apertar, derrubar um
trimestre antigo é um comando, e a mesma view embasa a escolha.

---

## 4. Carga

Quatro etapas, cada uma registrada em `ops.load_runs`: `stage`, `transform`,
`load_stations`, `load_facts`.

**Camada única de normalização.** `staging.v_price_survey_clean` converte o texto
bruto e classifica cada linha com o motivo da rejeição, ou nulo se está apta.
Validação e carga leem da mesma view e nunca divergem sobre o que é uma linha
válida.

**Data montada em ISO antes do cast**, em vez de `to_date` com máscara: o
resultado não depende do `DateStyle` da sessão, e `pg_input_is_valid` rejeita data
impossível sem lançar exceção por linha.

**Ordem das regras de rejeição importa.** Cada linha recebe o primeiro motivo que
se aplica, e o mais genérico vem antes. `empty_row`, `cnpj_missing` e
`cnpj_length` são três situações distintas e foram separadas justamente porque a
primeira investigação as confundiu.

**Amostra de `raw_row`, não o conjunto todo.** Guardar a linha íntegra de cada
rejeição não escala: uma regra que dispare para o arquivo inteiro geraria
centenas de milhares de documentos JSON, consumindo mais espaço que o próprio
fato. Ficam 100 exemplos por regra; o detalhe textual fica em todas.

**Carga cronológica, verificada.** O SCD Tipo 2 reconstrói vigências em ordem;
carregar um arquivo anterior a um já carregado produziria intervalos invertidos.
A verificação é explícita e aborta antes de tocar no banco.

**Idempotência, e o defeito que ela escondia.** A primeira versão do guard
reconhecia um intervalo já aplicado por igualdade de `valid_from`. Passava no
teste de recarregar o mesmo arquivo em seguida e falhava no de recarregar um
arquivo antigo com o warehouse completo — porque quando um posto muda no meio do
semestre, o primeiro intervalo repete atributos de uma versão aberta num arquivo
anterior, com `valid_from` mais antiga. A comparação correta é por contenção: o
intervalo já foi aplicado se existe versão cuja vigência cobre a data observada e
cujos atributos batem. O defeito só apareceu porque a recarga completa foi feita.

**`TRUNCATE`, não `DELETE`, ao limpar a staging.** `DELETE` apenas marca as linhas
como mortas e o espaço só retorna após `VACUUM` — 19 MB parados por semestre.

**Reprodutibilidade demonstrada.** O fato foi truncado e reconstruído a partir dos
sete arquivos, chegando ao mesmo total de 3.029.551 observações. A carga completa
leva cerca de 6 minutos.

**`MERGE` não foi usado no SCD Tipo 2.** Encerrar a versão anterior e inserir a
sucessora são duas operações sobre linhas diferentes da mesma tabela, e um `MERGE`
aplica uma ação por linha de origem. O laço explícito é mais lento e mais legível,
e o volume — uma iteração por posto por versão — não justifica otimizar.

---

## 5. Espaço

Teto de 500 MB. Medições após `REINDEX`:

| Objeto | Tamanho |
|---|---|
| Fato, heap (17 partições) | 174 MB |
| Fato, chave primária | 117 MB |
| `core.dim_station` | 11 MB |
| Demais objetos e catálogo | ~9 MB |
| **Total** | **311 MB** |
| **Folga** | **189 MB** |

**A chave primária custa quase tanto quanto o dado**, porque replica as três
colunas que são quase tudo que a tabela tem — o heap só acrescenta `sale_price` e
`source_file_id`.

**Uma medição que quase levou à decisão errada.** Logo após a recarga, a PK
media 181 MB e o banco 379 MB. O número sugeria migrar `station_key` de `bigint`
para `int` como economia relevante. Um `REINDEX` devolveu 64 MB: o excesso era
padrão de preenchimento das páginas reconstruídas por inserção sequencial, não
característica do modelo. Partir para a migração de tipo antes de reindexar teria
custado meia hora para resolver o que dois minutos de manutenção resolveram, e o
ganho seria atribuído à decisão errada.

**Alavancas disponíveis, em ordem de custo:**

1. Medir um índice por vez, derrubando entre rodadas — custo zero em espaço
2. Derrubar 2023Q1 e 2023Q2 — devolve cerca de 48 MB, reduz a janela para 3 anos
3. Reduzir `station_key` para `int` — devolve cerca de 30 MB, exige derrubar a FK,
   alterar os dois lados e reescrever o fato

---

## 6. Limitações conhecidas

**Posto que sai da amostra permanece vigente.** A carga encerra versão quando
atributos mudam, nunca quando o posto desaparece da pesquisa. Os 14.059 CNPJs
estão todos com `is_current`, incluindo os que não aparecem desde 2023. Consultas
sobre "postos ativos hoje" precisam filtrar por presença recente no fato, não por
`is_current`.

**A amostra encolhe ao longo da janela.** De 8.875 postos e 460 municípios em
2023-01 para 7.842 e 413 em 2025-02, com 5.071 CNPJs em comum. Qualquer série
longa que não controle isso mede rotatividade de amostra, não preço. Comparações
plurianuais exigem painel balanceado.

**Sem preço de compra**, logo sem margem.

**GNV não é comparável aos demais**, por estar em R$/m³ contra R$/litro. A fonte
ainda grafa a unidade de dois jeitos entre arquivos.

**9.114 linhas inteiramente vazias em 2025-01**, artefato de exportação daquele
arquivo específico. Nenhum outro semestre apresenta o problema.

**O CNPJ muda de formato entre arquivos** — mascarado em 2023, sem máscara em
2025, com espaço à esquerda em alguns. Normalizado na carga, mas é sintoma de que
a fonte é reprocessada, o que levanta dúvida sobre mudanças de endereço e razão
social observadas na fronteira entre semestres: parte delas pode ser
reprocessamento, não mudança real.

**A classificação de `NEXTA` como bandeira independente** é decisão apoiada em
evidência circunstancial, com margem de erro de 18 eventos em 1.960.

**A carga é manual.** Não há agendamento nem execução automatizada; os arquivos
são baixados e carregados sob demanda.

**Não há índices secundários no fato.** Ausência deliberada até haver plano de
execução que os justifique.

**A verificação de schema cobre estrutura, não conteúdo.** São 19 checagens, cinco
delas negativas — confirmam que as constraints recusam dado inválido. Não há
testes sobre o resultado analítico das consultas.
