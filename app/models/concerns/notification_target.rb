# Para onde a notificacao leva, e com que etiqueta ela chega.
#
# Separado de NotificationPushContent de proposito: um modulo monta o TEXTO do
# aviso, este diz o DESTINO. Sao perguntas diferentes, e cada tipo novo de
# notificacao mexe em uma ou na outra, raramente nas duas.
module NotificationTarget
  extend ActiveSupport::Concern

  include Rails.application.routes.url_helpers

  # Identifica o ASSUNTO, nao a notificacao. Duas mensagens da mesma conversa
  # compartilham a etiqueta, entao a segunda SUBSTITUI o aviso da primeira em vez
  # de empilhar outro card - o que importa quando o aviso fica na tela ate a
  # pessoa clicar. A etiqueta antiga trazia o id da notificacao, que e unico por
  # definicao: nada nunca se agrupava.
  #
  # No Chat Interno o ator e a mensagem, entao o agrupamento tem de vir da sala;
  # nas conversas o proprio ator ja e a conversa.
  def push_group_tag
    case primary_actor_type
    when 'ChatMessage'
      "internal_chat_#{primary_actor.chat_channel_id}"
    when 'Project'
      "project_#{primary_actor_id}"
    when 'Ticket'
      if notification_type == 'ticket_customer_communication_received'
        # Aqui SIM agrupado pelo ticket: duas respostas do mesmo cliente no
        # mesmo chamado sao o MESMO assunto, a segunda substitui o aviso da
        # primeira em vez de empilhar.
        "ticket_communication_#{primary_actor_id}"
      elsif notification_type == 'ticket_proposal_answered'
        # Por proposta, e nao por ticket: duas propostas respondidas no mesmo
        # chamado sao decisoes diferentes, e uma nao pode apagar o aviso da outra.
        "ticket_proposal_#{secondary_actor_id}"
      else
        # Agrupado pela TELA, e nao pelo ticket: a triagem se lê de uma vez, e
        # um aviso por chamado empilharia a bandeja num dia movimentado.
        'ticket_triage'
      end
    when 'Suggestion'
      "suggestion_#{primary_actor_id}"
    when 'Article'
      "article_#{primary_actor_id}"
    when 'Portal'
      "portal_#{primary_actor_id}"
    else
      "conversation_#{primary_actor_id}"
    end
  end

  # Para onde o clique leva, SEM host. O host certo e aquele que a pessoa ja
  # esta usando, e quem sabe disso e o navegador: o service worker resolve este
  # caminho contra a propria origem. Gravar o host aqui significaria depender do
  # FRONTEND_URL, que envelhece a cada troca de endereco - e um tunel temporario
  # troca de endereco a cada reinicio, levando a notificacao para um lugar morto.
  def push_target_path
    case primary_actor_type
    when 'ChatMessage'
      # A tela do Chat Interno escolhe a sala por `?room=` (InternalChatPage).
      # Nao ha helper de rota para ela: o /app e servido pelo mesmo dashboard
      # e as rotas internas sao do lado do navegador.
      "/app/accounts/#{account_id}/internal-chat?room=#{primary_actor.chat_channel_id}"
    when 'Project'
      "/app/accounts/#{account_id}/projects?project=#{primary_actor_id}"
    when 'Ticket'
      if notification_type == 'ticket_customer_communication_received'
        # Leva direto pro chamado, ja na aba de Comunicacao - e' ali que a
        # resposta do cliente esta.
        "/app/accounts/#{account_id}/tickets/#{primary_actor_id}?tab=communication"
      elsif notification_type == 'ticket_proposal_answered'
        # Direto na aba Valorizacao, onde esta a proposta que o cliente decidiu.
        "/app/accounts/#{account_id}/tickets/#{primary_actor_id}?tab=valuation"
      else
        # Leva a fila, e nao ao chamado: o que se faz com ele e aceitar e
        # encaminhar, e isso acontece na Triagem.
        "/app/accounts/#{account_id}/tickets/triage"
      end
    when 'Suggestion'
      # `?suggestion=` e o que SuggestionsPage.vue le para abrir o card certo
      # direto, em vez de so' levar ao quadro e deixar quem recebeu o aviso
      # procurar a sugestao sozinho.
      "/app/accounts/#{account_id}/suggestions?suggestion=#{primary_actor_id}"
    when 'Article'
      article_target_path
    when 'Portal'
      "/app/accounts/#{account_id}/portals/#{primary_actor.slug}/#{primary_actor.default_locale}/articles"
    else
      app_account_conversation_path(account_id: account_id, id: conversation.display_id)
    end
  end

  # Com Categoria, a tela de edicao vive debaixo dela; sem Categoria, debaixo
  # do Portal direto - sao duas rotas diferentes no painel (ver
  # helpcenter.routes.js: portals_categories_articles_edit / portals_articles_edit).
  def article_target_path
    base = "/app/accounts/#{account_id}/portals/#{primary_actor.portal.slug}/#{primary_actor.locale}"
    category = primary_actor.category

    if category.present?
      "#{base}/categories/#{category.slug}/articles/#{primary_actor.slug}"
    else
      "#{base}/articles/edit/#{primary_actor.slug}"
    end
  end

  # Versao absoluta, para quem precisa de host: e-mail, por exemplo, que nao tem
  # navegador para resolver caminho relativo.
  def push_target_url
    "#{frontend_base_url}#{push_target_path}"
  end

  def frontend_base_url
    ENV.fetch('FRONTEND_URL', '')
  end
end
