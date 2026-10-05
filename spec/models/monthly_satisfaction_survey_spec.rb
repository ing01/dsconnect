require 'rails_helper'

# A avaliacao mensal de satisfacao do Portal do Cliente - o lado MODEL: o mes
# de referencia, a trava de uma por contato por mes, e os agregados que a
# area interna vai usar no futuro.
RSpec.describe MonthlySatisfactionSurvey do
  let(:account) { create(:account) }
  let(:empresa) { create(:company, account: account) }
  let(:contato) { create(:contact, account: account, company: empresa) }

  describe '.current_reference_month' do
    it 'is always the first day of the month' do
      travel_to(Date.new(2026, 10, 17)) do
        expect(described_class.current_reference_month).to eq(Date.new(2026, 10, 1))
      end
    end
  end

  describe 'normalizacao do mes de referencia' do
    # Um dia qualquer gravado por engano vira o PRIMEIRO dia do mes - e o
    # que faz o indice unico enxergar "o mesmo mes" independente de QUANDO
    # dentro do mes a pessoa respondeu.
    it 'normalizes any day within the month to the first day' do
      avaliacao = create(:monthly_satisfaction_survey, contact: contato, reference_month: Date.new(2026, 10, 23))

      expect(avaliacao.reference_month).to eq(Date.new(2026, 10, 1))
    end
  end

  describe 'uma por contato por mes' do
    # A trava de verdade e o INDICE UNICO do banco, nao uma validacao de
    # aplicacao (ver o comentario no model) - este exemplo prova que o indice
    # existe e funciona, nao que uma validacao Ruby existe.
    it 'refuses a second survey for the same contact in the same month, at the database level' do
      create(:monthly_satisfaction_survey, account: account, contact: contato,
                                           reference_month: described_class.current_reference_month)

      segunda = build(:monthly_satisfaction_survey, account: account, contact: contato,
                                                    reference_month: described_class.current_reference_month)

      expect { segunda.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it 'allows the same contact to answer again in a different month' do
      create(:monthly_satisfaction_survey, account: account, contact: contato,
                                           reference_month: Date.new(2026, 9, 1))

      outra = build(:monthly_satisfaction_survey, account: account, contact: contato,
                                                  reference_month: Date.new(2026, 10, 1))

      expect { outra.save!(validate: false) }.not_to raise_error
    end

    it 'allows two different contacts to answer in the same month' do
      outro_contato = create(:contact, account: account, company: empresa)
      mes = described_class.current_reference_month
      create(:monthly_satisfaction_survey, account: account, contact: contato, reference_month: mes)

      outra = build(:monthly_satisfaction_survey, account: account, contact: outro_contato, reference_month: mes)

      expect { outra.save!(validate: false) }.not_to raise_error
    end
  end

  describe '.answered_for?' do
    it 'is false when the contact has nothing for that month' do
      expect(described_class.answered_for?(contact: contato)).to be(false)
    end

    it 'is true once the contact has answered that month' do
      create(:monthly_satisfaction_survey, account: account, contact: contato)

      expect(described_class.answered_for?(contact: contato)).to be(true)
    end

    # Respondida em SETEMBRO nao conta como respondida em OUTUBRO.
    it 'does not carry over from a previous month' do
      create(:monthly_satisfaction_survey, account: account, contact: contato, reference_month: Date.new(2026, 9, 1))

      expect(described_class.answered_for?(contact: contato, month: Date.new(2026, 10, 1))).to be(false)
    end

    it 'is false without a contact' do
      expect(described_class.answered_for?(contact: nil)).to be(false)
    end
  end

  describe 'a empresa e preenchida automaticamente' do
    it 'takes the company from the contact who answered' do
      avaliacao = MonthlySatisfactionSurveys::SubmitService.new(
        contact: contato,
        answers: described_class::QUESTION_KEYS.index_with { 4 }
      ).perform

      expect(avaliacao.company_id).to eq(empresa.id)
    end
  end

  describe '#average_rating' do
    it 'averages the ten answers' do
      avaliacao = create(:monthly_satisfaction_survey, account: account, contact: contato)
      avaliacao.answers.each { |resposta| resposta.update!(rating: 1) }
      avaliacao.answers.first.update!(rating: 5)

      # Nove notas 1 e uma nota 5: media = (9*1 + 5) / 10 = 1.4.
      expect(avaliacao.average_rating.round(1)).to eq(1.4)
    end
  end

  describe '.average_by_question' do
    # A base da futura comparacao "pergunta x pergunta": cada pergunta com a
    # sua propria media, dentro do RECORTE passado (aqui, so as avaliacoes
    # desta conta).
    it 'averages each question across every survey in the scope' do
      primeira = create(:monthly_satisfaction_survey, account: account, contact: contato)
      primeira.answers.find_by(question_key: 'erp_overall').update!(rating: 2)

      segundo_contato = create(:contact, account: account, company: empresa)
      segunda = create(:monthly_satisfaction_survey, account: account, contact: segundo_contato)
      segunda.answers.find_by(question_key: 'erp_overall').update!(rating: 4)

      medias = described_class.average_by_question(scope: account.monthly_satisfaction_surveys)

      expect(medias['erp_overall'].to_f).to eq(3.0)
    end
  end

  describe 'excluir a Empresa ou o Contato' do
    # Mesmo acordo que Manifestation tem com os dois: o historico de
    # satisfacao sobrevive, so perde o vinculo.
    it 'keeps the survey when the company is deleted, without the link' do
      avaliacao = create(:monthly_satisfaction_survey, account: account, company: empresa, contact: contato)

      empresa.destroy!

      expect(avaliacao.reload.company_id).to be_nil
    end

    it 'keeps the survey when the contact is deleted, without the link' do
      avaliacao = create(:monthly_satisfaction_survey, account: account, contact: contato)

      contato.destroy!

      expect(avaliacao.reload.contact_id).to be_nil
    end
  end
end
