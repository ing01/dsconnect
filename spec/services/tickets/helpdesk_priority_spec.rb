require 'rails_helper'

RSpec.describe Tickets::HelpdeskPriority do
  describe '.ticket_priority_for' do
    it 'maps the classified problem to the ticket priority' do
      expect(described_class.ticket_priority_for(problema: 'baixa')).to eq('low')
      expect(described_class.ticket_priority_for(problema: 'media')).to eq('medium')
      expect(described_class.ticket_priority_for(problema: 'alta')).to eq('high')
    end

    it 'falls back to low when there is no classification' do
      expect(described_class.ticket_priority_for).to eq('low')
      expect(described_class.ticket_priority_for(problema: nil)).to eq('low')
    end

    it 'ignores a value that is not one of the three tiers' do
      expect(described_class.ticket_priority_for(problema: 'urgente')).to eq('low')
    end
  end
end
