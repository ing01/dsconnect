# Aplica a identidade visual do `config/installation_config.yml` num banco que
# ja existe.
#
# O arquivo so e lido para a tabela `installation_configs` na primeira carga; a
# partir dai o produto le do banco, e o ConfigLoader roda com
# `reconcile_only_new: true`, que cria o que falta mas nunca sobrescreve o que
# ja esta la. Entao trocar o nome e as imagens no arquivo nao muda nada numa
# instalacao em uso - e o que fez a marca parecer perdida.
#
# Sincroniza apenas as chaves de marca, de proposito: recarregar tudo com
# `reconcile_only_new: false` sobrescreveria qualquer outra configuracao ja
# ajustada nesta instalacao.
#
#   bundle exec rake duedesk:branding
#   bundle exec rake duedesk:branding DRY_RUN=1
BRANDING_KEYS = %w[
  INSTALLATION_NAME
  BRAND_NAME
  BRAND_URL
  WIDGET_BRAND_URL
  LOGO
  LOGO_DARK
  LOGO_THUMBNAIL
].freeze

# Aplica uma chave, devolvendo se ela mudou de fato.
def sync_branding_key(key, wanted, dry_run)
  config = InstallationConfig.find_or_initialize_by(name: key)
  if config.value == wanted
    puts "  #{key}: ja esta como #{wanted.inspect}"
    return false
  end

  puts "  #{key}: #{config.value.inspect} -> #{wanted.inspect}"
  return true if dry_run

  config.value = wanted
  config.save!
  true
end

namespace :duedesk do
  desc 'Aplica nome e imagens do installation_config.yml no banco'
  task branding: :environment do
    dry_run = ENV['DRY_RUN'].present?
    defaults = ConfigLoader.new.general_configs.index_by { |config| config['name'] }

    changed = BRANDING_KEYS.count do |key|
      wanted = defaults.dig(key, 'value')
      wanted.nil? ? false : sync_branding_key(key, wanted, dry_run)
    end

    if dry_run
      puts "#{changed} chave(s) mudariam. Nada gravado."
      next
    end

    # O produto guarda estes valores em cache; sem limpar, a tela continuaria
    # mostrando a marca antiga ate o proximo reinicio.
    GlobalConfig.clear_cache
    puts "#{changed} chave(s) atualizada(s). Recarregue a pagina."
  end
end
