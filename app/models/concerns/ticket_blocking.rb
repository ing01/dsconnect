# Impedimento: o ticket esta travado por algo fora do alcance de quem atende -
# resposta do cliente, fornecedor, dependencia de outro time.
#
# NAO e um status. Ficar impedido nao encerra, nao resolve e nao cancela: o
# ticket segue aberto, na sua Mesa, no seu estagio, com seus responsaveis. Por
# isso `blocked_at` vive ao lado de `status`, e nao dentro dele - um ticket
# impedido continua sendo um ticket aberto para todo o resto do sistema.
#
# Impedimento de ticket FILHO sobe para o PAI: o analista que cuida do pai precisa saber
# que o desenvolvimento parou. O pai guarda de qual filho veio (`blocked_by_child_id`);
# retirar o impedimento do filho retira o do pai, e a resolucao fica registrada nos dois.
#
# Cada movimento deixa dois registros, de proposito: uma TicketActivity, que e a
# trilha de auditoria estruturada, e um comentario interno, que e onde a equipe
# efetivamente le o porque. O comentario usa o TicketComment de sempre - nao ha
# canal de comentario proprio para impedimento.
module TicketBlocking
  extend ActiveSupport::Concern

  included do
    belongs_to :blocked_by, class_name: 'User', optional: true
    # O filho de quem veio o impedimento deste ticket (quando ele e' o PAI).
    belongs_to :blocked_by_child, class_name: 'Ticket', optional: true

    scope :blocked, -> { where.not(blocked_at: nil) }
    scope :not_blocked, -> { where(blocked_at: nil) }
  end

  def blocked?
    blocked_at.present?
  end

  # Colocar impedimento. O motivo e obrigatorio: e ele que vira o comentario
  # interno, e um impedimento sem explicacao nao ajuda ninguem a destrava-lo.
  def block!(user, reason:, source_child: nil)
    motivo = reason.to_s.strip
    raise ArgumentError, I18n.t('tickets.impediment.reason_required') if motivo.blank?

    transaction do
      registrado = source_child ? I18n.t('tickets.impediment.from_child_reason', display_id: source_child.display_id, reason: motivo) : motivo
      update!(blocked_at: Time.current, blocked_by: user, blocked_reason: registrado, blocked_by_child_id: source_child&.id)
      register_impediment_comment(user, registrado)
      ticket_activities.create!(account_id: account_id, user: user, activity_type: :blocked, new_value: registrado)
      propagate_block_to_parent(user, motivo)
    end

    self
  end

  # Retirar o impedimento. O motivo que estava registrado sai junto: o campo
  # descreve o impedimento ATUAL, e manter o texto de um impedimento encerrado
  # faria a tela mostrar uma razao para um ticket que ja voltou ao normal. O
  # texto nao se perde - ele continua no comentario e na atividade.
  #
  # `resolution` (opcional) e' COMO o impedimento foi resolvido: vai no comentario e
  # na atividade, ao lado do motivo, no ticket e no pai que foi liberado com ele.
  def unblock!(user, resolution: nil, source_child: nil)
    return self unless blocked?

    motivo_anterior = blocked_reason
    resolucao = resolution.to_s.strip.presence

    transaction do
      update!(blocked_at: nil, blocked_by: nil, blocked_reason: nil, blocked_by_child_id: nil)
      register_release_comment(user, resolucao, source_child)
      ticket_activities.create!(
        account_id: account_id, user: user, activity_type: :unblocked,
        previous_value: motivo_anterior, new_value: resolucao
      )
      release_parent(user, resolucao)
    end

    self
  end

  private

  # O pai so' recebe o impedimento se puder: um pai ja impedido por outra coisa fica como
  # esta (so' ganha um comentario avisando), e um pai finalizado nao aceita mais alteracao.
  def propagate_block_to_parent(user, motivo)
    pai = parent
    return if pai.blank? || pai.finalized?

    if pai.blocked?
      pai.ticket_comments.create!(
        account_id: pai.account_id, user: user,
        content: I18n.t('tickets.impediment.child_also_blocked', display_id: display_id, reason: motivo)
      )
    else
      pai.block!(user, reason: motivo, source_child: self)
    end
  end

  # Libera o pai SO' se o impedimento dele veio deste filho. Se outro filho tambem esta
  # impedido, o pai continua impedido, agora por esse outro.
  def release_parent(user, resolucao)
    pai = parent
    return if pai.blank? || pai.finalized? || !pai.blocked? || pai.blocked_by_child_id != id

    outro = pai.children.blocked.where.not(id: id).order(:blocked_at).first
    if outro
      keep_parent_blocked_by(pai, outro, user)
    else
      pai.unblock!(user, resolution: resolucao, source_child: self)
    end
  end

  def keep_parent_blocked_by(pai, outro, user)
    pai.update!(blocked_by_child_id: outro.id,
                blocked_reason: I18n.t('tickets.impediment.from_child_reason', display_id: outro.display_id, reason: outro.blocked_reason))
    pai.ticket_comments.create!(
      account_id: pai.account_id, user: user,
      content: I18n.t('tickets.impediment.child_released_still_blocked', display_id: display_id, other_id: outro.display_id)
    )
  end

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

  def register_release_comment(user, resolucao, source_child)
    chave = source_child ? 'tickets.impediment.released_from_child_comment' : 'tickets.impediment.released_comment'
    texto = I18n.t(chave, user_name: user.name, display_id: source_child&.display_id)
    texto += " #{I18n.t('tickets.impediment.resolution_label', resolution: resolucao)}" if resolucao

    ticket_comments.create!(account_id: account_id, user: user, content: texto)
  end
end
