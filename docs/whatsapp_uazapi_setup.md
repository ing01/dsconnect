# WhatsApp via UAZAPI

Como conectar um número de WhatsApp na DSConnect usando a **UAZAPI**
(uazapiGO, [docs.uazapi.com](https://docs.uazapi.com)).

## O que é isso, de verdade

A UAZAPI automatiza uma sessão comum de WhatsApp Web, pareada por QR code.
Ela **não é** a WhatsApp Business Platform oficial da Meta. Por isso:

- **Não existe** template aprovado nem janela de atendimento de 24h: toda
  mensagem é texto normal, a qualquer momento.
- **O número pode ser banido ou limitado** pelo WhatsApp se parecer robô
  (respostas instantâneas, volume alto, disparo frio). É a mesma categoria de
  risco do AstereZap e do ExpxWhats.

## Os dois tokens da UAZAPI

| Token | Para que serve | Vai na DSConnect? |
|---|---|---|
| **admintoken** | Administrar o servidor: criar, listar e apagar instâncias | **Não.** Guarde só com quem administra o servidor |
| **token da instância** | Enviar e receber mensagens de UM número | **Sim**, é o que a caixa de entrada usa |

Quem tiver o admintoken controla todos os números do servidor, por isso ele
nunca fica gravado na DSConnect.

## Passo 1: criar a instância e parear o número

Pelo painel da UAZAPI, crie uma instância e escaneie o QR code com o celular
(WhatsApp > Aparelhos conectados). Ou pela API, com o admintoken:

```bash
# 1. Criar a instância (a resposta traz o "token" da instância - anote)
curl -X POST "https://SEU-SERVIDOR.uazapi.com/instance/init" \
  -H "admintoken: SEU_ADMIN_TOKEN" -H "Content-Type: application/json" \
  -d '{"name": "atendimento"}'

# 2. Gerar o QR code para parear (use o token da instância)
curl -X POST "https://SEU-SERVIDOR.uazapi.com/instance/connect" \
  -H "token: TOKEN_DA_INSTANCIA" -H "Content-Type: application/json" -d '{}'

# 3. Conferir se conectou ("connected": true)
curl "https://SEU-SERVIDOR.uazapi.com/instance/status" -H "token: TOKEN_DA_INSTANCIA"
```

## Passo 2: criar a caixa de entrada na DSConnect

Em **Configurações > Caixas de entrada > Adicionar caixa de entrada >
WhatsApp**, escolha **UAZAPI** e preencha:

| Campo | De onde vem |
|---|---|
| Nome da Caixa de Entrada | Livre |
| Número de telefone | O número pareado, formato internacional (ex: `+5511999999999`) |
| Endereço do servidor | A URL do seu servidor UAZAPI, ex: `https://suaempresa.uazapi.com` |
| Token da instância | O token da instância do passo 1 |

Ao salvar, a DSConnect:

1. Confere endereço e token com `GET /instance/status`. Se der "Invalid
   Credentials", um dos dois está errado ou o servidor não está acessível a
   partir da DSConnect.
2. Configura sozinha o webhook da instância (`POST /webhook`) apontando para
   `https://<sua-dsconnect>/webhooks/whatsapp/<numero>`, com os eventos
   `messages`, `messages_update` e `connection`, e ignorando as mensagens que
   a própria DSConnect enviou (`wasSentByApi`).

A variável de ambiente `FRONTEND_URL` da DSConnect precisa estar com o
endereço público certo, porque é com ela que a URL do webhook é montada.

### Se o webhook não for configurado sozinho

Configure na mão (o `+` do número vira `%2B` na URL):

```bash
curl -X POST "https://SEU-SERVIDOR.uazapi.com/webhook" \
  -H "token: TOKEN_DA_INSTANCIA" -H "Content-Type: application/json" \
  -d '{"enabled": true,
       "url": "https://SUA-DSCONNECT/webhooks/whatsapp/%2B5511999999999",
       "events": ["messages", "messages_update", "connection"],
       "excludeMessages": ["wasSentByApi"]}'
```

## Segurança do webhook

Todo evento da UAZAPI traz o token da instância no corpo. A DSConnect só
aceita o evento se esse token bater com o da caixa, então quem descobrir a
URL do webhook não consegue injetar mensagens falsas.

## Reduzindo o risco de banimento

Igual aos outros provedores não oficiais: em **Configurações da caixa de
entrada > Configurações**, o "Atraso de digitação simulada" faz cada envio
mostrar "digitando..." por 1,5 a 12 segundos (proporcional ao texto) antes de
sair. **Não zere isso.** Aqueça números novos aos poucos, evite disparo frio e
mantenha o celular pareado online.

## Problemas comuns

- **Mensagens pararam de chegar depois de a DSConnect ficar fora do ar**: a
  UAZAPI desliga o webhook sozinha depois de 24h sem nenhuma entrega com
  sucesso. Rode de novo o `POST /webhook` acima com `"enabled": true`.
- **Status fica só em "enviado"**: confira se o evento `messages_update`
  está marcado no webhook.
- **Mensagem enviada não sai**: veja o erro na conversa (ícone de erro) ou o
  log do Sidekiq por `[UAZAPI]`. Erro `WHATSAPP_REACHOUT_TIMELOCK` é o próprio
  WhatsApp limitando o número.

## O que não é processado (por enquanto)

Grupos são ignorados. Localização, enquete, contato compartilhado e reação
viram um aviso de "mensagem não suportada" na conversa. Texto, imagem,
vídeo, áudio, nota de voz, documento e figurinha funcionam.

## Para quem for mexer no código

- Envio: [`whatsapp_uazapi_service.rb`](../app/services/whatsapp/providers/whatsapp_uazapi_service.rb)
- Recebimento: [`incoming_message_uazapi_service.rb`](../app/services/whatsapp/incoming_message_uazapi_service.rb)
- O `source_id` gravado é o `messageid` (id do WhatsApp), porque é ele que
  volta nos recibos (`MessageIDs` do `messages_update`).
- Mídia recebida: `POST /message/download` devolve um `fileURL` que vale 2
  dias; a DSConnect baixa na hora.
