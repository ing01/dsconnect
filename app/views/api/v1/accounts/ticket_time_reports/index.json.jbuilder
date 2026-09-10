json.totals do
  json.hours @report[:totals][:hours]
  json.entries @report[:totals][:entries]
end

json.by_level @report[:by_level] do |row|
  json.level row[:level]
  json.hours row[:hours]
end

json.by_user @report[:by_user] do |row|
  json.user_id row[:user_id]
  json.user_name row[:user_name]
  json.level row[:level]
  json.hours row[:hours]
end
