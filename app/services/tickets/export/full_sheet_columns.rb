# As colunas da planilha completa (Tickets::Export::FullSheet), na ordem em que
# aparecem. E' uma TABELA de rotulo + funcao: as funcoes tem muitos `&.` (campo
# nao preenchido sai vazio), o que estoura as metricas de complexidade sem que haja
# logica de verdade - por isso elas ficam desligadas so' aqui.
# rubocop:disable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
module Tickets::Export::FullSheetColumns
  Column = Tickets::Export::FullSheet::Column
  DEV_FIELDS = Tickets::Export::FullSheet::DEV_FIELDS
  DEVELOPMENT_TYPES = Tickets::Export::FullSheet::DEVELOPMENT_TYPES

  module_function

  def all
    [
      # --- Identificação
      Column.new('ID interno', ->(t, _h) { t.id }),
      Column.new('Número', ->(t, _h) { t.display_id }),
      Column.new('Título', ->(t, h) { h.text(t.title) }),
      Column.new('Descrição', ->(t, h) { h.text(t.description) }),
      Column.new('Observação', ->(t, h) { h.text(t.observation) }),
      Column.new('Resolução', ->(t, h) { h.text(t.resolution) }),
      Column.new('Origem', ->(t, _h) { t.custom_attributes.to_h['imported_ticket_number'].present? ? 'Importado' : nil }),
      Column.new('Número no sistema anterior', ->(t, _h) { t.custom_attributes.to_h['imported_ticket_number'] }),
      Column.new('Chave do Jira', ->(t, _h) { t.jira_key }),
      # --- Fluxo
      Column.new('Status', ->(t, h) { h.label(:status, t.status) }),
      Column.new('Prioridade', ->(t, h) { h.label(:priority, t.priority) }),
      Column.new('Mesa de Serviço', ->(t, _h) { t.team&.name&.titleize }),
      Column.new('Estágio', ->(t, _h) { t.ticket_column&.name }),
      Column.new('Categoria', ->(t, _h) { t.ticket_category&.name }),
      Column.new('Complexidade', ->(t, _h) { t.ticket_complexity&.name }),
      Column.new('Catálogo de serviços', ->(t, _h) { t.service_catalog_item&.full_path&.join(' > ') }),
      Column.new('Próxima etapa do projeto', ->(t, _h) { t.next_project_stage }),
      Column.new('Aguardando triagem', ->(t, h) { h.yes_no(t.pending_triage) }),
      Column.new('Triado em', ->(t, h) { h.time(t.triaged_at) }),
      Column.new('Triado por', ->(t, _h) { t.triaged_by&.name }),
      # --- Cliente
      Column.new('Empresa', ->(t, _h) { t.company&.name }),
      Column.new('Razão social', ->(t, _h) { t.company&.legal_name }),
      Column.new('CNPJ', ->(t, _h) { t.company&.cnpj }),
      Column.new('Código da empresa', ->(t, _h) { t.company&.codigo }),
      Column.new('Nível da empresa', ->(t, _h) { t.company&.classification_level }),
      Column.new('Solicitante', ->(t, _h) { t.requester_contact&.name }),
      Column.new('E-mail do solicitante', ->(t, _h) { t.requester_contact&.email }),
      Column.new('Telefone do solicitante', ->(t, _h) { t.requester_contact&.phone_number }),
      # --- Responsáveis
      Column.new('Atendente', ->(t, _h) { t.assignee&.name }),
      Column.new('Responsável nível 2', ->(t, _h) { t.assignee_2&.name }),
      Column.new('Responsável nível 3', ->(t, _h) { t.assignee_3&.name }),
      Column.new('Responsável nível 4', ->(t, _h) { t.assignee_4&.name }),
      Column.new('Responsável nível 5', ->(t, _h) { t.assignee_5&.name }),
      Column.new('Seguidores', ->(t, _h) { t.followers.map(&:name).join('; ').presence }),
      # --- Relações
      Column.new('Ticket pai', ->(t, h) { h.number(t.parent) }),
      Column.new('Tickets filhos', ->(t, h) { h.numbers(t.children) }),
      Column.new('Agrupado em', ->(t, h) { h.number(t.merged_into) }),
      Column.new('Tickets agrupados', ->(t, h) { h.numbers(t.merged_tickets) }),
      Column.new('Projeto', ->(t, _h) { t.project&.name }),
      Column.new('Tarefa do projeto', ->(t, _h) { t.project_task_template&.name }),
      Column.new('Sprint', ->(t, _h) { t.sprint&.name }),
      Column.new('Tipo de desenvolvimento', ->(t, _h) { DEVELOPMENT_TYPES[t.development_type] }),
      Column.new('Conversas vinculadas', ->(t, _h) { t.conversations.map { |c| "##{c.display_id}" }.join('; ').presence }),
      # --- Impedimento
      Column.new('Impedido', ->(t, h) { h.yes_no(t.blocked?) }),
      Column.new('Impedido em', ->(t, h) { h.time(t.blocked_at) }),
      Column.new('Impedido por', ->(t, _h) { t.blocked_by&.name }),
      Column.new('Motivo do impedimento', ->(t, h) { h.text(t.blocked_reason) }),
      Column.new('Impedimento vindo do filho', ->(t, h) { h.number(t.blocked_by_child) }),
      Column.new('Filho concluído (selo)', ->(t, h) { h.time(t.child_completed_at) }),
      # --- Datas
      Column.new('Criado em', ->(t, h) { h.time(t.created_at) }),
      Column.new('Atualizado em', ->(t, h) { h.time(t.updated_at) }),
      Column.new('Data de entrega', ->(t, h) { h.time(t.due_date) }),
      Column.new('Agendado para', ->(t, h) { h.time(t.scheduled_at) }),
      Column.new('Resolvido em', ->(t, h) { h.time(t.resolved_at) }),
      Column.new('Fechado em', ->(t, h) { h.time(t.closed_at) }),
      Column.new('Cancelado em', ->(t, h) { h.time(t.cancelled_at) }),
      Column.new('Motivo do cancelamento', ->(t, h) { h.text(t.close_reason) }),
      # --- SLA
      *sla_columns,
      # --- Campos do desenvolvimento (Jira)
      *DEV_FIELDS.map { |key, label| Column.new(label, ->(t, h) { h.text(t.custom_attributes.to_h[key]) }) },
      Column.new('Outros campos personalizados', ->(t, h) { h.other_custom_attributes(t) }),
      # --- O que esta ligado ao ticket
      Column.new('Anexos (quantidade)', ->(t, _h) { t.ticket_attachments.size }),
      Column.new('Anexos', ->(t, h) { h.attachment_names(t) }),
      Column.new('Comunicações com o cliente (quantidade)', ->(t, _h) { t.ticket_customer_communications.size }),
      Column.new('Comunicações com o cliente', ->(t, h) { h.communications(t) }),
      Column.new('Comentários internos (quantidade)', ->(t, _h) { t.ticket_comments.size }),
      Column.new('Comentários internos', ->(t, h) { h.comments(t) }),
      Column.new('Apontamentos (quantidade)', ->(t, _h) { t.ticket_time_entries.size }),
      Column.new('Horas apontadas', ->(t, h) { h.hours(t) }),
      Column.new('Apontamentos', ->(t, h) { h.time_entries(t) }),
      Column.new('Checklist (concluídos/total)', ->(t, h) { h.checklist_progress(t) }),
      Column.new('Itens do checklist', ->(t, h) { h.checklist_items(t) }),
      Column.new('Compromissos (quantidade)', ->(t, _h) { t.calendar_events.size }),
      Column.new('Compromissos', ->(t, h) { h.appointments(t) }),
      Column.new('Propostas (quantidade)', ->(t, _h) { t.ticket_proposals.size }),
      Column.new('Histórico (quantidade)', ->(t, _h) { t.ticket_activities.size }),
      Column.new('Histórico', ->(t, h) { h.history(t) })
    ]
  end

  # Os tres relogios (atendimento, estagio, solucao): o estado e o prazo de cada um.
  def sla_columns
    { 'response' => 'atendimento', 'stage' => 'estágio', 'resolution' => 'solução' }.flat_map do |kind, name|
      [
        Column.new("SLA #{name} (situação)", ->(t, h) { h.sla_status(t, kind) }),
        Column.new("SLA #{name} (prazo)", ->(t, h) { h.sla_due(t, kind) })
      ]
    end
  end
end
# rubocop:enable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
