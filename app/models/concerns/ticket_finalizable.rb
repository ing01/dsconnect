# Um ticket finalizado nao muda mais.
#
# Fechado e cancelado sao registro historico: o atendimento acabou, e o que
# ficou gravado e o que aconteceu. A unica saida e reabrir - sem isso o ticket
# viraria um beco sem saida, porque reabrir tambem e uma alteracao.
#
# Resolvido NAO conta como finalizado, e continua editavel: e o estado
# intermediario que ainda espera a classificacao e a comunicacao de fechamento.
# E a mesma leitura que o menu de acoes ja faz (`isTerminal`).
#
# A regra vive no model, e nao no controller, para valer em todo caminho que
# altera um ticket - a tela de detalhe, o card do Kanban, uma automacao ou um
# console. A policy repete a regra para a API responder 403 e a tela desabilitar
# os controles, mas quem de fato impede e isto aqui.
module TicketFinalizable
  extend ActiveSupport::Concern

  FINALIZED_STATUSES = %w[closed cancelled].freeze

  # O que reabrir tem direito de mexer: o status e as marcas que ele apaga. Vem
  # de `reopen!`, e a lista existe para que reabrir nao vire brecha para alterar
  # o resto do ticket na mesma gravacao.
  REOPEN_ATTRIBUTES = %w[status resolved_at closed_at cancelled_at close_reason updated_at].freeze

  included do
    validate :unchanged_once_finalized, on: :update
  end

  # Como o ticket esta gravado hoje, e nao como esta sendo alterado agora: e o
  # estado anterior que decide se a alteracao pode acontecer.
  def finalized?
    FINALIZED_STATUSES.include?(status)
  end

  # Uma alteracao administrativa sobre um ticket ja finalizado.
  #
  # Hoje so o agrupamento precisa disto: ele fecha o ticket e depois marca nele
  # POR QUE foi fechado, o que e uma gravacao sobre um ticket ja fechado. E a
  # mesma excecao que o `skip_requirements` do `close!` representa, na linha
  # vizinha do MergeService.
  #
  # Delimitado a um bloco de proposito: nao ha como deixar a excecao ligada por
  # engano, e o `ensure` a desarma mesmo se o bloco levantar erro.
  def as_administrative_change
    @administrative_change = true
    yield
  ensure
    @administrative_change = false
  end

  private

  def unchanged_once_finalized
    return if @administrative_change
    return unless FINALIZED_STATUSES.include?(status_in_database)
    return if reopening?

    errors.add(:base, I18n.t('tickets.finalized.immutable'))
  end

  # Reabrir e a excecao, e a unica. Um ticket finalizado pode voltar a `open`, e
  # nada mais pode mudar junto: quem reabre e depois edita faz duas acoes, o que
  # deixa as duas no historico.
  def reopening?
    status == 'open' && (changed_attributes.keys - REOPEN_ATTRIBUTES).empty?
  end
end
