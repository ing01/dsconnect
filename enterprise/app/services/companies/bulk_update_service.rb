# Gestao de clientes: aplica as mesmas mudancas a varias Empresas de uma vez
# (nicho, subnicho, nivel, especialista, modulos, tipo de cobranca e status).
#
# So os campos presentes em `changes` sao mexidos - um campo que veio vazio
# LIMPA o valor (ex.: `specialist_id: ''` tira o especialista), um campo ausente
# fica como esta. Cada Empresa e salva pelo model, entao as validacoes continuam
# valendo. Uma Empresa que nao salva e' listada em `failed`, com o motivo em
# linguagem simples (`friendly_error`), e nao impede as demais.
class Companies::BulkUpdateService
  MODULE_MODES = %w[replace add remove].freeze
  NULLABLE_REFERENCES = %w[company_niche_id company_sub_niche_id specialist_id classification_level billing_type].freeze
  PROGRESS_EVERY = 25

  # Como cada campo aparece para quem le o log.
  FIELD_LABELS = {
    'company_niche_id' => 'Nicho', 'company_sub_niche_id' => 'Subnicho', 'specialist_id' => 'Especialista',
    'classification_level' => 'Nível', 'billing_type' => 'Tipo de cobrança', 'status' => 'Situação',
    'system_module_ids' => 'Módulos', 'modules_mode' => 'Forma de alterar os módulos'
  }.freeze
  ATTRIBUTE_LABELS = {
    cnpj: 'CNPJ', domain: 'Domínio', name: 'Nome', codigo: 'Código', legal_name: 'Razão social',
    billing_amount: 'Valor da cobrança', billing_type: 'Tipo de cobrança', classification_level: 'Nível',
    status: 'Situação', description: 'Descrição'
  }.freeze

  pattr_initialize [:account!, :companies!, :changes!, :on_progress]

  # Motivo pelo qual as mudancas nao podem ser aplicadas (nil = tudo certo).
  # Conferido ANTES de enfileirar o trabalho, para o usuario ver o erro na hora.
  def error
    validation_error
  end

  def perform
    problem = validation_error
    return { error: problem } if problem

    updated = 0
    failed = []
    processed = 0
    companies.find_each do |company|
      failure = apply(company)
      if failure
        failed << { id: company.id, name: company.name, error: failure }
      else
        updated += 1
      end
      processed += 1
      on_progress&.call(processed, updated, failed.size) if (processed % PROGRESS_EVERY).zero?
    end
    { updated: updated, failed: failed }
  end

  private

  def attributes
    @attributes ||= changes.to_h.stringify_keys.slice(*NULLABLE_REFERENCES, 'status').transform_values(&:presence)
  end

  def module_ids
    @module_ids ||= Array(changes[:system_module_ids]).compact_blank.map(&:to_i)
  end

  def change_modules?
    changes.to_h.key?('system_module_ids')
  end

  def mode
    changes[:modules_mode].presence || 'replace'
  end

  def apply(company)
    Company.transaction do
      company.assign_attributes(attributes)
      company.system_module_ids = target_modules(company) if change_modules?
      company.save!
    end
    nil
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved
    friendly_error(company)
  rescue StandardError => e
    Rails.logger.error("[Companies::BulkUpdateService] company #{company.id}: #{e.class}: #{e.message}")
    I18n.t('errors.companies.bulk_update.unexpected')
  end

  # "CNPJ: não é válido" em vez de "Validation failed: Cnpj is invalid".
  def friendly_error(company)
    messages = company.errors.map do |error|
      label = ATTRIBUTE_LABELS.fetch(error.attribute.to_sym) { company.class.human_attribute_name(error.attribute) }
      "#{label}: #{error.message}"
    end
    messages.presence&.join('; ') || I18n.t('errors.companies.bulk_update.not_saved')
  end

  def target_modules(company)
    current = company.system_module_ids
    case mode
    when 'add' then current | module_ids
    when 'remove' then current - module_ids
    else module_ids
    end
  end

  # Confere tudo antes de tocar em qualquer Empresa: uma referencia de outra conta
  # (ou inventada) derrubaria todas as gravacoes uma a uma.
  def validation_error
    invalid_field = references_error || value_error || modules_error
    return nil if invalid_field.blank?

    I18n.t('errors.companies.bulk_update.invalid_field', field: FIELD_LABELS.fetch(invalid_field, invalid_field))
  end

  # Cada checagem devolve a CHAVE do campo com problema (ou nil).
  def references_error
    checks = {
      'company_niche_id' => account.company_niches,
      'company_sub_niche_id' => account.company_sub_niches,
      'specialist_id' => account.users
    }
    checks.each do |key, scope|
      value = attributes[key]
      next if value.blank?
      return key unless scope.exists?(id: value)
    end
    nil
  end

  def value_error
    level = attributes['classification_level']
    return 'classification_level' if level.present? && !(1..5).cover?(level.to_i)
    return 'billing_type' if attributes['billing_type'].present? && Company::BILLING_TYPES.exclude?(attributes['billing_type'])
    return 'status' if changes.to_h.key?('status') && Company::STATUSES.exclude?(attributes['status'])

    nil
  end

  def modules_error
    return nil unless change_modules?
    return 'modules_mode' unless MODULE_MODES.include?(mode)
    return 'system_module_ids' unless account.system_modules.where(id: module_ids).count == module_ids.uniq.size

    nil
  end
end
