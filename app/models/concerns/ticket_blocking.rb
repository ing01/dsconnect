# Impedimento: o ticket esta travado por algo fora do alcance de quem atende -
# resposta do cliente, fornecedor, dependencia de outro time.
#
# NAO e um status. Ficar impedido nao encerra, nao resolve e nao cancela: o
# ticket segue aberto, na sua Mesa, no seu estagio, com seus responsaveis. Por
# isso `blocked_at` vive ao lado de `status`, e nao dentro dele - um ticket
# impedido continua sendo um ticket aberto para todo o resto do sistema.
#
# Cada movimento deixa dois registros, de proposito: uma TicketActivity, que e a
# trilha de auditoria estruturada, e um comentario interno, que e onde a equipe
# efetivamente le o porque. O comentario usa o TicketComment de sempre - nao ha
# canal de comentario proprio para impedimento.
module TicketBlocking
  extend ActiveSupport::Concern

  included do
    belongs_to :blocked_by, class_name: 'User', optional: true

    scope :blocked, -> { where.not(blocked_at: nil) }
    scope :not_blocked, -> { where(blocked_at: nil) }
  end

  def blocked?
    blocked_at.present?
  end

  # Colocar impedimento. O motivo e obrigatorio: e ele que vira o comentario
  # interno, e um impedimento sem explicacao nao ajuda ninguem a destrava-lo.
  def block!(user, reason:)
    motivo = reason.to_s.strip
    raise ArgumentError, I18n.t('tickets.impediment.reason_required') if motivo.blank?

    transaction do
      update!(blocked_at: Time.current, blocked_by: user, blocked_reason: motivo)
      register_impediment_comment(user, motivo)
      ticket_activities.create!(
        account_id: account_id, user: user,
        activity_type: :blocked,
        new_value: motivo
      )
    end

    self
  end

  # Retirar o impedimento. O motivo que estava registrado sai junto: o campo
  # descreve o impedimento ATUAL, e manter o texto de um impedimento encerrado
  # faria a tela mostrar uma razao para um ticket que ja voltou ao normal. O
  # texto nao se perde - ele continua no comentario e na atividade.
  def unblock!(user)
    return self unless blocked?

    motivo_anterior = blocked_reason

    transaction do
      update!(blocked_at: nil, blocked_by: nil, blocked_reason: nil)
      register_release_comment(user)
      ticket_activities.create!(
        account_id: account_id, user: user,
        activity_type: :unblocked,
        previous_value: motivo_anterior
      )
    end

    self
  end

  private

  # O comentario anuncia o que aconteceu antes de dar o motivo: lido no meio do
  # historico, "Aguardando o fornecedor" sozinho nao diz se e um impedimento, uma
  # observacao ou uma resposta. O texto da pessoa vai integro depois do rotulo.
  #
  # O motivo cru continua guardado em `blocked_reason`, entao a tela mostra o
  # texto limpo e o historico mostra o texto rotulado.
  def register_impediment_comment(user, motivo)
    ticket_comments.create!(
      account_id: account_id,
      user: user,
      content: I18n.t('tickets.impediment.recorded_comment', reason: motivo)
    )
  end

  def register_release_comment(user)
    ticket_comments.create!(
      account_id: account_id,
      user: user,
      content: I18n.t('tickets.impediment.released_comment', user_name: user.name)
    )
  end
end
