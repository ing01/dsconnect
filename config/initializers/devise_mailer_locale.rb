# O Devise::Mailer manda a recuperacao de senha, a confirmacao e o desbloqueio.
#
# Ele nao tem conta no contexto (`params: {account: nil}`), entao o
# `switch_locale` do ApplicationMailer caia em `I18n.default_locale`, que e
# `en` - e o e-mail chegava em ingles mesmo com a conta em portugues.
#
# `to_prepare` porque em desenvolvimento as classes sao recarregadas: incluir
# uma unica vez no boot perderia o efeito no primeiro reload.
Rails.application.config.to_prepare do
  Devise::Mailer.include(ForcedPortugueseLocale)
end
