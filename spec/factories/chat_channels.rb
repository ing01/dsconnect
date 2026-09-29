FactoryBot.define do
  factory :chat_channel do
    sequence(:name) { |n| "Canal #{n}" }
    account
    kind { :channel }

    # Conversa entre duas pessoas: nao tem nome, e quem participa e' quem define
    # de quem ela e'.
    factory :chat_direct do
      name { nil }
      kind { :direct }
    end
  end
end
