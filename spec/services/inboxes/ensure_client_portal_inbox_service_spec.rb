# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Inboxes::EnsureClientPortalInboxService do
  let(:account) { create(:account) }

  def perform
    described_class.new(account: account).perform
  end

  it 'cria a caixa do Portal com a atribuicao automatica desligada' do
    inbox = perform

    expect(inbox.enable_auto_assignment).to be(false)
    expect(inbox.lock_to_single_conversation).to be(false)
    expect(inbox.csat_survey_enabled).to be(true)
  end

  it 'nao liga sozinha a atribuicao automatica que um admin ativou na caixa' do
    inbox = perform
    inbox.update!(enable_auto_assignment: true)

    expect(perform.reload.enable_auto_assignment).to be(true)
  end

  # O defeito: quem desligava "Ativar atribuicao automatica de conversas" na caixa via o botao
  # religar sozinho na proxima vez que um cliente abria o chat (ou um atendente, "Abrir conversa").
  it 'nao religa a atribuicao automatica que alguem desligou na caixa' do
    inbox = perform
    inbox.update!(enable_auto_assignment: false)

    expect(perform.reload.enable_auto_assignment).to be(false)
  end

  it 'continua reforcando o que o historico de conversas e o CSAT exigem' do
    inbox = perform
    inbox.update!(lock_to_single_conversation: true, csat_survey_enabled: false, enable_auto_assignment: false)

    refreshed = perform.reload

    expect(refreshed.lock_to_single_conversation).to be(false)
    expect(refreshed.csat_survey_enabled).to be(true)
    expect(refreshed.enable_auto_assignment).to be(false)
  end

  it 'nao cria uma segunda caixa na segunda chamada' do
    first = perform

    expect { perform }.not_to change(account.inboxes, :count)
    expect(perform.id).to eq(first.id)
  end
end
