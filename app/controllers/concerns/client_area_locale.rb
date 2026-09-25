# O idioma das respostas da Area do Cliente.
#
# Sem isto, tudo que o servidor devolve sai no idioma padrao da instalacao - e o
# cliente lia "Invalid e-mail or password.".
#
# Reaproveita o SwitchLocale que o resto do sistema usa: `set_locale` valida o
# idioma e envolve a acao em `I18n.with_locale`, que e o que impede o idioma de
# um pedido vazar para o seguinte.
module ClientAreaLocale
  extend ActiveSupport::Concern
  include SwitchLocale

  # Portugues, SEMPRE.
  #
  # Regra absoluta, e nao um padrao: a conta nao opina, `DEFAULT_LOCALE` da
  # instalacao nao opina, o navegador de quem acessa nao opina. O produto e
  # brasileiro e atende clientes brasileiros, e o ingles reaparecia justamente
  # por esses caminhos indiretos - `I18n.default_locale` e `en`, e a conta nasce
  # em `en` no Chatwoot.
  #
  # Esta e a UNICA definicao: a mesma constante vale na resposta da API
  # (aqui), no e-mail (`ClientFacingLocale`) e na tela (`clientLocale` em
  # helper/clientSession.js). Um segundo valor escrito em outro lugar e como as
  # tres pontas voltam a discordar.
  LOCALE = 'pt_BR'.freeze

  included do
    # Declarado ANTES da autenticacao de proposito: a recusa por token invalido
    # ou acesso desligado e renderizada la dentro, e precisa sair traduzida
    # tambem.
    around_action :switch_client_locale
  end

  private

  def switch_client_locale(&)
    set_locale(LOCALE, &)
  end
end
