module Projects
  class CreateTicketsService
    pattr_initialize [:account!, :project!, :tasks, :user]

    def perform
      return [] if tasks.blank?

      target_column = project.team.ticket_columns.order(:position).first
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
            company: project.company,
            contact: project.contact,
            project: project,
            project_task_template: template,
            title: template.default_ticket_title.presence || template.name,
            description: template.description.presence || template.name,
            priority: :medium,
            assignee_id: assignee_id,
            due_date: due_date,
            scheduled_at: scheduled_at,
            next_project_stage: template.next_project_stage,
            position: index
          )

          # Populate checklist from template
          Array(template.checklist).each_with_index do |item, item_idx|
            item_title = item.is_a?(Hash) ? item['title'] || item[:title] : item.to_s
            next if item_title.blank?

            ticket.ticket_checklist_items.create!(
              account: account,
              title: item_title,
              position: item_idx
            )
          end

          created_tickets << ticket
        end
      end

      created_tickets
    end

    private

    def parse_datetime(val)
      return nil if val.blank?
      return val if val.is_a?(Time) || val.is_a?(DateTime)

      Time.zone.parse(val.to_s)
    rescue ArgumentError, TypeError
      nil
    end
  end
end
