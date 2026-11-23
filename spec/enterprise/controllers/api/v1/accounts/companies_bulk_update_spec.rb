require 'rails_helper'

RSpec.describe 'Companies bulk update', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:niche) { account.company_niches.create!(name: 'Varejo') }
  let(:sub_niche) { account.company_sub_niches.create!(name: 'Moda') }
  let(:system_module) { account.system_modules.create!(name: 'Fiscal') }
  let(:other_module) { account.system_modules.create!(name: 'Estoque') }
  let!(:first) { create(:company, account: account) }
  let!(:second) { create(:company, account: account) }
  let!(:third) { create(:company, account: account) }
  let(:url) { "/api/v1/accounts/#{account.id}/companies/bulk_update" }

  before { account.enable_features!(:companies) }

  def bulk(params, user = admin)
    post url, params: params, headers: user.create_new_auth_token, as: :json
  end

  it 'starts every company as active' do
    expect(first.reload.status).to eq('active')
  end

  it 'changes niche, sub niche, level, specialist and status of the selected companies only' do
    bulk(ids: [first.id, second.id],
         changes: { company_niche_id: niche.id, company_sub_niche_id: sub_niche.id,
                    classification_level: 3, specialist_id: admin.id, status: 'inactive' })

    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to include('updated' => 2, 'failed' => [])
    [first, second].each do |company|
      company.reload
      expect(company).to have_attributes(company_niche_id: niche.id, company_sub_niche_id: sub_niche.id,
                                         classification_level: 3, specialist_id: admin.id, status: 'inactive')
    end
    expect(third.reload).to have_attributes(company_niche_id: nil, status: 'active')
  end

  it 'clears a field sent empty and leaves absent fields alone' do
    first.update!(company_niche: niche, classification_level: 2)

    bulk(ids: [first.id], changes: { classification_level: '' })

    expect(first.reload).to have_attributes(classification_level: nil, company_niche_id: niche.id)
  end

  it 'applies to every company found by the filter with select_all' do
    first.update!(company_niche: niche)
    second.update!(company_niche: niche)

    bulk(select_all: true, company_niche_id: niche.id, changes: { status: 'inactive' })

    expect(response.parsed_body['updated']).to eq(2)
    expect(third.reload.status).to eq('active')
  end

  describe 'modules' do
    before { first.update!(system_modules: [system_module]) }

    it 'adds without dropping the ones already there' do
      bulk(ids: [first.id], changes: { system_module_ids: [other_module.id], modules_mode: 'add' })

      expect(first.reload.system_module_ids).to contain_exactly(system_module.id, other_module.id)
    end

    it 'removes only the chosen ones' do
      first.update!(system_modules: [system_module, other_module])

      bulk(ids: [first.id], changes: { system_module_ids: [other_module.id], modules_mode: 'remove' })

      expect(first.reload.system_module_ids).to eq([system_module.id])
    end

    it 'replaces the whole list' do
      bulk(ids: [first.id], changes: { system_module_ids: [other_module.id], modules_mode: 'replace' })

      expect(first.reload.system_module_ids).to eq([other_module.id])
    end

    it 'refuses a module from another account' do
      foreign = create(:account).system_modules.create!(name: 'Alheio')

      bulk(ids: [first.id], changes: { system_module_ids: [foreign.id] })

      expect(response).to have_http_status(:unprocessable_entity)
      expect(first.reload.system_module_ids).to eq([system_module.id])
    end
  end

  it 'changes the billing type for an administrator' do
    bulk(ids: [first.id], changes: { billing_type: 'annual' })

    expect(first.reload.billing_type).to eq('annual')
  end

  it 'refuses an invalid status and changes nothing' do
    bulk(ids: [first.id], changes: { status: 'banana' })

    expect(response).to have_http_status(:unprocessable_entity)
    expect(first.reload.status).to eq('active')
  end

  it 'refuses a niche from another account' do
    foreign = create(:account).company_niches.create!(name: 'Alheio')

    bulk(ids: [first.id], changes: { company_niche_id: foreign.id })

    expect(response).to have_http_status(:unprocessable_entity)
  end

  it 'asks for at least one change and one target' do
    bulk(ids: [first.id], changes: {})
    expect(response).to have_http_status(:unprocessable_entity)

    bulk(changes: { status: 'inactive' })
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it 'is restricted to administrators' do
    bulk({ ids: [first.id], changes: { status: 'inactive' } }, agent)

    expect(response).to have_http_status(:unauthorized)
    expect(first.reload.status).to eq('active')
  end

  it 'filters the list by status' do
    second.update!(status: 'inactive')

    get "/api/v1/accounts/#{account.id}/companies",
        params: { status: 'inactive' }, headers: admin.create_new_auth_token, as: :json

    expect(response.parsed_body['payload'].pluck('id')).to eq([second.id])
  end
end
