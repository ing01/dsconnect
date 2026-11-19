# Carga inicial pedida pela equipe: os analistas e os nichos/sub-nichos que atendem
# (CompanyNiches::AgentLinker::LINKS). Idempotente e sem efeito em conta onde os analistas nao
# existem. Um erro aqui NAO derruba o deploy: fica no log e o `rake company_niches:link_agents`
# repete o passo.
class LinkAgentsToCompanyNiches < ActiveRecord::Migration[7.2]
  def up
    Account.find_each do |account|
      report = CompanyNiches::AgentLinker.new(account).perform
      next if report.linked_agents.empty?

      say "conta #{account.id}: #{report.linked_agents.join(', ')} (#{report.links} vínculos; " \
          "#{report.created_niches} nichos e #{report.created_sub_niches} sub-nichos criados)"
      say "  não encontrados: #{report.missing_agents.join(', ')}" if report.missing_agents.any?
    end
  rescue StandardError => e
    say "vínculo dos analistas aos nichos NÃO aplicado (#{e.class}: #{e.message}); rode: bundle exec rake company_niches:link_agents"
  end

  def down; end
end
