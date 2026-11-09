# frozen_string_literal: true

require 'rails_helper'

# Um bloco colado na coluna 0 (sem indentacao) vira uma NOVA raiz do YAML: tudo o que vem depois
# dele sai de baixo de `pt_BR:`/`en:` e as telas passam a mostrar "Translation missing: ...".
# Aconteceu com `tickets.bulk` (notificacoes e textos de atividade da conversa sumiram).
RSpec.describe 'config/locales/*.yml' do
  Rails.root.glob('config/locales/*.yml').each do |path|
    it "#{path.basename} tem uma unica raiz (o codigo do idioma)" do
      raiz = YAML.load_file(path).keys

      expect(raiz.size).to eq(1), "raizes encontradas: #{raiz.inspect}"
    end
  end

  %w[en pt_BR].each do |locale|
    it "#{locale}: as chaves que ficavam abaixo do bloco quebrado existem" do
      I18n.with_locale(locale) do
        expect(I18n.exists?('notifications.notification_title.conversation_creation')).to be(true)
        expect(I18n.exists?('conversations.activity.assignee.assigned')).to be(true)
        expect(I18n.exists?('tickets.bulk.reasons.not_found')).to be(true)
      end
    end
  end
end
