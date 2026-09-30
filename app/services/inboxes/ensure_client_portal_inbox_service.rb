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

    def perform
      existing = find_channel&.inbox
      return existing if existing

      account.with_lock do
        channel = find_channel
        channel ? channel.inbox || create_inbox!(channel) : create_inbox_with_channel!
      end
    end

    private

    def find_channel
      account.api_channels.to_a.find { |channel| channel.additional_attributes[MARKER_KEY] == true }
    end

    def create_inbox_with_channel!
      channel = account.api_channels.create!(additional_attributes: { MARKER_KEY => true })
      create_inbox!(channel)
    end

    def create_inbox!(channel)
      account.inboxes.create!(channel: channel, name: 'Portal do Cliente')
    end
  end
end
