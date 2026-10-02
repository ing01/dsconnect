# A conversa de uma manifestacao: as respostas que o cliente LE e as anotacoes
# que so a equipe ve, na mesma tabela.
#
# `visibility` e o que separa as duas, e `visible_to_client` e o unico caminho
# pelo qual a Area do Cliente le mensagens - ver
# Api::V1::Client::ManifestationsController.
class ManifestationMessage < ApplicationRecord
  belongs_to :manifestation
  belongs_to :account
  # Autor: o agente OU o contato. Os dois nulaveis para que remover quem
  # escreveu nao apague o que foi dito.
  belongs_to :user, optional: true
  belongs_to :contact, optional: true

  VISIBILITIES = { public_reply: 0, internal_note: 1 }.freeze

  enum visibility: VISIBILITIES

  validates :body, presence: true
  validate :author_must_be_present

  before_validation :ensure_account_id

  # A fronteira do que sai para o cliente. Scope, e nao um `reject` na view: o
  # filtro precisa estar na CONSULTA para que nenhuma tela consiga esquece-lo.
  scope :visible_to_client, -> { where(visibility: :public_reply) }
  scope :chronological, -> { order(:created_at, :id) }

  # O cliente so escreve mensagem publica - a nota interna e da equipe.
  def from_client?
    contact_id.present?
  end

  # Quem escreveu. De fora e o contato; de dentro, o agente.
  def author_name
    from_client? ? contact&.name : user&.name
  end

  private

  def ensure_account_id
    self.account_id ||= manifestation&.account_id
  end

  # Sem autor nao da para dizer de que lado a mensagem veio - e e isso que
  # decide se ela aparece como resposta da equipe ou do cliente.
  def author_must_be_present
    return if user_id.present? || contact_id.present?

    errors.add(:base, I18n.t('manifestations.message.author_required'))
  end
end
