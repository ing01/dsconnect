# Indicadores do Painel Comercial - mesmas visoes do painel standalone antigo
# (ver Painel_Comercial_Duesoft_Documentacao_Tecnica.md): cartoes de KPI,
# tendencia mensal, ranking de vendedor/produto/canal. O grafico de tendencia
# e os periodos disponiveis sempre olham TODO o historico (igual ao painel
# antigo); so os KPIs e os rankings respeitam o filtro de periodo.
class Api::V1::Accounts::Crm::DashboardController < Api::V1::Accounts::BaseController
  before_action :check_authorization

  def show
    @period = params[:period].presence || 'all'
    all_sales = Current.account.crm_sales.includes(:client, :seller, :items)
    filtered_sales = filter_by_period(all_sales).to_a

    @kpis = build_kpis(filtered_sales)
    @trend = build_trend(all_sales.to_a)
    @seller_ranking = build_seller_ranking(filtered_sales)
    @product_ranking = build_product_ranking(filtered_sales)
    @channel_ranking = build_channel_ranking(filtered_sales)
    @periods = available_periods(all_sales.to_a)
  end

  private

  def check_authorization
    authorize ::Crm::Sale, :index?
  end

  def filter_by_period(scope)
    case @period
    when /\Ayear:(\d{4})\z/
      year = Regexp.last_match(1).to_i
      scope.where(competencia: Date.new(year, 1, 1)..Date.new(year, 12, 31))
    when /\Amonth:(\d{4})-(\d{2})\z/
      year = Regexp.last_match(1).to_i
      month = Regexp.last_match(2).to_i
      start_date = Date.new(year, month, 1)
      scope.where(competencia: start_date..start_date.end_of_month)
    else
      scope
    end
  end

  def build_kpis(sales)
    total_implementation = sales.sum { |s| s.implementation_value.to_f }
    {
      total_implementation: total_implementation,
      total_monthly: sales.sum { |s| s.monthly_value.to_f },
      sales_count: sales.size,
      unique_clients: sales.map(&:crm_client_id).uniq.size,
      avg_implementation_ticket: sales.empty? ? 0 : (total_implementation / sales.size),
    }
  end

  def build_trend(sales)
    sales.group_by { |s| s.competencia.strftime('%Y-%m') }.map do |month, month_sales|
      {
        month: month,
        implementation_value: month_sales.sum { |s| s.implementation_value.to_f },
        monthly_value: month_sales.sum { |s| s.monthly_value.to_f },
      }
    end.sort_by { |h| h[:month] }
  end

  def build_seller_ranking(sales)
    sales.group_by(&:user_id).map do |_user_id, seller_sales|
      seller = seller_sales.first.seller
      {
        name: seller&.name || I18n.t('crm.dashboard.unassigned_seller'),
        implementation_value: seller_sales.sum { |s| s.implementation_value.to_f },
        monthly_value: seller_sales.sum { |s| s.monthly_value.to_f },
        sales_count: seller_sales.size,
      }
    end.sort_by { |h| -h[:monthly_value] }
  end

  def build_product_ranking(sales)
    items = sales.flat_map(&:items)
    items.group_by(&:product).map do |product, product_items|
      {
        product: product,
        implementation_value: product_items.sum { |i| i.implementation_value.to_f },
        monthly_value: product_items.sum { |i| i.monthly_value.to_f },
      }
    end.sort_by { |h| -h[:monthly_value] }.first(8)
  end

  def build_channel_ranking(sales)
    sales.group_by { |s| s.channel.presence || I18n.t('crm.dashboard.no_channel') }.map do |channel, channel_sales|
      {
        channel: channel,
        monthly_value: channel_sales.sum { |s| s.monthly_value.to_f },
        unique_clients: channel_sales.map(&:crm_client_id).uniq.size,
        sales_count: channel_sales.size,
      }
    end.sort_by { |h| -h[:monthly_value] }
  end

  def available_periods(sales)
    dates = sales.map(&:competencia).compact
    {
      years: dates.map(&:year).uniq.sort.reverse,
      months: dates.map { |d| d.strftime('%Y-%m') }.uniq.sort.reverse,
    }
  end
end
