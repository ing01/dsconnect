# Avisa o ticket PAI quando um ticket FILHO de uma Mesa de desenvolvimento e
# concluido - o analista que cuida do pai precisa saber que o desenvolvimento
# terminou sem ficar abrindo o filho para conferir.
#
# "Concluido" e o status `closed`: o Estagio Finalizado e a automacao dele
# (Tickets::ColumnAutomationService) levam o ticket para la, e e o fechamento que
# marca o fim.
#
# Como em TicketBroadcastable, a marca e anotada no `after_update` (dentro da
# transacao) e lida depois do commit: o `saved_change_to_status?` nao sobrevive a
# um `reload` ou a outro salvamento na mesma transacao.
module TicketParentNotifiable
  extend ActiveSupport::Concern

  included do
    after_update :remember_completion
    after_rollback { @completed_now = nil }
    after_update_commit :enqueue_parent_notice
  end

  private

  def remember_completion
    @completed_now = true if saved_change_to_attribute?('status') && closed? && parent_id.present?
  end

  def enqueue_parent_notice
    return unless @completed_now

    @completed_now = nil
    return unless team&.development_module_enabled?

    Tickets::ChildCompletedJob.perform_later(id)
  end
end
