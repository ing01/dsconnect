# A proposta de melhoria enviada ao cliente por e-mail, com o PDF em anexo. Montada sobre o
# ApplicationMailer (SMTP da conta, layout e resolver de templates) e sempre em portugues, como
# os demais e-mails que vao para o cliente.
class TicketProposalMailer < ApplicationMailer
  include ForcedPortugueseLocale

  def proposal_sent(proposal, to_email)
    return unless smtp_config_set_or_development?

    prepare(proposal)
    attachments["proposta-#{@ticket.display_id}-#{proposal.id}.pdf"] = {
      mime_type: 'application/pdf',
      content: Tickets::Proposals::PdfBuilder.new(proposal: proposal).render
    }
    mail(to: to_email, subject: subject_for(proposal))
  end

  private

  def subject_for(proposal)
    I18n.t('ticket_proposal_mailer.proposal_sent.subject', number: @ticket.display_id, summary: proposal.summary.to_s.truncate(80))
  end

  def prepare(proposal)
    @proposal = proposal
    @ticket = proposal.ticket
    @contact = @ticket.requester_contact
    @company_name = proposal.company_name
    @agent_name = proposal.user&.name
    # So' ha como aprovar ou recusar pelo Portal quando a proposta esta liberada la.
    @client_url = "#{ENV.fetch('FRONTEND_URL', '').chomp('/')}/app/client/tickets/#{@ticket.id}" if proposal.visible_to_client
  end
end
