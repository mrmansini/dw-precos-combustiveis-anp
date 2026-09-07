# Olá, eu sou o Felipe 👋

Construo o caminho que o dado percorre até virar decisão — **da API até o dashboard.**

Sou Analista de Dados formado em Economia. Não paro na query: entendo o número, o processo que gerou ele e o impacto dele no negócio.

## O que eu faço

- 🔌 **Ingestão** — integrações via API REST (CRM, plataformas web, planilhas), tratando token, paginação, falha e reprocessamento.
- 🗄️ **Armazenamento** — modelagem dimensional e manutenção de bases PostgreSQL como fonte única da verdade.
- ⚙️ **Automação** — pipelines em n8n e Python que substituem processo manual.
- 📊 **Visualização** — dashboards em Power BI com KPIs definidos junto às áreas de negócio, e publicação na web quando o público é aberto.

## Alguns números

*Como Analista de Dados, desde jan/2025:*
- ⏱️ **30+ processos manuais automatizados** com n8n e Python — cerca de 80h/mês devolvidas ao time
- 📈 **10+ dashboards estratégicos** em Power BI (operações, SLA de suporte, funil comercial)

*Formação:*
- 🥇 1º lugar da turma de Ciências Econômicas na UEL (Honra ao Mérito)

## Stack

`Python` `SQL` `PostgreSQL` `Power BI (DAX / Power Query)` `n8n` `Docker` `APIs REST` `GitHub Actions` `Azure (AZ-900)` `Excel avançado`

## Projetos em destaque

### ⛽ [dashboard-precos-combustiveis](https://github.com/mrmansini/dashboard-precos-combustiveis)

Dashboard público de quatro páginas sobre preços de combustíveis no Brasil: quando o etanol compensa em cada município, preço por estado e produto, o efeito da troca de bandeira, e a cobertura da própria amostra.

A arquitetura é invertida em relação a um BI convencional. As consultas rodam no momento do build, dentro do GitHub Actions, e o que vai ao ar é um site estático. O banco nunca fica exposto ao visitante, não há tempo de espera para acordar o serviço, e a credencial de leitura só existe como secret de CI.

As decisões visuais são apoiadas em medição, e o README explica cada uma. CSV em vez de Parquet, porque 2,88 MB viram 513 KB sob gzip. Ponto em vez de barra nos rankings de eixo cortado, porque o comprimento de uma barra é lido como proporcional e num eixo que não começa em zero isso exagera uma diferença de 21% para o que parece cinco vezes.

A quarta página existe porque uma queda de preço e um encolhimento da amostra produzem o mesmo movimento na linha. Ela revelou que a série não é contínua: a cobertura tem degraus nas viradas de semestre, quando a ANP publica um arquivo novo e redefine a lista de municípios pesquisados.

**[Ver dashboard ao vivo →](https://mrmansini.github.io/dashboard-precos-combustiveis/)**

`Observable Framework` `D3` `Python` `PostgreSQL` `GitHub Actions` `GitHub Pages`

---

### 🗄️ [dw-precos-combustiveis-anp](https://github.com/mrmansini/dw-precos-combustiveis-anp)

O data warehouse dimensional por trás do dashboard acima: 3 milhões de observações da pesquisa semanal da ANP, 14 mil postos, 3 anos e meio.

Cada observação está ligada à bandeira e ao endereço que o posto tinha **naquela data**, não aos atuais — a dimensão de postos é versionada por SCD Tipo 2, e a garantia de que não existem duas vigências sobrepostas para o mesmo CNPJ está no banco, numa constraint de exclusão GiST, não no código de carga. O fato é particionado por trimestre.

Isso torna possível a pergunta que o modelo existe para responder: **o que acontece com o preço quando um posto larga a bandeira?** A resposta é queda de 2,94 centavos em relação ao próprio município — pequena em reais, robusta estatisticamente. Antes de afirmar isso, o mesmo cálculo foi aplicado a 12.193 postos que nunca mudaram nada, com datas de evento falsas: o placebo veio nulo, o que descartou a hipótese de que o efeito fosse artefato do método.

Os índices foram escolhidos por medição, não por hábito. Três candidatos foram testados e dois rejeitados com o plano de execução que justificou a rejeição — um deles custaria 91,5 MB para render 5%.

A documentação registra duas hipóteses que não vingaram: um critério estatístico de corte que eliminava quatro meses de dado real junto com o defeito que deveria remover, e uma tentativa de explicar o resultado que ficou sem casos suficientes para ser testada.

`PostgreSQL 18` `Python` `Modelagem dimensional` `SCD Tipo 2` `Particionamento`

---

### 📊 [pipeline-indicadores-bcb](https://github.com/mrmansini/pipeline-indicadores-bcb)

Pipeline que coleta indicadores econômicos do Banco Central (Selic, IPCA, câmbio, IBC-Br) e entrega em dashboard, rodando sozinho todo dia.

Carga incremental idempotente em PostgreSQL, seis validações de qualidade que reprovam a execução quando o dado não confere, e execução diária automatizada via GitHub Actions. A camada analítica alimenta Power BI e Looker Studio sem transformação intermediária.

O README documenta o que a API do SGS não conta na documentação — inclusive o fato de ela responder HTTP 200 com página de erro em HTML.

**[Ver dashboard ao vivo →](https://lookerstudio.google.com/reporting/387b4bf3-1c9c-4a06-9dc5-3f596da96aae)**

`Python` `PostgreSQL` `GitHub Actions` `Power BI` `Looker Studio`

---

### 🔔 [monitor-licitacoes-pncp](https://github.com/mrmansini/monitor-licitacoes-pncp)

Automação em n8n que monitora licitações públicas no PNCP, deduplica no PostgreSQL e avisa no Telegram apenas o que é novo.

O dedup mora no banco, não na ferramenta: `ON CONFLICT DO NOTHING` com `RETURNING` devolve exatamente as linhas inéditas. As respostas da API são classificadas em quatro situações — sucesso, sem resultados, erro de parâmetro e indisponibilidade —, cada uma com tratamento próprio, porque repetir uma requisição malformada é laço infinito e tratar 204 como falha é alarme falso.

Construído durante uma indisponibilidade de seis dias do endpoint principal, o que forçou um modo de desenvolvimento contra resposta real salva em disco. O README registra o incidente, as hipóteses testadas — inclusive a que se mostrou errada — e o que cada falha ensinou.

`n8n` `PostgreSQL` `Docker` `API REST` `Telegram Bot API`

---

## Um pouco de contexto

Antes de dados, passei por perícia judicial econômico-financeira, contabilidade e tesouraria — é de onde vem meu incômodo com número que não bate. Isso entrou no jeito como construo pipeline: audito o cálculo antes de confiar nele.

É também por isso que os READMEs registram as hipóteses que não vingaram. Um projeto que só mostra o que deu certo esconde a parte em que se aprende alguma coisa.

## Contato

📧 felipemansini@hotmail.com · 💼 [LinkedIn](https://linkedin.com/in/felipemansini) · 📍 Rolândia, PR
