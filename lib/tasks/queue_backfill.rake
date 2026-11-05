namespace :conversations do
  desc 'Coloca na Fila padrao as conversas abertas sem agente e sem fila. Simula por padrao; use APPLY=1 para gravar. ACCOUNT_ID opcional.'
  task backfill_default_queue: :environment do
    apply = ENV['APPLY'] == '1'
    accounts = Account.where.not("(settings->>'helpdesk_default_queue_id') IS NULL")
    accounts = accounts.where(id: ENV['ACCOUNT_ID']) if ENV['ACCOUNT_ID'].present?

    accounts.find_each do |account|
      queue_id = account.helpdesk_default_queue_id
      next if queue_id.blank?

      scope = account.conversations.open.unassigned.where(queue_id: nil)
      puts "Conta #{account.id}: #{scope.count} conversa(s) -> Fila #{queue_id} #{apply ? '' : '(simulacao)'}"
      # update_all de proposito: nao dispara distribuicao automatica nem eventos
      # em massa para conversas antigas.
      scope.update_all(queue_id: queue_id) if apply # rubocop:disable Rails/SkipsModelValidations
    end
  end
end
