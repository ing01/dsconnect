# API de Integração do DSConnect — guia da IA de Triagem / Análise (18/11/2026)

Para o desenvolvedor que conecta a IA de análise ao DSConnect. Explica **como o
fluxo "Triagem / Análise" funciona pela API**, quais novidades ele usa e o que
conferir antes de ligar. Complementa o guia de 09/11/2026
(`api_integracao_ajustes_para_dev.md`); a referência completa de campos e
respostas está no Swagger (grupo **Ticket Routing API**).

> **Disponibilidade:** implementado e documentado; **entra no ar no próximo
> deploy** (a Duesoft avisa). Os campos `observation`, `company_id` e
> `company_classification_level` dependem das migrations desse deploy: antes dele
> eles não existem.

- **Base:** `https://dsconnect.duesoft.com.br/api/v1/integrations`
- **Autenticação:** cabeçalho `X-Ticket-Api-Key: <chave>`.
- **Limite:** 120 chamadas por minuto por chave (429 em JSON com `retry_after`).
- **Compatibilidade:** nada foi removido ou renomeado; só foram **acrescentados**
  rotas e campos.

---

## 1. O fluxo, de ponta a ponta

```
Mesa "7 - Triagem / Análise", estágio "Pendente"
        │  1. a IA detecta o ticket e o move
        ▼
estágio "Em análise"
        │  2. a IA analisa, grava tudo em `observation`
        ▼
   ┌────┴─────────────────────────────────────────────────────┐
   │ faltou informação ........ estágio "Revisão Humana"       │
   │ melhoria, sem Nível ...... estágio "Classificado" (Mesa 7)│
   │ melhoria, Nível 1, 2 ou 3  Mesa "5 - Banco de ideias" › "Análise"
   │ melhoria, Nível 4 ou 5 ... Mesa "4 - Especialista" › "Melhoria"
   │ bug / erro ............... Mesa "4 - Especialista" › "GAP"
   └──────────────────────────────────────────────────────────┘
```

| Etapa | Chamada |
|---|---|
| Descobrir os ids das Mesas e Estágios (uma vez) | `GET /teams` |
| Achar os tickets a analisar | `GET /tickets?ticket_column_id=<id de Pendente>` |
| Ler o ticket inteiro | `GET /tickets/:id` (e `/tickets/:id/comments`, `/attachments`) |
| Iniciar a análise | `PATCH /tickets/:id` com `ticket_column_id` de "Em análise" |
| Achar a empresa e o Nível | `GET /companies?...` (seção 3) |
| Registrar a análise e rotear | **um único** `PATCH /tickets/:id` (seção 5) |

---

## 2. Passo 1 — descobrir ids e regras dos Estágios

Use **ids**, não nomes (os nomes "7 - Triagem / Análise" e "Pendente" podem ser
renomeados). Guarde o resultado e atualize de tempos em tempos.

```
GET /teams
```
```json
[{ "id": 12, "name": "7 - Triagem / Análise",
   "ticket_columns": [
     { "id": 81, "name": "Pendente",
       "requires": { "assignee": false, "due_date": false, "scheduled_at": false, "appointment": false } },
     { "id": 82, "name": "Em análise", "requires": { "...": false } }
   ] }]
```

**Novo:** `requires` mostra o que o Estágio exige de um ticket que entra nele.
Se algum valor for `true`, mande o dado **na mesma chamada** que move o ticket
(seção 4); caso contrário o movimento responde **422** e o ticket não muda.

> Hoje o esperado é que os Estágios do fluxo **não** tenham nenhuma exigência.
> Confira no `GET /teams`.

---

## 3. Achar a empresa e o Nível — `GET /companies` (novo)

A IA não precisa mais depender de o ticket já ter empresa: ela consulta.

| Filtro | O que faz |
|---|---|
| `query` | parte do nome, razão social, domínio ou código (sem diferenciar maiúscula) |
| `cnpj` | o documento inteiro, com ou sem pontuação (único na conta) |
| `codigo` | o código exato (único na conta) |
| `classified` | `true` só as que já têm Nível; `false` só as sem Nível |
| `page`, `per_page` | paginação (até 100 por página) |

```
GET /companies?cnpj=11.222.333/0001-81
```
```json
{ "payload": [{ "id": 940, "name": "Alfa Mercado", "legal_name": "Alfa Mercado Ltda",
                "cnpj": "11222333000181", "codigo": "A-100", "domain": null,
                "classification_level": 4, "blocked": false }],
  "meta": { "count": 1, "current_page": 1 } }
```

- `classification_level` é o **Nível da empresa, de 1 a 5**; `null` = **não
  classificada**.
- `GET /companies/:id` devolve uma empresa. De outra conta ou inexistente: **404**.
- Se o ticket **já tem empresa**, não precisa consultar: o detalhe
  (`GET /tickets/:id`) traz `company.id` e `company.classification_level`, e a
  lista traz `company_id` e `company_classification_level`.
- Para **ligar a empresa ao ticket** (quando ele veio sem), envie `company_id` no
  `PATCH`. Para **gravar o Nível** de uma empresa não classificada, envie
  `company_classification_level` (1 a 5) no `PATCH`. O Nível é da **empresa**:
  vale para todos os tickets dela. Normalmente a IA **não** deve inventar o
  Nível — empresa sem Nível vai para "Classificado" para uma pessoa classificar.

---

## 4. Passo 2 — iniciar a análise e mover entre estágios

```bash
curl -X PATCH "$BASE/tickets/123" -H "X-Ticket-Api-Key: $KEY" \
  -H "Content-Type: application/json" -d '{ "ticket_column_id": 82 }'
```

- Só `ticket_column_id`: a Mesa é a do Estágio (serve para mover entre Mesas).
- Mover **dispara as automações do estágio** de destino, como no painel
  (mensagens automáticas ao cliente, mudança de status etc.). Confirme que os
  estágios do fluxo não enviam mensagem ao cliente sem querer.
- **Estágio com exigências** (`requires` verdadeiro): envie junto, na mesma chamada:

| Exigência | Campo no `PATCH` |
|---|---|
| `assignee` | `assignee_id` (usuário da conta; veja `GET /users`) |
| `due_date` | `due_date` (ISO 8601, ex.: `2026-12-01T18:00:00-03:00`) |
| `scheduled_at` | `scheduled_at` (ISO 8601) |
| `appointment` | **não dá pela API** (só o painel cria apontamento) |

`due_date` e `scheduled_at` em branco **limpam** o campo; data inválida: **422**
com o campo em `attributes`.

---

## 5. Passo 3 — registrar a análise e rotear (uma chamada)

Faça a gravação e o movimento **no mesmo `PATCH`**: ele é atômico (se algo
falhar, nada é aplicado).

```bash
curl -X PATCH "$BASE/tickets/123" -H "X-Ticket-Api-Key: $KEY" \
  -H "Content-Type: application/json" -d '{
    "observation": "Análise da IA: melhoria no cadastro de produtos...",
    "estimativa_original_horas": 6,
    "ticket_column_id": 91,
    "note": "Melhoria; empresa nível 4 → Especialista > Melhoria"
}'
```

### 5.1 Observação — `observation`
- Texto livre do ticket, **onde a IA deve gravar toda a análise**. Aparece no
  ticket (cartão "Observação") e em `GET /tickets` / `GET /tickets/:id`.
- Enviar o texto **insere ou altera**; `""` ou `null` **remove**; omitir a chave
  **mantém**.
- **Cada `PATCH` substitui o texto inteiro.** Para acrescentar, leia
  `observation`, some o novo trecho e envie o conjunto.
- Em Mesas com o módulo de **Desenvolvimento** ativo, o cartão não aparece na
  tela (a API grava e lê normalmente).
- Ticket já finalizado (fechado/cancelado) não pode ser alterado.

### 5.2 Estimativa original (horas) — `estimativa_original_horas`
- Número de horas (`6`, `2.5` ou `"2,5"`), inserido, alterado ou removido (em
  branco/`null`) como a observação. Vem no `GET` (detalhe e lista) como número
  ou `null`. Negativo ou texto: **422**. Também aceito ao criar (`POST`).
- É o mesmo campo "Estimativa original (horas)" do Desenvolvimento e entra na
  soma de horas do Backlog.

### 5.3 Nota — `note`
Registra um texto no **Histórico** do ticket (visível à equipe), separado da
observação. Por padrão a nota ganha o prefixo "Direcionado automaticamente pela
IA de triagem:". Use para **o motivo de cada encaminhamento**. `"triage": false`
grava exatamente como enviada.

### 5.4 Tabela de decisão

| Resultado da análise | `ticket_column_id` | Outros campos |
|---|---|---|
| Informação faltante ou incompleta | "Revisão Humana" | `observation` com o que falta; `note` com o motivo |
| Melhoria, empresa **sem Nível** | "Classificado" (Mesa 7) | `observation`, `note` |
| Melhoria, Nível **1, 2 ou 3** | "Análise" da Mesa "5 - Banco de ideias" | `observation`, `note` |
| Melhoria, Nível **4 ou 5** | "Melhoria" da Mesa "4 - Especialista" | `observation`, `note` |
| Bug / erro | "GAP" da Mesa "4 - Especialista" | `observation`, `note` |

- **Revisão Humana:** uma pessoa decide o destino; não há automação de
  encaminhamento. A IA só move e deixa a `observation` pronta para quem revisa.
- **Classificado:** quando alguém preencher o Nível, o ticket **não volta sozinho**
  para a análise. A IA pode consultar periodicamente esse estágio
  (`GET /tickets?ticket_column_id=<Classificado>`) e rotear os que já tiverem
  `company_classification_level`.
- **Bug × melhoria:** a API não tem campo para isso; é decisão da IA, registrada
  na `observation` e na `note`.

### 5.5 Trocar de Mesa
- Categoria: pertence à Mesa. Se precisar de categoria na Mesa nova, envie
  `ticket_category_id` (de `GET /ticket_categories`) **na mesma chamada**.
- Se o ticket estiver num **sprint** da Mesa antiga, envie `sprint_id` (em branco
  = Backlog) junto; senão **422**.
- Classificação no Catálogo: `service_catalog_item_id` (de
  `GET /service_catalog_items`).

---

## 6. Como detectar tickets novos (polling)

Não há webhook de ticket: a IA consulta.

```
GET /tickets?ticket_column_id=<Pendente>&per_page=50
```
- Ordenado do mais recente para o mais antigo; `meta.count` traz o total.
- Mova o ticket para "Em análise" **logo ao pegá-lo**: assim ele sai de
  "Pendente" e não é analisado duas vezes (idempotência).
- Intervalo sugerido: 30 a 60 segundos (o limite é 120 chamadas/minuto por
  chave, somando todas as rotas).
- `?updated_after=<ISO 8601>` ajuda a buscar só o que mudou.

---

## 7. Erros que a IA deve tratar

| HTTP | Quando | O que fazer |
|---|---|---|
| 401 | chave ausente/inválida | verificar a chave |
| 404 | id inexistente ou de outra conta | não repetir; registrar |
| 422 | regra violada (`attributes` diz o campo): Estágio exige dado, Nível fora de 1–5, data/estimativa inválida, categoria de outra Mesa, ticket finalizado | corrigir e tentar de novo; se persistir, mover para "Revisão Humana" |
| 429 | limite de chamadas | aguardar `retry_after` segundos |

Em erro **nada é aplicado** (a chamada é atômica): o ticket continua onde estava.

---

## 8. Checklist antes de ligar

1. Deploy feito e migrations aplicadas (`observation`, Nível da empresa).
2. `GET /teams` mostra as Mesas **7, 5 e 4** e os estágios **Pendente, Em
   análise, Revisão Humana, Classificado** (Mesa 7), **Análise** (Mesa 5),
   **Melhoria** e **GAP** (Mesa 4) — guarde os ids.
3. Nenhum desses estágios tem `requires` verdadeiro (senão, mande os campos da
   seção 4; `appointment` não é possível pela API).
4. Os estágios de destino não têm mensagem automática ao cliente indesejada.
5. O ticket de teste passa pelo fluxo: Pendente → Em análise → destino, e a
   `observation` e a `note` aparecem no ticket.

## 9. Resumo das novidades usadas por este fluxo

| Novidade | Onde |
|---|---|
| `GET /companies`, `GET /companies/:id` (com o Nível) | seção 3 |
| `company_id` e `company_classification_level` na leitura e no `PATCH`/`POST` | seção 3 |
| `observation` no `GET`, `POST` e `PATCH` | 5.1 |
| `estimativa_original_horas` no `GET`, `POST` e `PATCH` | 5.2 |
| `requires` por Estágio em `GET /teams` | seção 2 |
| `assignee_id`, `due_date`, `scheduled_at` aplicados **antes** do movimento | seção 4 |
| Mover o estágio pela API **executa as automações** do estágio | seção 4 |
