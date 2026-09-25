require 'rails_helper'

# A triagem: o chamado aberto pelo cliente nao entra no Kanban sozinho.
#
# Quem abre pela Area do Cliente informa o problema; para onde o chamado vai e
# decisao de quem atende, e e isso que estes exemplos fixam.
RSpec.describe 'Ticket triage', type: :request do
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:team) { create(:team, account: account) }
  let(:column) { create(:ticket_column, team: team, position: 0) }
  let(:categoria) { team.ticket_categories.first }

  let(:outra_mesa) { create(:team, account: account) }
  let(:outra_coluna) { create(:ticket_column, team: outra_mesa, position: 0) }

  let(:em_triagem) do
    create(:ticket, account: account, team: team, ticket_column: column,
                    ticket_category: categoria, title: 'Aberto pelo cliente',
                    pending_triage: true)
  end

  def aprovar(ticket, params, user: administrator)
    patch "/api/v1/accounts/#{account.id}/tickets/#{ticket.id}/approve_triage",
          params: params, headers: user.create_new_auth_token, as: :json
  end

  describe 'a fila' do
    it 'lists only what is waiting' do
      em_triagem
      pronto = create(:ticket, account: account, team: team, ticket_column: column,
                               ticket_category: categoria, title: 'Ja triado')

      get "/api/v1/accounts/#{account.id}/tickets?pending_triage=true",
          headers: administrator.create_new_auth_token, as: :json

      ids = response.parsed_body['payload'].map { |t| t['id'] }
      expect(ids).to include(em_triagem.id)
      expect(ids).not_to include(pronto.id)
    end

    # `false` explicito tem de valer: `false.blank?` e true no Rails, e uma
    # checagem ingenua ignoraria o filtro.
    it 'honours an explicit false' do
      em_triagem
      pronto = create(:ticket, account: account, team: team, ticket_column: column,
                               ticket_category: categoria, title: 'Ja triado')

      get "/api/v1/accounts/#{account.id}/tickets?pending_triage=false",
          headers: administrator.create_new_auth_token, as: :json

      ids = response.parsed_body['payload'].map { |t| t['id'] }
      expect(ids).to include(pronto.id)
      expect(ids).not_to include(em_triagem.id)
    end
  end

  describe 'PATCH /approve_triage' do
    it 'accepts the ticket and forwards it to the chosen Mesa and stage' do
      aprovar(em_triagem, { team_id: outra_mesa.id, ticket_column_id: outra_coluna.id })

      expect(response).to have_http_status(:success)
      em_triagem.reload
      expect(em_triagem.pending_triage).to be(false)
      expect(em_triagem.team_id).to eq(outra_mesa.id)
      expect(em_triagem.ticket_column_id).to eq(outra_coluna.id)
      expect(em_triagem.triaged_by).to eq(administrator)
      expect(em_triagem.triaged_at).to be_present
    end

    it 'records who accepted it and where it went' do
      aprovar(em_triagem, { team_id: outra_mesa.id, ticket_column_id: outra_coluna.id })

      # Nao e a ULTIMA: o proprio model registra `team_changed`/`column_changed`
      # num `after_commit`, que roda depois desta - a ordem entre elas e detalhe
      # de implementacao, o que importa e a triagem estar registrada.
      atividade = em_triagem.ticket_activities.find_by(activity_type: :triaged)
      expect(atividade).to be_present
      expect(atividade.user).to eq(administrator)
      expect(atividade.new_value).to include(outra_mesa.name, outra_coluna.name)
    end

    # O Estagio pertence a uma Mesa: aceitar um par impossivel deixaria o
    # chamado num quadro onde a coluna nem existe.
    #
    # A recusa vem como 404, e nao 422, porque a busca do Estagio e feita DENTRO
    # da Mesa escolhida - a mesma guarda que impede usar a coluna de outra conta.
    # O model tambem recusa (ArgumentError), como segunda linha para quem chama
    # direto.
    it 'refuses a stage from another Mesa' do
      aprovar(em_triagem, { team_id: team.id, ticket_column_id: outra_coluna.id })

      expect(response).to have_http_status(:not_found)
      expect(em_triagem.reload.pending_triage).to be(true)
    end

    it 'refuses the mismatch at the model too' do
      expect do
        em_triagem.approve_triage!(user: administrator, team: team, column: outra_coluna)
      end.to raise_error(ArgumentError)
    end

    it 'refuses a ticket that is not waiting for triage' do
      pronto = create(:ticket, account: account, team: team, ticket_column: column,
                               ticket_category: categoria)

      aprovar(pronto, { team_id: team.id, ticket_column_id: column.id })

      expect(response).to have_http_status(:unprocessable_entity)
    end

    # A triagem tambem corrige a classificacao: a Categoria escolhida pelo
    # cliente pode nao ser a da Mesa que vai atender.
    it 'reclassifies when a category is given' do
      nova = outra_mesa.ticket_categories.first

      aprovar(em_triagem, { team_id: outra_mesa.id, ticket_column_id: outra_coluna.id,
                            ticket_category_id: nova.id })

      expect(em_triagem.reload.ticket_category_id).to eq(nova.id)
    end

    it 'brings the ticket into the board once accepted' do
      aprovar(em_triagem, { team_id: outra_mesa.id, ticket_column_id: outra_coluna.id })

      expect(outra_coluna.reload.operational_tickets).to include(em_triagem.reload)
    end
  end
end
