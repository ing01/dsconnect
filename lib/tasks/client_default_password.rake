# Aplica a senha padrao da Area do Cliente aos solicitantes que ja existem.
#
#   Simulacao (nao grava nada):
#     bundle exec rails client_access:apply_default_password
#   Gravar:
#     CONFIRM=1 bundle exec rails client_access:apply_default_password
#   So uma conta:
#     ACCOUNT_ID=2 CONFIRM=1 bundle exec rails client_access:apply_default_password
#
# Quem recebe: contato com e-mail, VINCULADO A UMA EMPRESA, que NUNCA teve acesso
# ao portal. Sem Empresa nao entra.
#
# Quem ja tem acesso NAO e' tocado, em hipotese nenhuma. Fica de fora quem:
#   - tem o acesso ligado;
#   - tem senha gravada (inclusive quem a equipe desligou - o desligamento guarda a senha);
#   - ja entrou alguma vez (client_last_sign_in_at) ou teve o acesso ligado antes
#     (client_access_enabled_at);
#   - tem sessao de cliente criada (access_tokens).
# Contato anonimizado (conta excluida) tambem e' ignorado. NADA e' enviado por
# e-mail: a senha e' entregue pela equipe.
namespace :client_access do
  desc 'Aplica a senha padrao (CLIENT_DEFAULT_PASSWORD) aos solicitantes com e-mail e sem senha (CONFIRM=1 grava)'
  task apply_default_password: :environment do
    hash = Contact.default_client_password_hash
    abort 'CLIENT_DEFAULT_PASSWORD nao esta definida no ambiente.' if hash.blank?

    com_empresa = 'contacts.company_id IS NOT NULL OR EXISTS (SELECT 1 FROM company_contacts cc WHERE cc.contact_id = contacts.id)'
    com_email = Contact.where("contacts.email IS NOT NULL AND contacts.email <> ''")
    com_email = com_email.where(account_id: ENV['ACCOUNT_ID']) if ENV['ACCOUNT_ID'].present?

    # Nunca teve acesso: nem ligado, nem senha, nem login, nem sessao.
    sem_acesso_nenhum = "contacts.encrypted_password = '' OR contacts.encrypted_password IS NULL"
    sem_sessao = "NOT EXISTS (SELECT 1 FROM access_tokens t WHERE t.owner_type = 'Contact' AND t.owner_id = contacts.id)"
    escopo = com_email.where(client_access_enabled: false)
                      .where(sem_acesso_nenhum)
                      .where(client_access_enabled_at: nil, client_last_sign_in_at: nil)
                      .where(sem_sessao)
                      .where.not('contacts.email ILIKE ?', "%#{ContactClientAccess::ANONYMIZED_EMAIL_SUFFIX}")
                      .where(com_empresa)

    # So informativo: quem ja tem acesso e portanto fica intacto.
    ja_com_acesso = com_email.where('contacts.client_access_enabled = TRUE OR contacts.client_last_sign_in_at IS NOT NULL ' \
                                    "OR NOT (#{sem_acesso_nenhum})")
    puts "Contatos que JA tem acesso ao portal (NAO serao alterados): #{ja_com_acesso.count}"
    puts "Contatos que receberiam a senha padrao: #{escopo.count}"
    escopo.group(:account_id).count.each { |conta, total| puts "  conta #{conta}: #{total}" }

    if ENV['CONFIRM'] != '1'
      puts 'Simulacao: nada foi gravado. Rode de novo com CONFIRM=1 para aplicar.'
      next
    end

    agora = Time.current
    total = 0
    escopo.in_batches(of: 1000) do |lote|
      # `update_all` de proposito: sem callbacks nem bcrypt por contato, e sem
      # mexer em `updated_at` (a equipe le isso como "quando foi editado").
      total += lote.update_all(encrypted_password: hash, client_access_enabled: true, # rubocop:disable Rails/SkipsModelValidations
                               client_access_enabled_at: agora, password_change_required: true,
                               default_password_set_at: agora)
    end
    puts "Senha padrao aplicada a #{total} contatos."
  end
end
