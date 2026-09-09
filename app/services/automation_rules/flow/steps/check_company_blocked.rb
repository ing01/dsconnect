# Reconfirma o bloqueio quando a Empresa e identificada no meio da conversa
# (por CNPJ, ou por escolha entre varias) - o `BlockGateService` do dispatcher
# so conhece a Empresa primaria que o contato ja tinha ao comecar o fluxo.
class AutomationRules::Flow::Steps::CheckCompanyBlocked < AutomationRules::Flow::Steps::Base
  def perform
    company_id = run.read_variable('empresa.id')
    company = account.companies.find_by(id: company_id)
    return branch_blocked if company.blank? || company.blocked?

    continue(result: { blocked: false })
  end

  private

  def branch_blocked
    target = step.dig('branches', 'blocked')
    return handoff(result: { blocked: true }) if target.blank?

    continue(target, result: { blocked: true })
  end
end
