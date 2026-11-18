# Preenche um Formulario pelo painel (agente), a partir do Artigo (POP) da Base de Conhecimento.
# O chamado e' opcional: informado pelo numero dele (`display_id`, o "#35369" da tela), a resposta
# fica no historico do chamado; sem numero, fica so' guardada na lista de respostas do formulario.
# A validacao e a gravacao sao as do Forms::SubmitService.
class Forms::FillService
  class InvalidFill < StandardError; end

  pattr_initialize [:form!, :user!, { ticket_display_id: nil, answers: {}, files: {} }]

  def perform
    Forms::SubmitService.new(
      form: form, source: 'internal', user: user, ticket: ticket, answers: answers, files: files
    ).perform
  rescue Forms::SubmitService::InvalidSubmission => e
    raise InvalidFill, e.message
  end

  private

  def ticket
    number = ticket_display_id.to_s.delete('#').strip
    return nil if number.blank?

    form.account.tickets.find_by(display_id: number) || raise(InvalidFill, 'chamado não encontrado: confira o número')
  end
end
