# O e-mail sai em PORTUGUES, sempre - nem a conta opina.
#
# Vide ClientAreaLocale::LOCALE: uma definicao so, valendo na tela, na resposta
# da API e aqui.
#
# Aplicado classe a classe, e nao no ApplicationMailer, por dois motivos. Os
# mailers herdados do upstream montam parte do conteudo FORA da renderizacao (o
# texto da pesquisa de satisfacao, por exemplo), e fixar o idioma so na hora de
# renderizar produzia mensagem em portugues com trecho em ingles dentro. E o
# idioma da conta e escolha legitima deles.
#
# Quem inclui: os e-mails que sao nossos e vao para o cliente, e o Devise::Mailer
# (recuperacao de senha, confirmacao, desbloqueio) - que nao tem conta nenhuma
# no contexto (`params: {account: nil}`) e por isso caia no ingles da
# instalacao. Era esse o e-mail que chegava em ingles.
module ForcedPortugueseLocale
  extend ActiveSupport::Concern

  private

  def switch_locale(&)
    I18n.with_locale(ClientAreaLocale::LOCALE, &)
  end
end
