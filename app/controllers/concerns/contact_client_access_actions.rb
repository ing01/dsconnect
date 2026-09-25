# A acao que liga e desliga o acesso do contato a Area do Cliente.
#
# Num concern, e nao no corpo do ContactsController, pelo mesmo motivo que
# TicketImpedimentActions existe: aquele controller ja esta no limite de
# tamanho, e a funcionalidade e recortavel.
#
# O `before_action :fetch_contact` NAO e declarado aqui de proposito - o Rails
# deduplica callbacks pelo nome do filtro, e uma segunda declaracao substituiria
# a do controller. A acao entra na lista de la.
module ContactClientAccessActions
  extend ActiveSupport::Concern

  # O acesso e um atributo do cadastro do contato: ligar, desligar, definir a
  # credencial e ate onde ele enxerga.
  def client_access
    if ActiveModel::Type::Boolean.new.cast(params[:enabled])
      @contact.client_tickets_visibility = params[:tickets_visibility] if params[:tickets_visibility].present?
      @contact.enable_client_access!(password: params[:password])
    else
      @contact.disable_client_access!
    end

    render 'show'
  end
end
