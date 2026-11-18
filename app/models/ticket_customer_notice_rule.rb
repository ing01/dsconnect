# == Schema Information
#
# Table name: ticket_customer_notice_rules
#
#  id               :bigint           not null, primary key
#  active           :boolean          default(TRUE), not null
#  body             :text             not null
#  kind             :string           not null
#  name             :string           not null
#  notify_customer  :boolean          default(TRUE), not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  account_id       :bigint           not null
#  from_team_id     :bigint
#  team_id          :bigint
#  ticket_column_id :bigint
#
# Uma mensagem automatica ao cliente do ticket, configurada em Configuracoes >
# Tickets > Mensagens ao cliente. Dispara quando o ticket ENTRA num Estagio
# (`kind: 'stage'`) ou passa para uma Mesa (`kind: 'team'`) - ver
# Tickets::CustomerNoticeService.
#
# O texto aceita variaveis entre chaves duplas ({{numero}}, {{estagio}}...),
# trocadas pelos dados do ticket no momento do envio.
class TicketCustomerNoticeRule < ApplicationRecord
  KINDS = %w[stage team].freeze

  # variavel => rotulo mostrado na tela de configuracao.
  VARIABLES = {
    'numero' => 'Número do ticket',
    'titulo' => 'Título',
    'cliente' => 'Cliente/Empresa',
    'solicitante' => 'Solicitante',
    'responsavel' => 'Responsável',
    'estagio' => 'Estágio atual',
    'mesa' => 'Mesa atual',
    'mesa_anterior' => 'Mesa anterior'
  }.freeze

  belongs_to :account
  belongs_to :ticket_column, optional: true
  belongs_to :team, optional: true
  belongs_to :from_team, class_name: 'Team', optional: true

  validates :name, presence: true, length: { maximum: 120 }
  validates :body, presence: true, length: { maximum: 5000 }
  validates :kind, inclusion: { in: KINDS }
  validates :ticket_column, presence: true, if: -> { kind == 'stage' }
  validates :team, presence: true, if: -> { kind == 'team' }
  validate :references_belong_to_account

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:id) }

  # Regras que valem para um ticket que acabou de entrar em `column_id` e,
  # quando a Mesa mudou, de `from_team_id` para `to_team_id`.
  def self.matching(account_id:, column_id:, from_team_id: nil, to_team_id: nil)
    scope = active.where(account_id: account_id)
    stage = scope.where(kind: 'stage', ticket_column_id: column_id)
    return stage if to_team_id.blank?

    team = scope.where(kind: 'team', team_id: to_team_id)
                .where('from_team_id IS NULL OR from_team_id = ?', from_team_id)
    stage.or(team)
  end

  # O texto final: troca cada {{variavel}} pelo dado do ticket. Uma variavel
  # desconhecida fica como foi escrita - melhor visivel do que sumir em silencio.
  def render_body(ticket, previous_team: nil)
    values = variables_for(ticket, previous_team)
    body.gsub(/\{\{\s*(\w+)\s*\}\}/) { values.fetch(Regexp.last_match(1), Regexp.last_match(0)).to_s }
  end

  private

  def variables_for(ticket, previous_team)
    {
      'numero' => ticket.display_id,
      'titulo' => ticket.title,
      'cliente' => ticket.company&.name || ticket.requester_contact&.name,
      'solicitante' => ticket.requester_contact&.name,
      'responsavel' => ticket.assignee&.name,
      'estagio' => ticket.ticket_column&.name,
      'mesa' => display_team_name(ticket.team),
      'mesa_anterior' => display_team_name(previous_team)
    }
  end

  # Mesas ficam em minusculas no banco; a mensagem do cliente leva o nome
  # capitalizado, como as telas.
  def display_team_name(team)
    team&.name.to_s.gsub(/\p{L}[\p{L}\p{M}'’-]*/u, &:capitalize)
  end

  def references_belong_to_account
    [ticket_column&.team, team, from_team].compact.each do |record|
      next if record.account_id == account_id

      errors.add(:base, 'Estágio ou Mesa de outra conta')
      break
    end
  end
end
