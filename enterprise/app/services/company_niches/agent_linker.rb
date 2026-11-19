# Vincula os analistas aos Nichos e Sub-nichos de empresa que atendem, e cadastra os que ainda nao
# existem (com o nome exato da lista). Idempotente: rodar de novo nao duplica nada, so' completa.
#
# Agente e nicho sao achados pelo nome SEM diferenciar maiuscula nem acento. Um agente que nao e'
# achado (ou que tem mais de um com o mesmo nome) e' pulado e fica no relatorio: nada e' chutado.
# Numa conta em que nenhum dos analistas existe, nao cria nem vincula nada.
class CompanyNiches::AgentLinker
  LINKS = {
    'Guilherme Vasconcelos' => {
      niches: ['Materiais de construção', 'Engenharia / Construção / Ferragens', 'Agropecuária'],
      sub_niches: ['Loja de tintas', 'Material de construção', 'Construção civil', 'Madeireira', 'Engenharia',
                   'Indústria de ferragens', 'Construção', 'Indústria de construção', 'Esquadrias', 'Indústria de fivelas',
                   'Terraplanagem', 'Produtos agropecuários', 'Sementes / ração', 'Usina', 'Cooperativa / associação']
    },
    'Ingrid' => {
      niches: ['Autopeças / Oficinas / Serviços automotivos', 'Conveniência e Mercado', 'Variedades'],
      sub_niches: ['Autopeças', 'Oficina', 'Retífica', 'Conveniência', 'Mercado', 'Varejo piscinas',
                   'Varejo produtos naturais', 'Varejo água / gás', 'Varejo sacolão', 'Variedades']
    },
    'João Vitor' => {
      niches: ['Indústria de alimentos', 'Frigorífico / Laticínio', 'Alimentação / restaurante / sorveteria'],
      sub_niches: ['Indústria de alimentos', 'Distribuidora de alimentos', 'Frigorífico', 'Laticínio', 'Restaurante',
                   'Sorveteria', 'Padaria / panificadora', 'Hamburgueria']
    },
    'Lucas Oliveira' => {
      niches: ['Material elétrico / energia solar', 'Papelaria / Embalagens', 'Móveis / Incorporadora',
               'Ferramentas / metalurgia', 'Beleza / cosméticos', 'Indústria farmacêutica'],
      sub_niches: ['Material elétrico', 'Energia solar', 'Papelaria', 'Embalagens', 'Livraria', 'Informática',
                   'Móveis e decoração', 'Incorporadora', 'Ferramentas', 'Extintores', 'Produtos de beleza e cosméticos',
                   'Distribuidora de cabelos e tapetes', 'Indústria farmacêutica', 'Produtos odontológicos',
                   'Distribuidora de produtos farmacêuticos']
    },
    'Ludmila' => {
      niches: ['Vestuário / calçados / semijoias', 'Serviços / outros', 'Pet / produtos agropecuários', 'Gestão de fazendas',
               'Transportes / logística', 'Produtos de limpeza', 'Floricultura', 'Indústria de eletrônicos', 'Facilities'],
      sub_niches: ['Vestuário', 'Calçados', 'Semijoias', 'Serviços diversos', 'Facilities', 'Saúde (clínicas, hospital, ótica)',
                   'Paisagismo / jardinagem', 'Dedetização', 'Informática', 'Segurança eletrônica', 'Distribuidora de tabaco',
                   'Educação', 'Ponto eletrônico', 'Revenda de veículos', 'Chaves', 'Pet / produtos agropecuários',
                   'Gestão de fazendas', 'Transportes / logística', 'Produtos de limpeza', 'Floricultura',
                   'Indústria de eletrônicos', 'Construção civil']
    }
  }.freeze

  Report = Struct.new(:linked_agents, :missing_agents, :created_niches, :created_sub_niches, :links, keyword_init: true)

  def initialize(account, links: LINKS)
    @account = account
    @links = links
  end

  def perform
    report = Report.new(linked_agents: [], missing_agents: [], created_niches: 0, created_sub_niches: 0, links: 0)
    found = @links.filter_map do |agent_name, lists|
      user = find_user(agent_name)
      if user.nil?
        report.missing_agents << agent_name
        next
      end

      [user, lists]
    end

    # Ponto de salvamento proprio: se algo falhar, so' este passo volta (a migration que o chama
    # continua viva para registrar o aviso, em vez de derrubar o deploy).
    ActiveRecord::Base.transaction(requires_new: true) do
      found.each { |user, lists| link(user, lists, report) }
    end
    report
  end

  private

  def link(user, lists, report)
    lists[:niches].each do |name|
      niche = niche_named(name, report)
      report.links += 1 if UserCompanyNiche.find_or_create_by!(account: @account, user: user, company_niche: niche).previously_new_record?
    end
    lists[:sub_niches].each do |name|
      sub = sub_niche_named(name, report)
      report.links += 1 if UserCompanySubNiche.find_or_create_by!(account: @account, user: user, company_sub_niche: sub).previously_new_record?
    end
    report.linked_agents << user.name
  end

  def niche_named(name, report)
    @niches ||= @account.company_niches.index_by { |niche| normalize(niche.name) }
    @niches[normalize(name)] ||= @account.company_niches.create!(name: name).tap { report.created_niches += 1 }
  end

  def sub_niche_named(name, report)
    @sub_niches ||= @account.company_sub_niches.index_by { |sub| normalize(sub.name) }
    @sub_niches[normalize(name)] ||= @account.company_sub_niches.create!(name: name).tap { report.created_sub_niches += 1 }
  end

  def find_user(name)
    matches = @account.users.select { |user| normalize(user.name) == normalize(name) }
    matches.one? ? matches.first : nil
  end

  def normalize(text)
    I18n.transliterate(text.to_s).downcase.gsub(/\s+/, ' ').strip
  end
end
