namespace :specialist_desk do
  desc 'Atribui os tickets da mesa "Especialista" ao analista responsavel pelo nicho/sub-nicho ' \
       'da empresa (ver Tickets::SpecialistDeskNicheAssigner). Sobrescreve o assignee atual. ' \
       'DRY_RUN=true so mostra o que faria, sem alterar nada. ACCOUNT_ID=1 limita a uma conta.'
  task assign_by_niche: :environment do
    dry_run = ActiveModel::Type::Boolean.new.cast(ENV['DRY_RUN'])
    accounts = ENV['ACCOUNT_ID'].present? ? Account.where(id: ENV.fetch('ACCOUNT_ID')) : Account.all

    puts '[DRY RUN - nada sera alterado]' if dry_run

    accounts.find_each do |account|
      report = Tickets::SpecialistDeskNicheAssigner.new(account, dry_run: dry_run).perform

      if report.team_missing
        puts "Conta #{account.id}: time \"Especialista\" não encontrado, pulando."
        next
      end

      total = report.assigned.size + report.unchanged.size + report.skipped_no_company.size +
              report.skipped_no_niche.size + report.skipped_no_responsible.size + report.skipped_ambiguous.size +
              report.skipped_finalized.size
      next if total.zero?

      puts "Conta #{account.id}: #{report.assigned.size} atribuído(s), #{report.unchanged.size} já correto(s)."
      report.assigned.each { |ticket_id, name| puts "  Ticket ##{ticket_id} -> #{name}" }
      puts "  Sem empresa vinculada: #{report.skipped_no_company.join(', ')}" if report.skipped_no_company.any?
      puts "  Empresa sem nicho/sub-nicho cadastrado: #{report.skipped_no_niche.join(', ')}" if report.skipped_no_niche.any?
      puts "  Nicho/sub-nicho sem analista responsável: #{report.skipped_no_responsible.join(', ')}" if report.skipped_no_responsible.any?
      puts "  Ambíguo (mais de um analista responsável): #{report.skipped_ambiguous.join(', ')}" if report.skipped_ambiguous.any?
      puts "  Finalizado (não pode mais ser alterado): #{report.skipped_finalized.join(', ')}" if report.skipped_finalized.any?
    end
  end
end
