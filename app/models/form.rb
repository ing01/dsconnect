# O Formulario (estilo Google Forms) - template por conta, com as perguntas
# guardadas em `fields` (jsonb), mesmo padrao de Checklist#items. Pode estar
# vinculado a um Artigo (qual POP ele documenta) e a varios itens do
# Catalogo de Servicos (anexados automaticamente no checklist do ticket
# quando o item e' classificado - ver Ticket#classify!).
class Form < ApplicationRecord
  STATUSES = %w[draft published].freeze
  FIELD_TYPES = %w[short_text paragraph single_choice multiple_choice dropdown date file_upload].freeze
  # Quem pode preencher quando o formulario e' publicado na Central de Ajuda:
  # `login` (so' cliente logado na Area do Cliente - o padrao) ou `open` (qualquer pessoa com o link).
  ACCESS_MODES = %w[login open].freeze

  belongs_to :account
  belongs_to :article, optional: true

  has_many :service_catalog_item_forms, dependent: :destroy
  has_many :service_catalog_items, through: :service_catalog_item_forms
  has_many :form_responses, dependent: :destroy
  has_many :ticket_checklist_items, dependent: :nullify

  validates :name, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :access_mode, inclusion: { in: ACCESS_MODES }

  # O codigo do link do formulario aberto: aleatorio, nao e' o id do banco.
  has_secure_token :public_token

  scope :ordered, -> { order(:name) }
  scope :published, -> { where(status: 'published') }

  def published?
    status == 'published'
  end

  def open_access?
    access_mode == 'open'
  end

  # Cada pergunta do `fields` jsonb: `{id, label, description, field_type,
  # required, options, position}` - string keys, ja que passam por JSON toda
  # vez que o formulario e' salvo. `id` e' gerado no FRONTEND (uuid local),
  # nao e' um FK de banco - so' serve pra `FormAnswer#field_id` saber a qual
  # pergunta aquela resposta pertence.
  def self.field_attributes_from(field, position)
    field = field.is_a?(Hash) ? field.with_indifferent_access : {}
    {
      'id' => field[:id].presence || SecureRandom.uuid,
      'label' => field[:label].to_s,
      'description' => field[:description].to_s,
      'field_type' => FIELD_TYPES.include?(field[:field_type]) ? field[:field_type] : 'short_text',
      'required' => ActiveModel::Type::Boolean.new.cast(field[:required]) || false,
      'options' => field[:options].is_a?(Array) ? field[:options].map(&:to_s) : [],
      'position' => position
    }
  end

  def normalized_field(field_id)
    fields.find { |field| field['id'] == field_id.to_s }
  end
end
