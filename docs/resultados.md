# Resultados

Achados analíticos obtidos sobre o modelo. Decisões de modelagem estão em
`decisoes.md`; medição de desempenho, em `performance.md`.

Base: 3.029.551 observações de preço entre 02/01/2023 e 29/06/2026, cobrindo
14.059 postos em 462 municípios.

---

## 1. Efeito da troca de bandeira sobre o preço

A pergunta que justifica o versionamento da dimensão de postos: quando um posto
troca de bandeira, o que acontece com o preço que ele cobra?

### Desenho

Para cada troca identificada em `core.v_brand_changes`, comparam-se as
observações do mesmo posto nas oito semanas anteriores e nas oito posteriores à
data da mudança. A diferença bruta não serve: se a troca coincide com uma alta
geral do mercado, o movimento seria atribuído ao evento. Por isso subtrai-se a
variação da mediana do próprio município no mesmo período, e a coluna resultante
— `excess_change` — é o que se analisa.

Exige-se pelo menos quatro observações de cada lado, o que reduz 1.021
desbandeiramentos a 443 casos analisáveis para a gasolina comum.

### Validação por grupo de controle

O primeiro resultado levantou suspeita: desbandeiramento e bandeiramento
apontavam na mesma direção, quando a hipótese econômica previa sinais opostos.
Isso é sintoma clássico de viés no cálculo.

O teste, em `sql/queries/05_controle_placebo.sql`: aplicar o mesmo cálculo a
postos que nunca mudaram atributo algum em toda a janela, atribuindo a eles as
datas dos eventos reais ocorridos no mesmo município.

| Grupo | Casos | Efeito médio | Mediana | Erro padrão | Abaixo do mercado |
|---|---:|---:|---:|---:|---:|
| Desbandeiramento | 443 | −0,0294 | −0,0140 | 0,0056 | 60,3% |
| Bandeiramento | 343 | −0,0084 | −0,0050 | 0,0049 | 55,1% |
| Troca de distribuidora | 36 | +0,0033 | −0,0050 | 0,0105 | 55,6% |
| **Placebo** | **12.193** | **+0,0041** | **+0,0008** | **0,0010** | **48,7%** |

O placebo veio limpo: efeito praticamente nulo e proporção de 48,7% abaixo do
mercado, o que é a moeda justa esperada de postos sem evento. O cálculo não
fabrica efeito negativo, e a suspeita de reversão à média não se sustentou.

### Resultado

Com o controle validado, o desbandeiramento tem efeito robusto: −2,94 centavos
contra +0,41 do placebo, distância de 5,9 erros padrão. Pelo teste de proporção,
que não depende de suposição sobre a distribuição, 60,3% contra 48,7% com n=443
dá z ≈ 4,9.

A hipótese original — que os sinais se invertessem — está errada. Os dois tipos
de evento reduzem o preço; o desbandeiramento reduz 3,5 vezes mais. A leitura que
sobrevive é que qualquer troca de bandeira envolve renegociação de contrato de
fornecimento e tende a ser seguida de queda, e que largar a bandeira, abrindo
acesso ao mercado spot, produz queda bem maior. Os 36 casos de troca direta entre
distribuidoras, com efeito nulo, são consistentes com isso, mas a amostra é
pequena demais para sustentar a interpretação sozinha.

### O resultado ante o que se conhece do setor

O efeito de desbandeiramento tem direção esperada e mecanismo documentado. A
regulação da ANP determina que o posto que exibe a marca de um distribuidor só
pode adquirir combustível daquele distribuidor, enquanto o posto sem bandeira
negocia livremente com qualquer distribuidor autorizado. É esse contrato de
exclusividade que a literatura de mercado aponta como origem da diferença de
preço.

Duas referências públicas dão a ordem de grandeza:

- Dados de mercado dos Estados Unidos de agosto de 2024 mostram o posto
  bandeirado precificando cerca de 3,15 centavos de dólar acima da média da rua
  e o sem bandeira 4,85 abaixo, com o diferencial entre os dois grupos chegando
  a 8 centavos por galão.
- No Brasil, o estudo *Impactos da Entrada de Distribuidoras de Combustíveis no
  Segmento de Revenda Varejista*, da Tendências Consultoria para a
  Fecombustíveis, conclui que quanto maior a participação de postos de bandeira
  branca num município, menor tende a ser o preço médio dos combustíveis ali.

**As magnitudes não são diretamente comparáveis.** Aqueles números medem
diferença de nível entre grupos distintos de postos, algo perto de 2% do preço.
O resultado desta análise mede outra coisa: quanto o mesmo posto muda depois do
evento, cerca de 0,5%. Um posto que larga a bandeira não converge para a média
dos sem bandeira em oito semanas, então o efeito de evento ser menor que o
diferencial de nível é o esperado, não uma inconsistência.

**O efeito de bandeiramento não tem correspondente na literatura.** O material
disponível descreve o movimento inverso: adotar a marca de uma distribuidora é
apresentado como forma de sustentar margem, porque o consumidor associa a marca
a garantia de qualidade. Que adotar bandeira também reduza o preço em relação ao
mercado local é o achado que permanece sem explicação estabelecida.

### Hipótese testada e não sustentada: efeito por distribuidora

**Formulação.** Se o efeito de bandeiramento vem das condições de contrato, e não
do consumidor, ele deveria variar conforme quem absorve o posto: distribuidoras
regionais em expansão, disputando participação, ofereceriam termos mais
agressivos que as grandes estabelecidas. A prática é lícita — o CADE já
reconheceu que distribuidoras pratiquem preços de fornecimento diferentes
conforme o contrato de cada revendedor.

**Teste.** Desagregação dos 343 eventos de bandeiramento em gasolina comum por
`brand_after`, restrita a grupos com dez ou mais casos.

| Bandeira adotada | Casos | Efeito médio | Erro padrão | t |
|---|---:|---:|---:|---:|
| RODOIL | 11 | −0,0328 | 0,0453 | −0,7 |
| VIBRA | 82 | −0,0130 | 0,0106 | −1,2 |
| RAIZEN | 81 | −0,0071 | 0,0081 | −0,9 |
| IPIRANGA | 89 | −0,0064 | 0,0091 | −0,7 |
| ALE | 31 | +0,0080 | 0,0206 | +0,4 |

**Resultado: nenhum grupo se distingue de zero.** O maior `t` em módulo é 1,2. O
grupo de maior efeito aparente, RODOIL, tem erro padrão de 0,0453 sobre onze
casos — o ruído é maior que o efeito. E o único grupo com sinal positivo, ALE,
tem `t` de 0,4.

A leitura ingênua da coluna de efeito sugeriria uma história: duas distribuidoras
regionais nas duas pontas, três grandes agrupadas no meio. Com o erro padrão ao
lado, a história desaparece. Os cinco números são compatíveis com um único valor
em torno de −0,008.

**Conclusão.** A desagregação não refuta a hipótese do contrato; ela não tem
poder para testá-la. O efeito agregado de bandeiramento depende dos 343 casos
reunidos, e a amostra por distribuidora é pequena demais para revelar estrutura
interna. Testar a hipótese exigiria outro desenho, provavelmente com dado de
preço de fornecimento, que a fonte da ANP não traz.

**Verificação lateral do tratamento de aliases.** O grupo ALE motivava
desconfiança específica, porque `ALESAT` → `ALE` foi uma renomeação de rótulo que
atingiu 139 postos e é resolvida pela tabela de aliases (ver `decisoes.md`). Se
alguma dessas transições tivesse escapado, apareceria aqui como bandeiramento
falso, e um evento falso não teria motivo para mexer no preço. A checagem de
`brand_before` nos 31 casos devolveu `BRANCA` em todos: nenhum resíduo de
renomeação, e o `+0,0080` é ruído, não artefato de classificação.

### Ressalvas

**Magnitude modesta.** Três centavos sobre uma gasolina de R$ 6 é meio por cento.
Robusto estatisticamente, pequeno economicamente.

**Associação, não causa.** Um posto que troca de bandeira provavelmente já
passava por reposicionamento comercial. O desenho não separa o efeito da troca do
efeito daquilo que motivou a troca.

**O controle não é pareado.** Postos estáveis são, por definição, uma população
mais previsível. O grupo valida o método de cálculo; não elimina seleção. Esta é
a ressalva mais séria do desenho: o placebo prova que a conta não fabrica efeito,
não que os postos que trocam de bandeira seriam comparáveis aos que não trocam.

---

## 2. Paridade etanol/gasolina

A regra prática de mercado é a dos 70%: abaixo dessa razão o etanol tende a
compensar, porque rende menos por litro.

Percentual de semanas em que o etanol compensou, por UF, entre as unidades com
mais de cem semanas de observação:

| UF | Semanas favoráveis | Total | % |
|---|---:|---:|---:|
| MT | 999 | 1.089 | 91,7 |
| SP | 13.859 | 17.213 | 80,5 |
| MS | 663 | 944 | 70,2 |
| PR | 2.824 | 4.432 | 63,7 |
| GO | 1.750 | 2.751 | 63,6 |
| MG | 4.841 | 8.648 | 56,0 |
| DF | 89 | 183 | 48,6 |
| ES | 386 | 1.554 | 24,8 |

O ordenamento reproduz a geografia da produção de cana e o custo de transporte:
Centro-Oeste e São Paulo no topo, Sudeste litorâneo bem abaixo. Nenhuma parte do
modelo foi construída com essa informação, então o resultado funciona como
verificação independente da consistência das dimensões, do versionamento e do
rollup.

**Reprodução pela camada de consumo.** As views `analytics.v_site_*` (migrações
013 a 015), construídas depois para alimentar o dashboard publicado, chegam aos
mesmos percentuais por um caminho diferente — pivô do rollup semanal e agregação
no cliente, em vez da view analítica original. A coincidência serve de teste de
regressão da camada de consumo.

**Cobertura da paridade.** O pivô descarta município-semana que não tenha as duas
séries: 1.327 de 70.981 pares pesquisados, ou 1,9%, dos quais 1.298 têm apenas
gasolina. Dois municípios ficam integralmente de fora, Parintins e Tefé, ambos no
Amazonas, por nunca terem série de etanol na mesma semana da gasolina.

---

## 3. Cobertura da amostra

A pesquisa encolheu ao longo da janela. Observações de posto e produto na
primeira e na última semana:

| Semana | Observações |
|---|---:|
| 02/01/2023 | 13.215 |
| 29/06/2026 | 11.472 |

Queda de 13%. Entre os arquivos extremos, os postos distintos caíram de 8.875
para 7.842 e os municípios de 460 para 413, com apenas 5.071 CNPJs presentes nos
dois.

Isso não é curiosidade: qualquer série plurianual que não controle a composição
da amostra mede rotatividade de postos, não preço. `analytics.v_sample_coverage`
existe para tornar esse controle possível, e comparações longas exigem painel
balanceado.

### A série não é contínua

A construção do dashboard obrigou a olhar a cobertura semana a semana, e a
tendência de 13% escondia um comportamento diferente: a série tem degraus, e eles
caem nas fronteiras entre arquivos semestrais.

Maiores quedas de uma semana para a outra, em municípios com gasolina comum:

| Semana | Anterior | Cobertura | Variação | Natureza |
|---|---:|---:|---:|---|
| 29/06/2026 | 382 | 284 | −98 | Última semana da janela, truncada |
| 14/07/2025 | 365 | 281 | −84 | Início do mergulho de 2025 |
| 01/07/2024 | 417 | 339 | −78 | Primeiro dia do arquivo 2024-02 |

A queda de 01/07/2024 coincide exatamente com o início do arquivo do segundo
semestre. A ANP redefine a amostra ao publicar cada arquivo, e a série não é
comparável através dessas datas sem ressalva. A densidade — postos por município
— sobe nesses mesmos pontos, o que confirma o mecanismo: a agência retira
municípios inteiros e mantém o volume de coleta nos que permanecem.

### Semanas de borda são truncadas por construção

A primeira e a última semana da janela caem cerca de 26% abaixo da cobertura
típica, não por falha de coleta, mas porque o arquivo semestral começa e termina
no meio de uma semana ISO. O efeito sobre os resultados é material: no Paraná, a
paridade da última semana aparecia em 61,5% contra 63,0% da semana anterior,
diferença que vinha inteiramente da amostra do estado ter caído de 26 para 16
municípios.

`analytics.v_site_week_scope` (migração 014) exclui as duas semanas de borda do
consumo. A regra é estrutural, não estatística — ver abaixo.

### Hipótese testada e descartada: corte por limiar de cobertura

**Formulação.** Em vez de identificar as bordas, descartar automaticamente toda
semana cuja cobertura ficasse abaixo de 85% da mediana histórica nacional.

**Resultado.** A regra cortou as bordas corretamente e cortou junto 16 semanas
contíguas entre 14/07/2025 e 27/10/2025, quando a cobertura caiu de cerca de 370
para 270 municípios e depois se recuperou sozinha. Isso é cobertura real da
fonte, e removê-la abriria um vão de quatro meses no meio da série — defeito pior
que o problema original.

A causa do erro foi usar a mediana de toda a janela como referência: como a
cobertura cai 13% ao longo do período, a mediana histórica fica puxada para cima
e o limiar passa a acusar semanas normais do fim da série.

**Regra adotada.** Corte estrutural, apenas a primeira e a última semana da
janela, sem limiar a calibrar. A cobertura de cada semana passou a ser exposta ao
consumo (`v_site_week_scope.cities`) em vez de usada para suprimir dado.

---

## 4. Limitações do dado que restringem análise

**`core.dim_city.ibge_code` vem inteiramente nulo** — 462 de 462 municípios. A
coluna existe no modelo e a fonte nunca a preenche, o que inviabiliza junção com
malha geográfica oficial sem um de-para por nome e UF. Análise espacial e mapas
ficam fora de alcance sem trabalho adicional de conciliação.

**`city_name` não é chave.** VALENCA existe na Bahia e no Rio de Janeiro, e é o
único nome duplicado na dimensão. Qualquer agregação por nome de município
colapsa as duas numa série só, produzindo um resultado plausível e errado.
Análises devem usar `city_key`.

**Sem preço de compra**, logo sem margem. A coluna existe no layout da fonte e
vem vazia em todos os arquivos, o que impede separar movimento de custo de
movimento de margem — limitação central para interpretar o efeito de bandeira.
