require 'rails_helper'

RSpec.describe Tickets::HelpdeskPriority do
  describe '.ticket_priority_for' do
    it 'usa so o nivel do cliente quando a IA nao classificou nada' do
      expect(described_class.ticket_priority_for(client_level: 1)).to eq('low')
      expect(described_class.ticket_priority_for(client_level: 2)).to eq('medium')
      expect(described_class.ticket_priority_for(client_level: 3)).to eq('high')
    end

    it 'nunca deixa a prioridade cair abaixo do que o nivel do cliente ja garante' do
      # Empresa de nivel alto (3) com um problema que a IA classificou como
      # baixa - o piso do nivel prevalece.
      expect(described_class.ticket_priority_for(client_level: 3, problema: 'baixa')).to eq('high')
    end

    it 'deixa a IA subir a prioridade acima do piso do nivel do cliente' do
      # Empresa de nivel baixo (1) com um problema que a IA classificou como
      # alta - a IA prevalece, porque e maior que o piso.
      expect(described_class.ticket_priority_for(client_level: 1, problema: 'alta')).to eq('high')
    end

    it 'usa a classificacao da IA quando ela e igual ao nivel do cliente' do
      expect(described_class.ticket_priority_for(client_level: 2, problema: 'media')).to eq('medium')
    end

    it 'trata nivel desconhecido como baixa' do
      expect(described_class.ticket_priority_for(client_level: 99)).to eq('low')
    end
  end
end
