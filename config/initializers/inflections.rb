# Be sure to restart your server when you modify this file.

# Add new inflection rules using the following format. Inflections
# are locale specific, and you may define rules for as many different
# locales as you wish. All of these examples are active by default:
# ActiveSupport::Inflector.inflections(:en) do |inflect|
#   inflect.plural /^(ox)$/i, '\1en'
#   inflect.singular /^(ox)en/i, '\1'
#   inflect.irregular 'person', 'people'
#   inflect.uncountable %w( fish sheep )
# end

# These inflection rules are supported but not enabled by default:
# ActiveSupport::Inflector.inflections(:en) do |inflect|
#   inflect.acronym 'RESTful'
# end

# A regra generica do Rails pra plural -> singular em "...ches" assume que o
# "ch" faz parte do radical (ex.: "watches" -> "watch", certo), mas "niche"
# termina em "che" - a mesma regra devolve "nich" (errado) em vez de "niche".
# Isso quebrava `controller_name.classify` em
# `Api::BaseController#check_authorization` pros controllers
# CompanyNichesController/CompanySubNichesController (NameError: uninitialized
# constant CompanyNich), deixando o seletor de Nicho/Subnicho sempre vazio -
# achado ao investigar por que o Nicho importado nao aparecia (2026-11-18).
ActiveSupport::Inflector.inflections(:en) do |inflect|
  inflect.irregular 'niche', 'niches'
end
