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

### Ressalvas

**Magnitude modesta.** Três centavos sobre uma gasolina de R$ 6 é meio por cento.
Robusto estatisticamente, pequeno economicamente.

**Associação, não causa.** Um posto que troca de bandeira provavelmente já
passava por reposicionamento comercial. O desenho não separa o efeito da troca do
efeito daquilo que motivou a troca.

**O controle não é pareado.** Postos estáveis são, por definição, uma população
mais previsível. O grupo valida o método de cálculo; não elimina seleção.

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
