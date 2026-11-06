require 'rails_helper'

# Pesquisa por digito: a pesquisa "encerrada" (cliente respondeu sem nota) nao pode
# voltar a contar como pendente. A marca `csat_dismissed` fica em
# `content_attributes`, gravado como TEXTO JSON - por isso e' lida em Ruby, nao por
# `content_attributes ->> 'csat_dismissed'` no SQL (que devolvia sempre NULL).
describe Whatsapp::CsatDigitSurveyService do
  let(:account) { create(:account) }
  let(:conversation) { create(:conversation, account: account) }
  let!(:survey) do
    create(:message, account: account, inbox: conversation.inbox, conversation: conversation,
                     message_type: :outgoing, content_type: :input_csat, content: 'Avalie de 1 a 5')
  end

  describe '#pending_survey_message' do
    it 'devolve a pesquisa ainda sem resposta' do
      expect(described_class.new(conversation: conversation).pending_survey_message).to eq(survey)
    end

    it 'nao devolve a pesquisa ja encerrada (csat_dismissed)' do
      survey.update!(content_attributes: (survey.content_attributes || {}).merge('csat_dismissed' => true))

      expect(described_class.new(conversation: conversation).pending_survey_message).to be_nil
    end

    it 'nao devolve a pesquisa que ja tem resposta' do
      create(:csat_survey_response, account: account, conversation: conversation, message: survey,
                                    contact: conversation.contact, rating: 4)

      expect(described_class.new(conversation: conversation).pending_survey_message).to be_nil
    end
  end
end
