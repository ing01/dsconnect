require 'rails_helper'

# O agente avalia uma resposta do DueBot (polegar para cima/baixo). Fica guardada no
# banco, com uma copia da pergunta e da resposta, para analisar e melhorar a IA.
RSpec.describe 'Api::V1::Accounts::Captain::CopilotMessageFeedbacksController', type: :request do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account, role: :agent) }
  let(:copilot_thread) { create(:captain_copilot_thread, account: account, user: user) }
  let!(:question) do
    create(:captain_copilot_message, copilot_thread: copilot_thread, account: account,
                                     message: { content: 'Como emitir uma NF-e?' }, message_type: :user)
  end
  let!(:answer) do
    create(:captain_copilot_message, copilot_thread: copilot_thread, account: account,
                                     message: { content: 'Va em Fiscal > Emissao.' }, message_type: :assistant)
  end

  def feedback_url(message = answer, thread = copilot_thread)
    "/api/v1/accounts/#{account.id}/captain/copilot_threads/#{thread.id}/copilot_messages/#{message.id}/feedback"
  end

  describe 'POST feedback' do
    it 'saves a positive rating with a copy of the question and the answer' do
      expect do
        post feedback_url, params: { rating: 'positive' }, headers: user.create_new_auth_token, as: :json
      end.to change(CopilotMessageFeedback, :count).by(1)

      expect(response).to have_http_status(:success)
      saved = CopilotMessageFeedback.last
      expect(saved).to have_attributes(
        user_id: user.id, account_id: account.id, copilot_message_id: answer.id, rating: 'positive',
        question: 'Como emitir uma NF-e?', answer: 'Va em Fiscal > Emissao.', assistant_id: copilot_thread.assistant_id
      )
      expect(response.parsed_body['feedback']).to include('rating' => 'positive')
    end

    it 'saves the reason and the comment of a negative rating' do
      post feedback_url, params: { rating: 'negative', reason: 'wrong_answer', comment: 'O menu e outro.' },
                         headers: user.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(CopilotMessageFeedback.last).to have_attributes(rating: 'negative', reason: 'wrong_answer', comment: 'O menu e outro.')
      expect(response.parsed_body['feedback']).to include('reason' => 'wrong_answer', 'comment' => 'O menu e outro.')
    end

    it 'keeps where the chat was opened' do
      copilot_thread.update!(conversation_display_id: 77, screen: 'tickets_index')

      post feedback_url, params: { rating: 'positive' }, headers: user.create_new_auth_token, as: :json

      expect(CopilotMessageFeedback.last).to have_attributes(conversation_display_id: 77, screen: 'tickets_index')
    end

    it 'updates the previous rating instead of creating another one' do
      post feedback_url, params: { rating: 'positive' }, headers: user.create_new_auth_token, as: :json

      expect do
        post feedback_url, params: { rating: 'negative', reason: 'incomplete' }, headers: user.create_new_auth_token, as: :json
      end.not_to change(CopilotMessageFeedback, :count)

      expect(CopilotMessageFeedback.last).to have_attributes(rating: 'negative', reason: 'incomplete')
    end

    it 'drops the reason of a positive rating' do
      post feedback_url, params: { rating: 'positive', reason: 'wrong_answer' }, headers: user.create_new_auth_token, as: :json

      expect(CopilotMessageFeedback.last.reason).to be_nil
    end

    it 'refuses a reason that is not on the list' do
      post feedback_url, params: { rating: 'negative', reason: 'qualquer coisa' }, headers: user.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(CopilotMessageFeedback.count).to eq(0)
    end

    it 'refuses a rating that is not positive or negative' do
      post feedback_url, params: { rating: 'ótima' }, headers: user.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'refuses a rating on the question of the agent' do
      post feedback_url(question), params: { rating: 'positive' }, headers: user.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(CopilotMessageFeedback.count).to eq(0)
    end

    it 'does not reach the thread of another agent' do
      other = create(:user, account: account, role: :agent)

      post feedback_url, params: { rating: 'positive' }, headers: other.create_new_auth_token, as: :json

      expect(response).to have_http_status(:not_found)
    end

    it 'requires authentication' do
      post feedback_url, params: { rating: 'positive' }, as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'DELETE feedback' do
    it 'removes only the rating of this agent' do
      post feedback_url, params: { rating: 'positive' }, headers: user.create_new_auth_token, as: :json
      other = create(:user, account: account, role: :agent)
      CopilotMessageFeedback.create!(account: account, user: other, copilot_message: answer, rating: :negative, answer: 'x')

      delete feedback_url, headers: user.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['feedback']).to be_nil
      expect(CopilotMessageFeedback.where(user_id: user.id)).to be_empty
      expect(CopilotMessageFeedback.where(user_id: other.id).count).to eq(1)
    end
  end

  describe 'the feedback shown with the messages' do
    it 'comes back in the listing for the agent who rated, and only for that agent' do
      post feedback_url, params: { rating: 'negative', reason: 'outdated' }, headers: user.create_new_auth_token, as: :json

      get "/api/v1/accounts/#{account.id}/captain/copilot_threads/#{copilot_thread.id}/copilot_messages",
          headers: user.create_new_auth_token, as: :json

      by_id = response.parsed_body['payload'].index_by { |item| item['id'] }
      expect(by_id[answer.id]['feedback']).to include('rating' => 'negative', 'reason' => 'outdated')
      expect(by_id[question.id]['feedback']).to be_nil
    end
  end

  describe 'when the conversation with the DueBot is deleted' do
    it 'keeps the feedback, with the copy of the question and the answer' do
      post feedback_url, params: { rating: 'negative', reason: 'wrong_answer' }, headers: user.create_new_auth_token, as: :json

      answer.destroy!

      saved = CopilotMessageFeedback.last
      expect(saved.copilot_message_id).to be_nil
      expect(saved).to have_attributes(question: 'Como emitir uma NF-e?', answer: 'Va em Fiscal > Emissao.')
    end
  end
end
