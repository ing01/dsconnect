# Repara os arquivos dos tickets FILHOS que ficaram quebrados (imagem que nao abre).
#
# Ate a correcao de 2026-11-12, copiar os arquivos do ticket pai ao criar um filho gravava
# o ticket e o registro do anexo, mas o ENVIO do arquivo para o armazenamento falhava com
# "closed stream" (o arquivo temporario ja estava fechado). O resultado: o anexo existe no
# filho, com nome e tamanho, mas o arquivo em si nao existe no storage - a imagem aparece
# quebrada.
#
# A tarefa procura, nos filhos, os anexos cujo arquivo falta no storage e reenvia o conteudo
# a partir do anexo do pai que tem o MESMO checksum (o checksum do filho foi calculado do
# arquivo original, entao e' a prova de que e' o mesmo conteudo). Nao cria nem apaga nenhum
# registro: so devolve o arquivo que faltava. Anexo sem origem no pai e' apenas listado.
#
# Por padrao so' LISTA o que seria reparado (dry run). Passe CONFIRM=1 para executar.
# ACCOUNT_ID e opcional.
#
#   bundle exec rake duesoft:repair_child_ticket_attachments
#   CONFIRM=1 bundle exec rake duesoft:repair_child_ticket_attachments
namespace :duesoft do
  desc 'Reenvia ao storage os arquivos que faltam nos anexos de tickets filhos (CONFIRM=1 executa)'
  task repair_child_ticket_attachments: :environment do
    confirm = ENV['CONFIRM'] == '1'

    scope = TicketAttachment.joins(:ticket).where.not(tickets: { parent_id: nil })
    scope = scope.where(account_id: ENV['ACCOUNT_ID']) if ENV['ACCOUNT_ID'].present?

    repaired = 0
    orphaned = 0

    scope.includes(file_attachment: :blob, ticket: :parent).find_each do |attachment|
      next unless attachment.file.attached?

      blob = attachment.file.blob
      next if blob.service.exist?(blob.key)

      source = attachment.ticket.parent.ticket_attachments.includes(file_attachment: :blob).find do |candidate|
        candidate.file.attached? &&
          candidate.file.blob.checksum == blob.checksum &&
          candidate.file.blob.service.exist?(candidate.file.blob.key)
      end

      label = "ticket ##{attachment.ticket.display_id} - #{blob.filename}"
      if source.nil?
        orphaned += 1
        puts "SEM ORIGEM  #{label}"
        next
      end

      puts "#{confirm ? 'REPARANDO' : 'REPARARIA'}  #{label} (do ticket ##{attachment.ticket.parent.display_id})"
      next unless confirm

      source.file.blob.open { |file| blob.upload_without_unfurling(file) }
      repaired += 1
    end

    puts "#{confirm ? 'Reparados' : 'A reparar'}: #{confirm ? repaired : 'veja acima'} | sem origem: #{orphaned}"
    puts 'Nada foi alterado. Rode de novo com CONFIRM=1 para executar.' unless confirm
  end
end
