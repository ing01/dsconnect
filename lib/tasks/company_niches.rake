namespace :company_niches do
  desc 'Vincula os analistas aos nichos e sub-nichos que atendem (cria os que faltam). Idempotente. ACCOUNT_ID=1 limita a uma conta.'
  task link_agents: :environment do
    accounts = ENV['ACCOUNT_ID'].present? ? Account.where(id: ENV.fetch('ACCOUNT_ID')) : Account.all
    accounts.find_each do |account|
      report = CompanyNiches::AgentLinker.new(account).perform
      puts "Conta #{account.id}: #{report.linked_agents.size} agente(s) vinculado(s) (#{report.links} vínculo(s) novo(s)), " \
           "#{report.created_niches} nicho(s) e #{report.created_sub_niches} sub-nicho(s) criado(s)."
      puts "  Não encontrados (ou nome repetido): #{report.missing_agents.join(', ')}" if report.missing_agents.any?
    end
  end
end
