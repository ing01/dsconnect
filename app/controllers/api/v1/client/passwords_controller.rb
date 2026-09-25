# A redefinicao de senha da Area do Cliente.
#
# NAO herda de Api::V1::Client::BaseController de proposito: aquela base exige
# sessao a cada requisicao, e quem esqueceu a senha justamente nao tem nenhuma.
# O que autoriza aqui e o token do e-mail, gerado, digerido e expirado pelo
# proprio Devise (`reset_password_within`).
#
# O pedido do link nao mora aqui - ele entra pelo MESMO botao "Esqueci minha
# senha" da tela de login, em DeviseOverrides::PasswordsController#create, que
# cai no contato quando nenhum usuario interno responde pelo e-mail. A tela e
# compartilhada, e quem digita o e-mail nao tem como saber qual dos dois e.
class Api::V1::Client::PasswordsController < ApplicationController
  def update
    contato = Contact.reset_password_by_token(
      reset_password_token: params[:token],
      password: params[:password],
      password_confirmation: params[:password_confirmation]
    )

    return render_invalid_token if contato.id.blank?
    return render_errors(contato) if contato.errors.any?

    # O acesso pode ter sido desligado depois de o e-mail sair. A senha ja foi
    # gravada pelo Devise - nao e credencial invalida, e a porta que fechou.
    return render_access_revoked unless contato.client_access?

    # Redefinir derruba a sessao aberta: quem chega aqui esqueceu a senha ou
    # desconfia que alguem a tem, e nos dois casos uma sessao viva em outro
    # lugar deve cair.
    contato.revoke_client_sessions!

    render json: { message: I18n.t('client_area.password.updated') }
  end

  private

  # Token errado e token vencido dao a MESMA resposta: separar os dois diria a
  # quem tentar adivinhar que chegou perto.
  def render_invalid_token
    render json: { error: I18n.t('client_area.password.invalid_token') },
           status: :unprocessable_entity
  end

  def render_errors(contato)
    render json: { error: contato.errors.full_messages.to_sentence },
           status: :unprocessable_entity
  end

  def render_access_revoked
    render json: { error: I18n.t('client_area.unauthorized') },
           status: :unauthorized
  end
end
