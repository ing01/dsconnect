module SortHandler
  extend ActiveSupport::Concern

  class_methods do
    def sort_on_last_activity_at(sort_direction = :desc)
      order(last_activity_at: sort_direction)
    end

    def sort_on_created_at(sort_direction = :asc)
      order(created_at: sort_direction)
    end

    def sort_on_priority(sort_direction = :desc)
      order(generate_sql_query("priority #{sort_direction.to_s.upcase} NULLS LAST, last_activity_at DESC"))
    end

    def sort_on_priority_created_at(sort_direction = :desc)
      order(generate_sql_query("priority #{sort_direction.to_s.upcase} NULLS LAST, created_at ASC"))
    end

    def sort_on_waiting_since(sort_direction = :asc)
      order(generate_sql_query("(waiting_since IS NULL), waiting_since #{sort_direction.to_s.upcase}, created_at ASC"))
    end

    # Aba "Na fila": maior prioridade primeiro (urgente, alta, media, baixa,
    # sem prioridade) e, dentro da mesma prioridade, quem chamou primeiro
    # (`created_at` da conversa). Nao considera devolucao, o tempo da primeira
    # resposta nem a ultima mensagem do contato. Mesmo criterio de
    # `Queues#claim_next` e do `sortOnQueuePosition` do frontend.
    def sort_on_queue_position(_sort_direction = :asc)
      order(generate_sql_query('priority DESC NULLS LAST, created_at ASC, id ASC'))
    end

    def last_messaged_conversations
      Message.except(:order).select(
        'DISTINCT ON (conversation_id) conversation_id, id, created_at, message_type'
      ).order('conversation_id, created_at DESC')
    end

    def sort_on_last_user_message_at
      order('grouped_conversations.message_type', 'grouped_conversations.created_at ASC')
    end

    private

    def generate_sql_query(query)
      Arel::Nodes::SqlLiteral.new(sanitize_sql_for_order(query))
    end
  end
end
