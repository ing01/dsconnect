require 'rails_helper'

# Quem abre (ou escreve em) uma sala do Chat Interno ja viu as mensagens dela: as
# notificacoes dessas mensagens somem sem precisar abrir cada uma na caixa de
# entrada. So as da SALA e so as do proprio usuario.
describe Notification::MarkInternalChatReadService do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }
  let(:sender) { create(:user, account: account) }
  let(:room) { create(:chat_channel, account: account) }
  let(:other_room) { create(:chat_channel, account: account) }

  def notify(message, to: user)
    create(:notification, account: account, user: to, notification_type: 'internal_chat_message',
                          primary_actor: message, secondary_actor: sender)
  end

  it 'marks as read the notifications of every message in the room' do
    first = notify(create(:chat_message, chat_channel: room, user: sender))
    second = notify(create(:chat_message, chat_channel: room, user: sender))

    described_class.new(user: user, account: account, chat_channel: room).perform

    expect(first.reload.read_at).to be_present
    expect(second.reload.read_at).to be_present
  end

  it 'leaves the notifications of other rooms alone' do
    elsewhere = notify(create(:chat_message, chat_channel: other_room, user: sender))

    described_class.new(user: user, account: account, chat_channel: room).perform

    expect(elsewhere.reload.read_at).to be_nil
  end

  it 'leaves other users notifications alone' do
    other_user = create(:user, account: account)
    theirs = notify(create(:chat_message, chat_channel: room, user: sender), to: other_user)

    described_class.new(user: user, account: account, chat_channel: room).perform

    expect(theirs.reload.read_at).to be_nil
  end

  it 'is triggered when the member reads the room' do
    notification = notify(create(:chat_message, chat_channel: room, user: sender))
    member = ChatChannelMember.create!(chat_channel: room, user: user, account: account)

    member.mark_read!

    expect(notification.reload.read_at).to be_present
  end
end
