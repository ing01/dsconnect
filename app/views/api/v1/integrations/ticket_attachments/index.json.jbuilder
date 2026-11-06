json.array! @ticket_attachments do |attachment|
  json.partial! 'attachment', attachment: attachment
end
