summary = lambda do |row|
  json.clocks row[:clocks]
  json.hit row[:hit]
  json.missed row[:missed]
  json.active row[:active]
  json.hit_rate row[:hit_rate]
  json.actual_hours row[:actual_hours]
  json.overrun_hours row[:overrun_hours]
  json.threshold_hours row[:threshold_hours]
end

json.totals { summary.call(@report[:totals]) }

json.by_kind @report[:by_kind] do |row|
  json.kind row[:kind]
  summary.call(row)
end

json.by_user @report[:by_user] do |row|
  json.user_id row[:user_id]
  json.user_name row[:user_name]
  json.kind row[:kind]
  summary.call(row)
end

json.by_company @report[:by_company] do |row|
  json.company_id row[:company_id]
  json.company_name row[:company_name]
  json.kind row[:kind]
  summary.call(row)
end
