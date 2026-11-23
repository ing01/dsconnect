# O que uma alteracao em massa muda, em linhas legiveis para o log da Gestao de
# clientes ("Nicho: Varejo", "Módulos: adicionar Fiscal, Estoque").
class Companies::BulkUpdateSummary
  STATUS_LABELS = { 'active' => 'Ativo', 'inactive' => 'Inativo' }.freeze
  BILLING_LABELS = { 'monthly' => 'Mensal', 'annual' => 'Anual' }.freeze
  MODE_LABELS = { 'add' => 'adicionar', 'remove' => 'remover', 'replace' => 'substituir por' }.freeze
  CLEARED = 'limpar campo'.freeze

  pattr_initialize [:account!, :changes!]

  def lines
    [status_line, level_line, niche_line, sub_niche_line, specialist_line, billing_line, modules_line].compact
  end

  private

  def data
    @data ||= changes.to_h.with_indifferent_access
  end

  def changed?(key)
    data.key?(key)
  end

  def status_line
    "Situação: #{STATUS_LABELS.fetch(data[:status], data[:status])}" if changed?(:status)
  end

  def level_line
    return unless changed?(:classification_level)

    "Nível: #{data[:classification_level].present? ? data[:classification_level] : CLEARED}"
  end

  def niche_line
    named_line('Nicho', :company_niche_id, account.company_niches)
  end

  def sub_niche_line
    named_line('Subnicho', :company_sub_niche_id, account.company_sub_niches)
  end

  def specialist_line
    named_line('Especialista', :specialist_id, account.users)
  end

  def billing_line
    return unless changed?(:billing_type)

    "Tipo de cobrança: #{BILLING_LABELS.fetch(data[:billing_type], data[:billing_type].presence || CLEARED)}"
  end

  def modules_line
    return unless changed?(:system_module_ids)

    names = account.system_modules.where(id: Array(data[:system_module_ids])).order(:name).pluck(:name)
    "Módulos: #{MODE_LABELS.fetch(data[:modules_mode].presence || 'replace', 'substituir por')} #{names.join(', ')}"
  end

  def named_line(label, key, scope)
    return unless changed?(key)
    return "#{label}: #{CLEARED}" if data[key].blank?

    "#{label}: #{scope.find_by(id: data[key])&.name}"
  end
end
