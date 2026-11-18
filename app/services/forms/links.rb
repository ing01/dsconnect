# Os enderecos para o cliente preencher um Formulario publicado, a partir da Central de Ajuda:
#   - `open`  : /app/forms/<codigo>       - qualquer pessoa com o link, sem login;
#   - `login` : /app/client/forms/<id>    - so' o cliente logado na Area do Cliente (quem nao esta
#                                           logado e' levado ao login e volta ao formulario).
# O endereco-base e' o do sistema (FRONTEND_URL): a Central de Ajuda pode estar num dominio proprio.
module Forms::Links
  def self.base_url
    ENV.fetch('FRONTEND_URL', '').chomp('/')
  end

  def self.client_url(form)
    "#{base_url}/app/client/forms/#{form.id}"
  end

  def self.public_url(form)
    return nil unless form.open_access?

    "#{base_url}/app/forms/#{form.public_token}"
  end

  # O link que a Central de Ajuda mostra ao cliente.
  def self.fill_url(form)
    public_url(form) || client_url(form)
  end
end
