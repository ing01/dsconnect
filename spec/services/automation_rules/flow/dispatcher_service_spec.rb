require 'rails_helper'

RSpec.describe AutomationRules::Flow::DispatcherService do
  let(:account) { create(:account) }
  let(:conversation) { create(:conversation, account: account) }
  let(:automation_rule) { create(:automation_rule, account: account, flow_steps: []) }

  describe '.start' do
    it 'starts a flow run for a conversation that came in by itself' do
      result = described_class.start(rule: automation_rule, conversation: conversation)

      expect(result).to be(true)
      expect(AutomationFlowRun.exists?(automation_rule_id: automation_rule.id, conversation_id: conversation.id)).to be(true)
    end

    it 'does not start a flow run for a conversation the agent started via "Nova Conversa"' do
      conversation.additional_attributes['agent_initiated'] = true
      conversation.save!

      result = described_class.start(rule: automation_rule, conversation: conversation)

      expect(result).to be(false)
      expect(AutomationFlowRun.exists?(automation_rule_id: automation_rule.id, conversation_id: conversation.id)).to be(false)
    end
  end

  describe '.resume' do
    let(:run) do
      create(:automation_flow_run, account: account, automation_rule: automation_rule, conversation: conversation,
                                    status: :waiting, waiting_until: 1.hour.from_now)
    end

    it 'resumes a waiting run for an ordinary incoming message' do
      run
      message = create(:message, conversation: conversation, account: account, message_type: :incoming)

      expect(described_class.resume(message: message)).to be(true)
      expect(run.reload.status).not_to eq('waiting')
    end

    it 'does not resume a waiting run once the agent has taken over via "Nova Conversa"' do
      run
      conversation.additional_attributes['agent_initiated'] = true
      conversation.save!
      message = create(:message, conversation: conversation, account: account, message_type: :incoming)

      expect(described_class.resume(message: message)).to be(false)
      expect(run.reload.status).to eq('waiting')
    end
  end
end
