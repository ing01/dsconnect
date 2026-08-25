json.payload do
  json.array! @ticket_followers do |follower|
    json.partial! 'api/v1/models/ticket_follower', formats: [:json], resource: follower
  end
end
