require 'rails_helper'

RSpec.describe V2::Reports::Implementation::PeriodComparisonBuilder do
  it 'computes delta/direction per numeric key' do
    result = described_class.new(
      current: { total_hours: 10, projects_count: 2 },
      previous: { total_hours: 6, projects_count: 2 }
    ).build

    expect(result[:total_hours]).to eq(value: 10, previous_value: 6, delta: 4, direction: 'up')
    expect(result[:projects_count]).to eq(value: 2, previous_value: 2, delta: 0, direction: 'flat')
  end

  it 'is flat/nil-delta when a value is missing from the previous period' do
    result = described_class.new(current: { total_hours: 10 }, previous: {}).build

    expect(result[:total_hours]).to eq(value: 10, previous_value: nil, delta: nil, direction: 'flat')
  end
end
