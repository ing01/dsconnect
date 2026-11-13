# WhatsApp via ExpxWhats (self-hosted)

Como conectar um número de WhatsApp na DSConnect usando o **ExpxWhats**
([github.com/.../ExpxWhats](https://github.com/)) em vez da WhatsApp Business
Platform oficial da Meta.

## O que é isso, de verdade

O ExpxWhats é um servidor Go que expõe uma API HTTP sobre a biblioteca
[`whatsmeow`](https://github.com/tulir/whatsmeow). Ele **não fala com a API
oficial da Meta** — ele automatiza uma sessão comum de WhatsApp Web, pareada
por QR code, exatamente como você faria abrindo `web.whatsapp.com` no
celular. Por isso:

- **Não existe** "template aprovado" nem janela de atendimento de 24h — toda
  mensagem é tratada como texto normal, a qualquer momento.
- **Não é afiliado à Meta**: é uma biblioteca de engenharia reversa do
  protocolo do WhatsApp (licença MPL-2.0), mantida pela comunidade.
- **O número pode ser banido ou limitado** pelo WhatsApp se detectar
  comportamento de robô (respostas instantâneas, volume alto, etc). Isso é
  um risco real e conhecido desse tipo de integração — não existe garantia
  de que não vai acontecer, só formas de reduzir a chance (ver seção
  "Reduzindo o risco de banimento" abaixo).
- É **auto-hospedado**: ao contrário do AstereZap (que é um serviço de
  terceiros já integrado na DSConnect), aqui é a própria empresa que roda o
  servidor, guarda os arquivos de sessão e é responsável pelo uptime.

Essa é a mesma categoria de risco e funcionamento do provider **AstereZap**
já existente na DSConnect (`Configurações > Caixa de entrada > Adicionar
caixa > WhatsApp > AstereZap`) — se você já usa ou usou o AstereZap, a
lógica de uso no dia a dia (envio, resposta do cliente, limites) é a mesma.
A diferença é só *onde* o servidor roda e *quem* é dono dele.

## Passo 1 — Rodar o servidor ExpxWhats

Em um servidor próprio (VM, container, etc), com Go 1.26+ instalado:

```bash
cd api
go build -o wapi .
./wapi          # sobe em http://127.0.0.1:8080 (ADDR=host:porta pra mudar)
```

Na primeira execução é gerado um `api.key` (chave global de administração).
**Guarde esse arquivo com cuidado** — ele controla todos os números
conectados nesse servidor. Os arquivos `api.key`, `wa.db` (sessões do
WhatsApp) e `api.db` (histórico) ficam na pasta de execução e não são
versionados: faça backup regular deles, porque quem tiver esses arquivos
controla a sessão do número (se perdê-los, precisa escanear o QR de novo).

Por padrão o servidor só escuta em `127.0.0.1`. Para a DSConnect conseguir
entregar/receber webhooks, ele precisa estar acessível por **HTTPS**, atrás
de um proxy reverso (nginx/Caddy) com certificado válido — nunca exponha a
porta 8080 direto na internet.

## Passo 2 — Criar e parear o número

1. Acesse `https://seu-servidor/admin` e entre com o `api.key` (ou a chave
   definida em `API_KEY`).
2. Crie uma instância (um número). Isso já gera um **token** (X-Instance-Token)
   específico daquele número — anote-o.
3. Em **WhatsApp > Aparelhos conectados** no celular que vai ser conectado,
   escaneie o QR exibido no painel.
4. Ainda no painel, configure o **webhook** da instância apontando para a
   DSConnect:

   ```
   https://sua-dsconnect.com.br/webhooks/whatsapp/<numero_com_codigo_do_pais>
   ```

   Use o mesmo `<numero_com_codigo_do_pais>` que você vai cadastrar como
   "Número de telefone" no passo 3 (só dígitos, com código do país — ex:
   `5511999999999`). Em **Eventos**, marque pelo menos `message` e
   `receipt`. Um **Secret** (segredo de assinatura) é opcional nesta
   versão — a DSConnect ainda não verifica a assinatura `X-Signature`, mas
   recomendamos preenchê-lo mesmo assim e tratar a URL do webhook como
   informação sensível (não divulgar/logar em lugar público).

## Passo 3 — Criar a caixa de entrada na DSConnect

Em **Configurações > Caixas de entrada > Adicionar caixa de entrada >
WhatsApp**, escolha o provedor **ExpxWhats** e preencha:

| Campo | De onde vem |
|---|---|
| Nome da Caixa de Entrada | Livre, só pra identificar na DSConnect |
| Número de telefone | O mesmo número usado na URL do webhook (passo 2), no formato internacional |
| Endereço do servidor | A URL base do seu ExpxWhats, ex: `https://whatsapp.suaempresa.com.br` |
| Nome da instância | O `name` que você deu à instância no painel do ExpxWhats |
| Token da instância | O `X-Instance-Token` gerado no passo 2 |

Ao salvar, a DSConnect faz uma checagem (`GET /instances/{nome}/config`) pra
confirmar que endereço, instância e token estão certos antes de criar o
canal — se der erro de credenciais inválidas, revise os três campos.

## Reduzindo o risco de banimento

Isso **não elimina** o risco, só reduz:

- **Atraso de digitação simulada**: em
  `Configurações da caixa de entrada > Configurações`, ajuste "Atraso de
  digitação simulada" (mínimo/máximo em segundos). Por padrão, toda
  mensagem enviada pela DSConnect espera entre 1,5s e 12s (proporcional ao
  tamanho do texto) antes de "aparecer digitando" e enviar — isso imita um
  humano respondendo, em vez de um robô instantâneo. **Não zere isso.**
- **Aqueça o número aos poucos**: se for um número novo, comece com poucas
  conversas por dia antes de usá-lo em volume alto.
- **Evite disparo em massa/frio**: isso é o principal gatilho de bloqueio.
  Use só para atendimento (conversas iniciadas pelo cliente) ou campanhas
  para contatos que já têm relacionamento, nunca listas frias compradas.
- **Um número = uma sessão por vez**: não escaneie o mesmo QR em dois
  lugares, não tente rodar duas instâncias para o mesmo número.
- **Mantenha o celular pareado online** (o WhatsApp Web precisa do celular
  conectado à internet periodicamente; ficar muito tempo offline pode
  derrubar a sessão).
- **Faça backup de `wa.db`**: se o servidor cair e perder esse arquivo, a
  sessão se perde e é preciso reparear via QR — o que por si só não bane o
  número, mas é um transtorno evitável com backup.

## Diferenças técnicas em relação ao AstereZap (para quem for mexer no código)

- Envio: **um único** endpoint `POST /instances/{nome}/messages` (campo
  `type` decide o formato), em vez de um endpoint por tipo.
- Mídia recebida: `GET /instances/{nome}/messages/{id}/media` devolve o
  arquivo binário direto (com `Content-Type` certo) — não precisa de
  decodificação base64 como no AstereZap.
- Webhook: payload sempre embrulhado em
  `{"instance":..., "event":..., "data":..., "time":...}`, com dois eventos
  relevantes: `message` (mensagem recebida ou enviada — `data.from_me`
  diferencia) e `receipt` (confirmação de entrega/leitura).
- Implementação na DSConnect:
  [`app/services/whatsapp/providers/whatsapp_expxwhats_service.rb`](../app/services/whatsapp/providers/whatsapp_expxwhats_service.rb)
  (envio) e
  [`app/services/whatsapp/incoming_message_expxwhats_service.rb`](../app/services/whatsapp/incoming_message_expxwhats_service.rb)
  (webhook recebido), seguindo o mesmo molde do
  `Whatsapp::Providers::WhatsappAsterezapService` /
  `Whatsapp::IncomingMessageAsterezapService` já existentes.
- **Limitação atual**: mensagens de grupo, localização, enquete, contato
  compartilhado e chamadas não são processadas (o grupo é ignorado; os
  demais tipos viram uma mensagem "não suportada" na conversa, sem travar o
  processamento). Só conversas individuais (1:1) com texto, imagem, vídeo,
  áudio, nota de voz, documento e figurinha são suportadas por enquanto.

## Problemas comuns

- **"Invalid Credentials" ao salvar a caixa**: confira se `base_url` não
  tem barra sobrando no final, se o nome da instância bate exatamente com o
  criado no painel, e se o servidor ExpxWhats está acessível a partir de
  onde a DSConnect roda (não só do seu computador).
- **Mensagens não chegam na DSConnect**: confira se o webhook está
  configurado na instância certa (painel `/admin` do ExpxWhats), se a URL
  bate com o número cadastrado, e se os eventos `message`/`receipt` estão
  marcados. O botão "Disparar evento de teste" no painel do ExpxWhats
  (`POST /instances/{nome}/webhook/test`) ajuda a confirmar se a DSConnect
  está recebendo.
- **Mensagens enviadas pela DSConnect não saem**: veja o log do Sidekiq/
  Rails por `[ExpxWhats]` ou o erro salvo na mensagem (ícone de erro na
  conversa) — o corpo de erro do ExpxWhats vem como `{"error": "..."}`.
