FactoryBot.define do
  factory :manifestation do
    account
    company { create(:company, account: account) }
    contact { create(:contact, account: account, company: company) }
    kind { :suggestion }
    subject_area { :erp }
    status { :received }
    sequence(:title) { |n| "Manifestação #{n}" }
    description { 'Descrição detalhada da manifestação.' }
  end

  factory :manifestation_message do
    manifestation
    account { manifestation.account }
    visibility { :public_reply }
    body { 'Mensagem.' }
    # Autor obrigatorio (ver ManifestationMessage#has_an_author): sem indicar, a
    # mensagem e da equipe.
    user { create(:user, account: manifestation.account, role: :agent) }
  end
end
