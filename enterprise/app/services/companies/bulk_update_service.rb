# Gestao de clientes: aplica as mesmas mudancas a varias Empresas de uma vez
# (nicho, subnicho, nivel, especialista, modulos, tipo de cobranca e status).
#
# So os campos presentes em `changes` sao mexidos - um campo que veio vazio
# LIMPA o valor (ex.: `specialist_id: ''` tira o especialista), um campo ausente
# fica como esta. Cada Empresa e salva pelo model, entao as validacoes e os
# recalculos (prioridade a partir da cobranca, por exemplo) continuam valendo.
# Uma Empresa que nao salva e' listada em `failed` e nao impede as demais.
class Companies::BulkUpdateService
  MODULE_MODES = %w[replace add remove].freeze
  NULLABLE_REFERENCES = %w[company_niche_id company_sub_niche_id specialist_id classification_level billing_type].freeze

  pattr_initialize [:account!, :companies!, :changes!]

  def perform
    error = validation_error
    return { error: error } if error

    updated = 0
    failed = []
    companies.find_each do |company|
      problem = apply(company)
      if problem
        failed << { id: company.id, name: company.name, error: problem }
      else
        updated += 1
      end
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
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved => e
    e.message
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
    references_error || value_error || modules_error
  end

  def references_error
    checks = {
      'company_niche_id' => account.company_niches,
      'company_sub_niche_id' => account.company_sub_niches,
      'specialist_id' => account.users
    }
    checks.each do |key, scope|
      value = attributes[key]
      next if value.blank?
      return "#{key} invalid" unless scope.exists?(id: value)
    end
    nil
  end

  def value_error
    level = attributes['classification_level']
    return 'classification_level invalid' if level.present? && !(1..5).cover?(level.to_i)
    return 'billing_type invalid' if attributes['billing_type'].present? && Company::BILLING_TYPES.exclude?(attributes['billing_type'])
    return 'status invalid' if changes.to_h.key?('status') && Company::STATUSES.exclude?(attributes['status'])

    nil
  end

  def modules_error
    return nil unless change_modules?
    return 'modules_mode invalid' unless MODULE_MODES.include?(mode)
    return 'system_module_ids invalid' unless account.system_modules.where(id: module_ids).count == module_ids.uniq.size

    nil
  end
end
