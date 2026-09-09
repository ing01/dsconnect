module Projects
  class CreateTicketsService
    pattr_initialize [:account!, :project!, :tasks, :user]

    def perform
      return [] if tasks.blank?

      target_column = project.team.ticket_columns.find_by(kind: 'pending') || project.team.ticket_columns.order(:position).first
      return [] unless target_column

      created_tickets = []

      ActiveRecord::Base.transaction do
        tasks.each_with_index do |task_data, index|
          template = account.project_task_templates.find_by(id: task_data[:task_template_id] || task_data[:project_task_template_id])
          next unless template

          due_date = parse_datetime(task_data[:due_date])
          if due_date.blank? && template.due_days.present?
            base_date = project.start_date ? project.start_date.to_time : Time.zone.now
            due_date = base_date + template.due_days.days
          end

          scheduled_at = parse_datetime(task_data[:scheduled_at])

          assignee_id = task_data[:assignee_id].presence || template.default_assignee_id
          assignee_id = nil unless project.team.members.exists?(id: assignee_id)

          ticket = account.tickets.create!(
            team: project.team,
            ticket_column: target_column,
            ticket_category: ticket_category_for(task_data),
            company: project.company,
            contact: project.contact,
            project: project,
            project_task_template: template,
            title: ticket_title_for(template),
            description: template.description.presence || template.name,
            priority: :medium,
            assignee_id: assignee_id,
            due_date: due_date,
            scheduled_at: scheduled_at,
            next_project_stage: template.next_project_stage,
            position: index
          )

          # Populate checklist from the Checklist attached to the template, if any.
          Array(template.checklist&.items).each_with_index do |item, item_idx|
            attrs = checklist_item_attributes_from(item)
            next if attrs[:title].blank?

            ticket.ticket_checklist_items.create!(attrs.merge(account: account, position: item_idx))
          end

          created_tickets << ticket
        end
      end

      created_tickets
    end

    private

    # "NOME DA EMPRESA | NOME DA TAREFA" - so quando o projeto tem uma Empresa
    # (opcional: um projeto pode nao ter cliente). Sem o prefixo, tickets de
    # projetos diferentes com tarefas de mesmo nome ficavam indistinguiveis na
    # lista/Kanban de tickets.
    def ticket_title_for(template)
      task_title = template.default_ticket_title.presence || template.name
      return task_title if project.company.blank?

      "#{project.company.name} | #{task_title}"
    end

    # Ticket#ticket_category is required on create (see TicketOpening) - a task
    # can name a specific Categoria (chosen in ProjectCreateDialog's step 2),
    # falling back to the Mesa's first one so generation never fails just
    # because nobody picked one.
    def ticket_category_for(task_data)
      requested_id = task_data[:ticket_category_id].presence
      category = project.team.ticket_categories.find_by(id: requested_id) if requested_id

      category || project.team.ticket_categories.order(:position, :id).first
    end

    # Same shape as Api::V1::Accounts::TicketChecklistItemsController#item_attributes_from -
    # a Checklist's `items` jsonb array holds plain hashes (string keys),
    # `type` renamed to `item_type` since `type` is reserved for STI.
    def checklist_item_attributes_from(item)
      item = item.is_a?(Hash) ? item.with_indifferent_access : {}
      {
        title: item[:title].to_s,
        item_type: TicketChecklistItem::ITEM_TYPES.include?(item[:type]) ? item[:type] : 'checkbox',
        required: ActiveModel::Type::Boolean.new.cast(item[:required]) || false,
        options: item[:options].is_a?(Array) ? item[:options] : []
      }
    end

    def parse_datetime(val)
      return nil if val.blank?
      return val if val.is_a?(Time) || val.is_a?(DateTime)

      Time.zone.parse(val.to_s)
    rescue ArgumentError, TypeError
      nil
    end
  end
end
