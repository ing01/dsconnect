# "Converter em Ticket": a manifestacao que precisa de atendimento de verdade
# entra no fluxo normal.
#
# Nao monta um ticket a mao - repete o caminho que o Portal do Cliente ja usa
# (Api::V1::Client::TicketsController#build_ticket): Mesa da Categoria ou a
# primeira ativa, Estagio de entrada da Mesa, prioridade media, empresa e
# contato preservados. Assim o ticket convertido e indistinguivel de um aberto
# pelo Portal, e nao um registro meio preenchido que a equipe precisa consertar.
#
# A conversao e IRREVERSIVEL e UNICA: `converted_ticket_id` ja preenchido faz o
# servico recusar, e e isso que impede a duplicidade pedida.
class Manifestations::TicketConversionService
  class AlreadyConverted < StandardError; end
  class NoTeamAvailable < StandardError; end

  def initialize(manifestation:, user:, team: nil, category: nil)
    @manifestation = manifestation
    @user = user
    @team = team
    @category = category
  end

  def perform
    raise AlreadyConverted, I18n.t('manifestations.convert.already_done') if @manifestation.converted?

    ActiveRecord::Base.transaction do
      ticket = build_ticket
      ticket.save!
      copy_attachments!(ticket)
      link!(ticket)
      log!(ticket)
      ticket
    end
  end

  private

  attr_reader :manifestation, :user

  def account
    manifestation.account
  end

  # A Mesa: a escolhida por quem converteu, senao a da Categoria, senao a
  # primeira ativa. Sem nenhuma Mesa ativa nao ha para onde mandar o chamado, e
  # falhar aqui e melhor do que criar um ticket sem Mesa.
  def team
    @team ||= @category&.team || account.teams.active.order(:name).first
  end

  def category
    # Uma Categoria de outra Mesa nao sobrevive a validacao
    # `ticket_category_belongs_to_team` do ticket - entao ela so vale se for da
    # Mesa resolvida.
    return @category if @category.present? && @category.team_id == team&.id

    team&.ticket_categories&.order(:position, :id)&.first
  end

  def entry_column(team)
    team.ticket_columns.find_by(kind: 'pending') || team.ticket_columns.order(:position, :id).first
  end

  def build_ticket
    raise NoTeamAvailable, I18n.t('manifestations.convert.no_team') if team.blank?

    ticket = account.tickets.new(
      title: manifestation.title,
      # A descricao leva a origem no corpo: quem abre o ticket precisa saber que
      # ele nasceu de uma manifestacao, e o numero e a forma de voltar nela.
      description: converted_description
    )
    apply_routing(ticket)
    apply_requester(ticket)
    ticket
  end

  def apply_routing(ticket)
    ticket.team = team
    ticket.ticket_column = entry_column(team)
    ticket.ticket_category = category
    ticket.priority = 'medium'
    # O Portal ja roteia sozinho, e aqui quem converte e um humano que escolheu a
    # Mesa: nao ha o que triar.
    ticket.pending_triage = false
  end

  def apply_requester(ticket)
    ticket.company_id = manifestation.company_id
    ticket.contact_id = manifestation.contact_id
    ticket.origin = 'client_area'
  end

  def converted_description
    I18n.t('manifestations.convert.description_header',
           reference: manifestation.reference,
           kind: I18n.t("manifestations.kinds.#{manifestation.kind}"),
           subject: I18n.t("manifestations.subject_areas.#{manifestation.subject_area}")) +
      "\n\n#{manifestation.description}"
  end

  # Os anexos vao para o ticket por COPIA da referencia do Active Storage - o
  # mesmo blob, sem reenviar o arquivo. A manifestacao continua com os dela: ela
  # nao deixa de existir por ter virado ticket.
  def copy_attachments!(ticket)
    manifestation.manifestation_attachments.each do |origem|
      next unless origem.file.attached?

      destino = ticket.ticket_attachments.new(account_id: ticket.account_id, user: user)
      destino.file.attach(origem.file.blob)
      destino.save!
    end
  end

  def link!(ticket)
    manifestation.update!(
      converted_ticket: ticket,
      converted_at: Time.current,
      # Convertida = o assunto passou a ser tratado no ticket. Deixa-la em
      # "Recebida" faria a fila interna mostrar como nova uma manifestacao que
      # ja esta em andamento em outro lugar.
      status: :in_progress
    )
  end

  def log!(ticket)
    manifestation.manifestation_activities.create!(
      user: user,
      activity_type: :converted_to_ticket,
      new_value: ticket.display_id.to_s,
      meta: { ticket_id: ticket.id, ticket_display_id: ticket.display_id, team_id: ticket.team_id }
    )
  end
end
