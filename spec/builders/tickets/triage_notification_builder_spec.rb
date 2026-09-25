require 'rails_helper'

# O aviso de que chegou chamado na Triagem.
#
# Quem tem acesso à tela é quem precisa saber - notificar só alguns seria
# escolher aqui uma regra que a tela não tem.
RSpec.describe Tickets::TriageNotificationBuilder do
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:agente) { create(:user, account: account, role: :agent) }
  let(:team) { create(:team, account: account) }
  let(:column) { create(:ticket_column, team: team, position: 0) }
  let(:empresa) { create(:company, account: account, name: 'ELETROSUL') }

  let(:em_triagem) do
    create(:ticket, account: account, team: team, ticket_column: column,
                    ticket_category: team.ticket_categories.first,
                    company: empresa, pending_triage: true)
  end

  def avisos(user)
    user.notifications.where(notification_type: 'ticket_triage_pending')
  end

  it 'notifies everyone who can work the triage screen' do
    administrator
    agente

    described_class.new(ticket: em_triagem).perform

    expect(avisos(administrator).count).to eq(1)
    expect(avisos(agente).count).to eq(1)
  end

  it 'points the notification at the ticket' do
    administrator

    described_class.new(ticket: em_triagem).perform

    aviso = avisos(administrator).first
    expect(aviso.primary_actor).to eq(em_triagem)
    expect(aviso.account).to eq(account)
  end

  # O aviso é "há algo na fila": repetir enquanto ninguém leu não acrescenta
  # nada e só empilha a bandeja.
  it 'does not repeat while the notification is unread' do
    administrator
    described_class.new(ticket: em_triagem).perform

    expect { described_class.new(ticket: em_triagem).perform }
      .not_to(change { avisos(administrator).count })
  end

  it 'notifies again once the previous one was read' do
    administrator
    described_class.new(ticket: em_triagem).perform
    avisos(administrator).first.update!(read_at: Time.current)

    expect { described_class.new(ticket: em_triagem).perform }
      .to(change { avisos(administrator).count }.by(1))
  end

  # Só o que está na fila: um chamado já aceito não tem o que avisar.
  it 'says nothing for a ticket that is not waiting' do
    administrator
    pronto = create(:ticket, account: account, team: team, ticket_column: column,
                             ticket_category: team.ticket_categories.first)

    described_class.new(ticket: pronto).perform

    expect(avisos(administrator)).to be_empty
  end

  describe 'o texto e o destino' do
    it 'names the company and the ticket, and points at the queue' do
      administrator
      described_class.new(ticket: em_triagem).perform
      aviso = avisos(administrator).first

      expect(aviso.push_message_title).to include('ELETROSUL', em_triagem.display_id.to_s)
      expect(aviso.push_target_path).to eq("/app/accounts/#{account.id}/tickets/triage")
    end

    # Agrupado pela TELA: num dia movimentado, um card por chamado empilharia a
    # bandeja do sistema operacional.
    it 'groups every triage notice under one tag' do
      administrator
      described_class.new(ticket: em_triagem).perform

      expect(avisos(administrator).first.push_group_tag).to eq('ticket_triage')
    end
  end

  # O gatilho: abrir um chamado em triagem enfileira o aviso sozinho.
  it 'is enqueued when a ticket is created waiting for triage' do
    expect do
      create(:ticket, account: account, team: team, ticket_column: column,
                      ticket_category: team.ticket_categories.first, pending_triage: true)
    end.to have_enqueued_job(Tickets::TriageNotificationJob)
  end

  it 'is not enqueued for a ticket opened by an agent' do
    expect do
      create(:ticket, account: account, team: team, ticket_column: column,
                      ticket_category: team.ticket_categories.first)
    end.not_to have_enqueued_job(Tickets::TriageNotificationJob)
  end
end
