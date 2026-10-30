# O Inbox unico do chat do Portal do Cliente, por conta.
#
# E um `Channel::Api` comum - o mesmo "canal generico" que o Chatwoot ja tem
# pronto, sem tabela nova. A marca que o identifica vive em
# `additional_attributes`, e nao no nome: o nome e o que a equipe ve e pode
# editar (Configuracoes > Caixas de Entrada), e um texto editavel nunca pode
# ser a fronteira que decide "esta e a caixa do Portal".
#
# `account.with_lock` around the find-or-create: duas abas do Portal abrindo a
# MESMA conta ao mesmo tempo, na primeira vez (antes do Inbox existir), nao
# podem criar duas caixas "Portal do Cliente" - so a primeira chamada grava, a
# segunda encontra o que a primeira ja fez.
module Inboxes
  class EnsureClientPortalInboxService
    MARKER_KEY = 'client_portal'

    pattr_initialize [:account!]

    # So para leitura: nao cria nada. Uma tela que so LISTA novidades (as
    # Notificacoes do Portal) nao pode ter o efeito colateral de criar a caixa
    # "Portal do Cliente" so por ter sido aberta - sem ninguem nunca ter usado
    # o chat, nao ha conversa nenhuma para achar de qualquer jeito.
    def self.find_existing(account)
      account.api_channels.to_a.find { |channel| channel.additional_attributes[MARKER_KEY] == true }&.inbox
    end

    def perform
      existing = find_channel&.inbox
      return ensure_settings!(existing) if existing

      account.with_lock do
        channel = find_channel
        inbox = channel ? channel.inbox || create_inbox!(channel) : create_inbox_with_channel!
        ensure_settings!(inbox)
      end
    end

    private

    # Reforca as duas configuracoes em toda chamada, nao so na criacao - uma
    # caixa criada por uma versao anterior deste servico (antes de existir
    # historico de conversas/CSAT) precisa alcancar o mesmo estado sem
    # depender de ninguem editar isso manualmente em Configuracoes.
    def ensure_settings!(inbox)
      return inbox if settings_in_place?(inbox)

      inbox.update!(lock_to_single_conversation: false, csat_survey_enabled: true, enable_auto_assignment: false)
      inbox
    end

    def settings_in_place?(inbox)
      inbox.lock_to_single_conversation == false && inbox.csat_survey_enabled == true && inbox.enable_auto_assignment == false
    end

    def find_channel
      account.api_channels.to_a.find { |channel| channel.additional_attributes[MARKER_KEY] == true }
    end

    def create_inbox_with_channel!
      channel = account.api_channels.create!(additional_attributes: { MARKER_KEY => true })
      create_inbox!(channel)
    end

    def create_inbox!(channel)
      account.inboxes.create!(
        channel: channel,
        name: 'Portal do Cliente',
        # Uma conversa RESOLVIDA nao deve continuar recebendo mensagem por
        # cima - e' o gatilho que separa uma sessao de chat da proxima
        # (historico de conversas) e o mesmo gatilho que dispara a pesquisa
        # de satisfacao ao resolver.
        lock_to_single_conversation: false,
        csat_survey_enabled: true,
        # Quem recebe a conversa do Portal e' decidido pela triagem do bot
        # (Mesa/Fila), nunca pela distribuicao automatica da caixa - que
        # entregava ao primeiro agente online antes da triagem rodar.
        enable_auto_assignment: false
      )
    end
  end
end
