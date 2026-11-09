# API de Integração de Tickets do DSConnect — ajustes de 09/11/2026

Para a IA/time de desenvolvimento que migra o fluxo de chamados do Jira para o
DSConnect. Descreve **o que mudou** em relação ao guia de 06/11/2026 e as regras
que valem agora. A referência completa de campos e respostas está no Swagger
(grupo **Ticket Routing API**).

> **Disponibilidade:** implementado e documentado; **ainda não publicado em
> produção**. Entra no próximo deploy — a Duesoft avisa quando estiver no ar. Até
> lá, produção segue com o comportamento do guia de 06/11.

- **Base:** `https://dsconnect.duesoft.com.br/api/v1/integrations`
- **Autenticação:** cabeçalho `X-Ticket-Api-Key: <chave>` (sem mudança).
- **Isolamento:** a conta vem da chave; nada de outra conta é lido ou alterado.
- **Compatibilidade:** nenhuma rota, campo ou valor do guia de 06/11 foi removido
  ou renomeado. As únicas mudanças de comportamento estão na seção 9.

---

## 1. Resumo

| # | Novidade |
|---|---|
| 1 | `GET /users` e `GET /users/:id` — usuários da conta (para descobrir o `assignee_id`) |
| 2 | `GET /sprints`; `sprint_id` na leitura, na criação e no `PATCH`; filtro `GET /tickets?sprint_id=` |
| 3 | `development_type` aceita `story` (História), além de `bug` e `task` |
| 4 | `ticket_column_id` **sem** `team_id` passa a deduzir a Mesa (`PATCH` e `/route`) |
| 5 | `note` sem o prefixo da triagem de IA (`"triage": false`) |
| 6 | Limite de chamadas documentado; o 429 agora responde JSON |
| 7 | Anexos: o link do arquivo agora exige autenticação |
| 8 | Esclarecimentos: encerramento, `assignee_id`, 40 MB |

Terminologia: o que o guia chamava de "campos do card do Jira" são os
**campos do desenvolvimento** (`observacoes_dev`, `observacoes_teste`,
`documentacao`, `instrucoes`, `analise`). **A API não tem campo de chave do
Jira**: identifique os tickets pelos ids do DSConnect — `id` (nas rotas) e
`display_id` (o número exibido no painel).

---

## 2. Erros

| HTTP | Quando | Corpo |
|---|---|---|
| 401 | chave ausente/inválida | `{"error":"unauthorized"}` |
| 403 | API desligada na conta | `{"error":"api disabled for this account"}` |
| 404 | id **inexistente ou de outra conta** | `{"error":"Resource could not be found"}` |
| 422 | regra violada | `{"error":"…","message":"…","attributes":["campo"]}` (algumas validações trazem só `message`/`attributes`, ou só `error`) |
| 429 | limite de chamadas | seção 6 |

Regra geral: id de outra conta é **404**, nunca é aceito; id da conta que não
serve naquele contexto é **422**.

---

## 3. Usuários e sprints

### `GET /users`
```json
[{ "id": 31, "name": "Ana Souza", "email": "ana@empresa.com.br", "role": "agent" }]
```
`?team_id=<id>` lista só os **membros da Mesa** (quem pode ser responsável na
criação — seção 8). Mesa de outra conta/inexistente → 404. `role`: `agent` ou
`administrator`.

### `GET /users/:id`
Um usuário da conta. De outra conta, inexistente ou id inválido → 404.

### `GET /sprints`
```json
[{ "id": 4, "name": "OUT26 S4", "team_id": 9, "team_name": "Desenvolvimento",
   "starts_on": "2026-10-26", "ends_on": "2026-11-01", "status": "active", "active": true }]
```
Ordenado por `starts_on`. `status`: `upcoming`, `active`, `completed`. `active:
true` marca o sprint **em andamento** da Mesa. Filtros: `?team_id=` (de outra
conta → 404) e `?status=` (valor fora da lista → 422, não lista vazia).

---

## 4. Campos novos nos tickets

Na leitura (detalhe e respostas de escrita): `development_type` e `sprint_id`
(`null` = Backlog). Na lista: os mesmos dois.

**`development_type`** — `bug` (Bug), `task` (Tarefa), **`story` (História)**.
Em branco limpa; outro valor → 422 (a mensagem lista os válidos). `bug` e `task`
são os mesmos de antes.

**`sprint_id`** — sprint da **mesma Mesa** do ticket → senão 422. De outra conta
ou inexistente → 404. Em branco devolve o ticket ao Backlog.

Filtros na lista: `?sprint_id=` e `?development_type=`.

Onde enviar:
- **Criação:** `POST /tickets`, dentro de `ticket` (ao lado de `title` etc.).
- **Alteração:** `PATCH /tickets/:id` (ou `/route`), no nível raiz do corpo.

---

## 5. `POST` e `PATCH` — como funcionam

- **`POST /tickets`** — corpo `{ "ticket": { … } }`. Obrigatórios: `title`,
  `description`, `priority`, `ticket_category_id` e `ticket_column_id`. Aceita
  também `team_id`, `company_id`, `contact_id`, `ticket_complexity_id`,
  `assignee_id`, `due_date`, `development_type`, `sprint_id`, os campos do
  desenvolvimento e `custom_attributes`. Responde **201** com o ticket.
- **`PATCH /tickets/:id`** é o mesmo que **`PATCH /tickets/:id/route`**: corpo
  no nível raiz, **todos os campos opcionais**, cada um aplicado só se enviado:
  `team_id`, `ticket_column_id`, `service_catalog_item_id`, `ticket_category_id`,
  `ticket_complexity_id`, `assignee_id`, `priority`, `development_type`,
  `sprint_id`, os campos do desenvolvimento, `custom_attributes` (**mescla**, não
  substitui), `note` e `triage`. Responde **200** com o ticket.
- **Limite:** `title` e `description` **não** são editáveis por `PATCH`/`route`
  (só na criação).
- Trocar de Mesa com o ticket **dentro de um sprint** exige `sprint_id` na mesma
  requisição (em branco = Backlog) → senão 422.
- Trocar de Mesa remove a categoria atual (ela pertence à Mesa antiga): envie
  `ticket_category_id` da nova Mesa.

```bash
curl -X POST "$BASE/tickets" -H "X-Ticket-Api-Key: $KEY" -H "Content-Type: application/json" -d '{
  "ticket": {
    "title": "Erro ao emitir nota fiscal",
    "description": "A emissão retorna rejeição 539.",
    "priority": "high",
    "ticket_column_id": 12,
    "ticket_category_id": 7,
    "development_type": "bug",
    "sprint_id": 4,
    "assignee_id": 31
  }
}'

curl -X PATCH "$BASE/tickets/123" -H "X-Ticket-Api-Key: $KEY" -H "Content-Type: application/json" \
  -d '{ "ticket_column_id": 14, "sprint_id": null, "development_type": "story" }'
```

### Mesa e Estágio (`PATCH`, `/route`; o `POST` já deduzia a Mesa)

| Enviado | Resultado |
|---|---|
| só `ticket_column_id` | a Mesa é a do Estágio *(antes era ignorado em silêncio)* |
| só `team_id` | vai para o **primeiro Estágio** da Mesa (sem mudança se já está nela) |
| os dois | o Estágio tem de ser da Mesa → senão **422** |
| nenhum, ou em branco | não move |

Mesa ou Estágio de outra conta → 404.

---

## 6. Limite de chamadas — HTTP 429

**120 requisições por minuto, por chave** (contagem separada para cada chave).
Excedido:

```
HTTP/1.1 429 Too Many Requests
Retry-After: 23
Content-Type: application/json
```
```json
{ "error": "rate_limit_exceeded",
  "message": "Too many requests: the limit is 120 per 60 seconds for each API key. Retry in 23 seconds.",
  "limit": 120, "period_seconds": 60, "retry_after": 23 }
```
Aguarde `retry_after` segundos (mesmo valor do cabeçalho). O 429 era texto puro
("Retry later"); agora é JSON.

---

## 7. Anexos

- `attachments[].url` é um link **permanente** que redireciona (**302**) para um
  link assinado **válido por 5 minutos**.
- **Mudança de segurança (no mesmo deploy):** o link passa a **exigir
  autenticação**. Ao baixar, envie o mesmo `X-Ticket-Api-Key`; sem credencial,
  **401**. Antes, qualquer pessoa com o endereço baixava o arquivo, sem login, e
  links antigos continuavam valendo — isso acabou.
- **Upload:** `POST /tickets/:ticket_id/attachments` (multipart, campo `file`).
  Limite de **40 MB por arquivo**: acima disso → **422** e nada é anexado.
  Ticket já fechado/cancelado também recusa (422).

```bash
curl -L "$ATTACHMENT_URL" -H "X-Ticket-Api-Key: $KEY" -o arquivo
```

---

## 8. Regras esclarecidas

### Encerramento
- **Não existe operação de fechar/resolver** nesta API, e `status` **não é
  aceito**: se enviado, é ignorado (sem erro).
- **Mover para o Estágio "Finalizado" só muda `ticket_column_id`; o `status` não
  muda** (continua `open`), a menos que o Estágio tenha automação configurada.
  Hoje os Estágios "Finalizado" **não têm automação**: mover para lá **não**
  encerra o ticket. Considere na migração: ticket "Done" no Jira fica na coluna
  Finalizado, mas com `status: "open"`.
- Pelo painel, fechar exige classificação no Catálogo, a **Resolução** e a
  comunicação ao cliente. Se a migração precisar de tickets já encerrados, é
  preciso combinar uma operação de fechamento com a Duesoft — hoje ela não existe.

### `assignee_id` — criação × atualização
A diferença é **intencional** (regra do produto):

| Operação | Regra |
|---|---|
| sempre | o usuário é **da conta da chave** (outra conta → 404) |
| `POST` | tem de ser **membro da Mesa** do ticket → senão 422 |
| `PATCH` / `/route` | basta ser da conta (um administrador pode assumir ticket de Mesa em que não é membro) |

### `note`
- No `/route`/`PATCH` a nota ganha o prefixo `Direcionado automaticamente pela IA
  de triagem:` (é o fluxo da triagem). Envie **`"triage": false`** para gravar
  **exatamente como enviada**.

---

## 9. Mudanças de comportamento (únicas)

1. `PATCH`/`/route` com `ticket_column_id` **sem** `team_id`: antes ignorado;
   agora move o ticket (deduz a Mesa).
2. `PATCH`/`/route` com só `team_id` de **outra** Mesa: antes não fazia nada;
   agora leva ao primeiro Estágio dela.
3. `team_id` e `ticket_column_id` que **não batem**: agora **422** (antes o
   Estágio prevalecia, sem aviso). `team_id` de outra conta: **404**.
4. O 429 passou de texto para JSON.

---

## 10. Como validar depois do deploy

1. `GET /users` e `GET /sprints` → 200, só com dados da sua conta.
2. `GET /tickets?sprint_id=<id>` → só os tickets do sprint.
3. `PATCH /tickets/:id` com só `ticket_column_id` de outra Mesa → move e troca a Mesa.
4. `PATCH` com `development_type: "story"` → 200; com `"epic"` → 422.
5. `PATCH` com `sprint_id` de sprint de outra Mesa → 422; de outra conta → 404.
6. `PATCH` com `assignee_id` de usuário de outra conta → 404.
7. `POST` com `assignee_id` de usuário que não é da Mesa → 422.
8. Baixar `attachments[].url` sem a chave → 401; com a chave → o arquivo.
9. 121 chamadas em 1 minuto → a 121ª responde 429 em JSON.
