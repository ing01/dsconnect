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
    self.password = password if password.present?
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

  def register_client_sign_in!
    # `update_column` de proposito: anotar o login e um carimbo, nao uma
    # alteracao do cadastro - nao deve rodar validacao nem mexer em updated_at,
    # que a equipe le como "quando este contato foi editado".
    update_column(:client_last_sign_in_at, Time.current) # rubocop:disable Rails/SkipsModelValidations
  end

  private

  def client_access_requires_credentials
    return unless client_access_enabled?

    errors.add(:email, I18n.t('contacts.client_access.email_required')) if email.blank?
    errors.add(:password, I18n.t('contacts.client_access.password_required')) if encrypted_password.blank?
  end
end
