json.payload @attendance_windows do |window|
  json.id window.id
  json.day_of_week window.day_of_week
  json.start_minute window.start_minute
  json.end_minute window.end_minute
end
