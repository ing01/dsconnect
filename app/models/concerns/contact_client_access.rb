# O lado Contato da Area do Cliente.
#
# O contato E o cliente: quem ja esta cadastrado na Empresa passa a poder entrar
# quando a equipe interna liga o acesso e define uma senha. Nada aqui duplica o
# cadastro - nome, e-mail, telefone e empresa continuam sendo os do contato.
module ContactClientAccess
  extend ActiveSupport::Concern

  # Ate onde o contato enxerga dentro da propria empresa.
  #
  # `own` e o padrao de proposito: liberar todos os chamados da empresa a quem
  # acabou de ganhar acesso exporia atendimentos de outras pessoas da mesma
  # empresa sem ninguem ter decidido isso.
  VISIBILITY = { own: 0, company: 1 }.freeze

  # A troca de senha do primeiro acesso exige um minimo maior que o da
  # redefinicao por e-mail: a senha padrao e conhecida por muita gente.
  MIN_CHANGED_PASSWORD_LENGTH = 8

  # E-mail de contato anonimizado (conta excluida) - nunca recebe acesso.
  ANONYMIZED_EMAIL_SUFFIX = '@excluido.invalid'.freeze

  class_methods do
    # A senha padrao vem do ambiente, nunca do codigo nem do banco: assim ela nao
    # fica no repositorio. Sem ela definida, o recurso inteiro fica desligado.
    def default_client_password
      ENV['CLIENT_DEFAULT_PASSWORD'].presence
    end

    # O hash bcrypt e calculado UMA vez por processo e reaproveitado: gerar um por
    # contato custaria ~0,2s cada, o que travaria uma importacao grande. O sal
    # vai dentro do hash, entao `valid_password?` funciona normalmente.
    def default_client_password_hash
      senha = default_client_password
      return if senha.blank?

      @default_client_password_hashes ||= {}
      @default_client_password_hashes[senha] ||= Devise::Encryptor.digest(self, senha)
    end

    # Dias de validade da senha padrao; vazio = nunca expira (o padrao).
    def default_client_password_expires_in_days
      dias = ENV['CLIENT_DEFAULT_PASSWORD_EXPIRES_DAYS'].to_i
      dias if dias.positive?
    end
  end

  included do
    # O token de sessao e o mesmo AccessToken do resto do sistema, com o contato
    # como dono. Nao se usa o AccessTokenable: aquele concern cria um token no
    # `after_create` de todo registro, e contato nasce as centenas pelas
    # conversas - aqui o token so existe a partir do primeiro login.
    has_one :access_token, as: :owner, dependent: :destroy

    # Mesmo hash e mesmo mecanismo de recuperacao do usuario interno: bcrypt via
    # Devise, com o token de redefinicao que o proprio Devise gera e expira.
    #
    # :validatable fica de fora de proposito - ela exigiria e-mail e senha de
    # TODO contato, e a esmagadora maioria nao tem nem vai ter.
    devise :database_authenticatable, :recoverable

    enum client_tickets_visibility: VISIBILITY, _prefix: :sees

    # A credencial so faz sentido com o acesso ligado; e o acesso so se sustenta
    # com e-mail (e o login) e senha.
    validate :client_access_requires_credentials

    # A confirmacao viria de `:validatable`, que fica de fora de proposito (ela
    # exigiria e-mail e senha de TODO contato). Sem esta linha, digitar duas
    # senhas diferentes na tela de redefinicao gravava a primeira em silencio.
    # So roda quando `password_confirmation` foi preenchido, entao nao atrapalha
    # quem define a senha pelo cadastro interno.
    validates :password, confirmation: true

    scope :with_client_access, -> { where(client_access_enabled: true) }

    # Senha padrao: todo solicitante (contato com e-mail e vinculado a uma Empresa)
    # nasce com acesso e com a senha padrao, e precisa trocar no primeiro acesso
    # (pelo site). Antes da validacao, porque `client_access_requires_credentials`
    # exige a credencial ja preenchida quando o acesso esta ligado.
    before_validation :apply_default_client_access, if: :provision_default_client_access?

    # Quem pode receber o e-mail de redefinicao.
    #
    # `client_access?` e nao so o e-mail: mandar link de senha para contato sem
    # acesso ligado seria oferecer uma porta que nao abre. E-mail nao e unico
    # entre contas, entao o primeiro com acesso responde - quem tem acesso em
    # duas contas e caso que o cadastro nao modela hoje.
    def self.client_recoverable_from_email(email)
      return if email.blank?

      with_client_access.where('lower(email) = ?', email.to_s.downcase)
                        .find(&:client_access?)
    end
  end

  # Pode entrar? Reune tudo que o login exige, para a resposta ser uma so - e a
  # mesma pergunta vale na tela, na sessao e a cada requisicao seguinte.
  #
  # Contato bloqueado ENTRA no Portal (chamados, propostas...), mas nao usa o
  # chat com a equipe - ver `client_chat_allowed?`.
  def client_access?
    client_access_enabled? && email.present? && encrypted_password.present?
  end

  # O chat com a equipe e' a unica parte do Portal que o bloqueio fecha: quem
  # foi bloqueado nao deve abrir conversa com os atendentes.
  def client_chat_allowed?
    !blocked?
  end

  # Liga o acesso. A senha e opcional numa reativacao: quem ja tinha credencial
  # volta a entrar com a mesma, sem a equipe precisar inventar outra.
  def enable_client_access!(password: nil)
    if password.present?
      self.password = password
      # Senha escolhida pela equipe no cadastro: nao e a padrao, nao ha o que trocar.
      self.password_change_required = false
      self.default_password_set_at = nil
    end
    self.client_access_enabled = true
    self.client_access_enabled_at ||= Time.current
    save!
  end

  # Desliga sem apagar a senha: religar nao obriga a cadastrar credencial de
  # novo, e a sessao aberta cai na proxima requisicao porque `client_access?`
  # passa a ser falso.
  def disable_client_access!
    update!(client_access_enabled: false)
    revoke_client_sessions!
  end

  # As empresas as quais este contato pertence. A Area do Cliente nunca olha
  # alem disto - e a fronteira de tudo que ele enxerga.
  def client_company_ids
    # `companies` (juncao) e `company_id` (primaria) ja existem no cadastro e
    # sao mantidas em sincronia pelo Enterprise::Concerns::Contact. Lemos as
    # duas porque um contato antigo pode ter so a primaria.
    ([company_id] + company_ids).compact.uniq
  end

  # Os tickets que este contato pode ver. UMA definicao, usada por toda consulta
  # da Area do Cliente: listagem, Kanban, detalhe e contagem.
  #
  # Fora de qualquer empresa nao ha o que mostrar - devolver os tickets "dele"
  # soltos abriria acesso a um contato que ninguem vinculou a lugar nenhum.
  def visible_tickets
    empresas = client_company_ids
    return Ticket.none if empresas.empty?

    escopo = account.tickets.where(company_id: empresas)
    sees_company? ? escopo : escopo.where(contact_id: id)
  end

  # As manifestacoes de SAC que este contato pode ver.
  #
  # Mesma fronteira dos tickets, pela mesma razao - e de proposito que a
  # permissao reaproveitada e `client_tickets_visibility`: quem foi autorizado a
  # ver os chamados da empresa toda ve tambem as manifestacoes dela, e quem so ve
  # os proprios chamados so ve as proprias manifestacoes. Um segundo campo de
  # permissao sobre a mesma pergunta daria duas respostas para administrar.
  def visible_manifestations
    empresas = client_company_ids
    return Manifestation.none if empresas.empty?

    escopo = account.manifestations.where(company_id: empresas)
    sees_company? ? escopo : escopo.where(contact_id: id)
  end

  # O token de sessao. E o mesmo AccessToken que o resto do sistema usa, so que
  # com o contato como dono - nao ha tabela de sessao de cliente.
  def client_access_token
    access_token || create_access_token!(owner: self)
  end

  # Dispara o e-mail de redefinicao e devolve o token gerado.
  #
  # Nao usa `send_reset_password_instructions` do Devise porque aquele caminho
  # passa pelo `Devise::Mailer`, cuja view monta a URL com
  # `edit_password_url(resource)` - rota que so existe para quem tem
  # `devise_for`. Aqui o token e o do Devise (gerado, digerido e expirado por
  # ele); so a mensagem e nossa.
  def send_client_reset_password_instructions
    token = set_reset_password_token
    ClientPasswordMailer.with(account: account)
                        .reset_password_instructions(self, token)
                        .deliver_later
    token
  end

  def revoke_client_sessions!
    access_token&.destroy
    reload
  end

  # Ainda com a senha padrao e o prazo (se houver) ja passou: nao entra mais com
  # ela, so pelo "esqueci minha senha". Sem prazo configurado, nunca expira.
  def client_default_password_expired?
    dias = self.class.default_client_password_expires_in_days
    password_change_required? && dias.present? && default_password_set_at.present? &&
      default_password_set_at < dias.days.ago
  end

  # Chamado quando o vinculo com a Empresa nasce DEPOIS do contato (importacao de
  # solicitantes, vinculo pela tela): so' agora ele passa a ser um solicitante.
  def provision_default_client_access!
    return unless provision_default_client_access?(persisted_company_link: true)

    apply_default_client_access
    # `save`, e nao `save!`: isto roda depois do vinculo, que nao pode falhar por
    # causa de um contato com dado invalido (e-mail fora do formato, por exemplo) -
    # ele so' fica sem a senha padrao.
    return true if save

    Rails.logger.warn("Senha padrao nao aplicada ao contato #{id}: #{errors.full_messages.to_sentence}")
    false
  end

  # Troca de senha do primeiro acesso. Devolve um simbolo (`:ok` ou o motivo da
  # recusa) para o controller traduzir - nada aqui conhece HTTP.
  def change_client_password(current_password:, password:, confirmation:)
    return :wrong_current unless valid_password?(current_password.to_s)
    return :too_short if password.to_s.length < MIN_CHANGED_PASSWORD_LENGTH
    return :mismatch unless password == confirmation
    return :same_as_current if password == current_password
    return :same_as_default if password == self.class.default_client_password

    self.password = password
    self.password_confirmation = confirmation
    self.password_change_required = false
    self.default_password_set_at = nil
    save ? :ok : :invalid
  end

  # Redefinir por e-mail tambem encerra a exigencia: a pessoa ja escolheu uma senha.
  def clear_password_change_requirement!
    update_columns(password_change_required: false, default_password_set_at: nil) # rubocop:disable Rails/SkipsModelValidations
  end

  def register_client_sign_in!
    # `update_column` de proposito: anotar o login e um carimbo, nao uma
    # alteracao do cadastro - nao deve rodar validacao nem mexer em updated_at,
    # que a equipe le como "quando este contato foi editado".
    update_column(:client_last_sign_in_at, Time.current) # rubocop:disable Rails/SkipsModelValidations
  end

  private

  def apply_default_client_access
    self.encrypted_password = self.class.default_client_password_hash
    self.client_access_enabled = true
    self.client_access_enabled_at ||= Time.current
    self.password_change_required = true
    self.default_password_set_at = Time.current
  end

  # Quem recebe a senha padrao: contato com e-mail, VINCULADO A UMA EMPRESA e sem
  # credencial ainda. Sem Empresa nao entra. So dispara na criacao ou quando o
  # e-mail/a Empresa acabam de aparecer - nunca religa quem ja tem senha
  # (inclusive quem a equipe desligou: o desligamento guarda a senha), e nunca
  # toca em conta anonimizada.
  def provision_default_client_access?(persisted_company_link: false)
    return false if self.class.default_client_password.blank?
    return false if email.blank? || email.downcase.end_with?(ANONYMIZED_EMAIL_SUFFIX)
    return false if encrypted_password.present?
    return false unless client_company_link?(persisted_company_link)

    persisted_company_link || new_record? || will_save_change_to_email? || will_save_change_to_company_id?
  end

  # `company_id` e' a Empresa principal; o vinculo pela juncao (`company_contacts`)
  # so existe depois que o contato foi gravado - e' o caso da importacao.
  def client_company_link?(persisted_company_link)
    return true if company_id.present?

    persisted_company_link && persisted? && company_contacts.exists?
  end

  def client_access_requires_credentials
    return unless client_access_enabled?

    errors.add(:email, I18n.t('contacts.client_access.email_required')) if email.blank?
    errors.add(:password, I18n.t('contacts.client_access.password_required')) if encrypted_password.blank?
  end
end
