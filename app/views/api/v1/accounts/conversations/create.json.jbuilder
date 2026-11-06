json.partial! 'api/v1/conversations/partials/conversation', formats: [:json], conversation: @conversation
json.pulled_from_queue @pulled_from_queue || false
