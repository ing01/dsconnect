# Envia a proposta por e-mail ao solicitante do ticket (com o PDF) e registra quando e para onde.
# Nunca levanta: a proposta ja esta salva, e o e-mail que nao saiu vira um aviso para quem a criou
# (`reason`), nao um erro que desfaz o trabalho.
#   - `no_email`: o solicitante nao tem e-mail cadastrado;
#   - `not_delivered`: o servidor de e-mail nao aceitou/nao esta configurado;
#   - `failed`: erro inesperado no envio.
class Tickets::Proposals::EmailService
  Result = Struct.new(:sent, :reason, :to, keyword_init: true)

  pattr_initialize [:proposal!]

  def perform
    to = recipient
    return Result.new(sent: false, reason: 'no_email') if to.blank?

    mail = TicketProposalMailer.with(account: proposal.account).proposal_sent(proposal, to).deliver_now
    return Result.new(sent: false, reason: 'not_delivered') unless delivered?(mail)

    # rubocop:disable Rails/SkipsModelValidations
    proposal.update_columns(emailed_at: Time.current, emailed_to: to)
    # rubocop:enable Rails/SkipsModelValidations
    Result.new(sent: true, to: to)
  rescue StandardError => e
    Rails.logger.error "Falha ao enviar a proposta #{proposal.id} por e-mail: #{e.message}"
    Result.new(sent: false, reason: 'failed')
  end

  # Quem recebe: o e-mail do solicitante do ticket de origem.
  def recipient
    proposal.ticket.requester_contact&.email.presence
  end

  private

  # Uma entrega de verdade tem destinatario; o NullMail (SMTP nao configurado) nao tem.
  def delivered?(mail)
    mail.present? && !mail.is_a?(ActionMailer::Base::NullMail) && mail.to.present?
  end
end
