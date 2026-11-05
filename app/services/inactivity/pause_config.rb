# Configuracao do fluxo de PAUSA por inatividade (guardada em
# `Inbox#inactivity_config` e `ServiceQueue#inactivity_pause_config`).
# Tudo desligado por padrao: sem `pause_enabled` o comportamento continua sendo
# o encerramento direto por inatividade.
class Inactivity::PauseConfig
  DEFAULT_PAUSE_AFTER = 5     # min depois do aviso (ou da ultima msg da equipe, sem aviso)
  DEFAULT_PAUSE_WINDOW = 120  # min pausado, aguardando o cliente voltar
  DEFAULT_MAX_PAUSES = 1

  DEFAULT_MESSAGES = {
    'pause' => "⏸️ Seu atendimento foi pausado por falta de interação.\n\n" \
               "Você pode retomar esta mesma conversa até {data_hora_limite}, sem perder o histórico. " \
               "Responda SIM (ou envie qualquer mensagem) para retomar, ou NÃO para encerrar.\n\n" \
               'Após esse prazo, o atendimento será finalizado.',
    'resume_same_agent' => "✅ Que bom ter você de volta! Conversa reaberta.\n\n" \
                           'Seu atendimento será retomado com {atendente}. Aguarde ser atendido.',
    'resume_queue' => "✅ Que bom ter você de volta! Conversa reaberta.\n\n" \
                      'O atendente anterior não está disponível no momento, então você foi encaminhado ' \
                      'para a fila e será atendido por um novo atendente. Aguarde ser atendido.',
    'resume_out_of_hours' => 'Estamos fora do horário de atendimento no momento. ' \
                             'Seu atendimento continuará assim que voltarmos.',
    'extension' => "⏰ O prazo de pausa do seu atendimento foi estendido!{motivo}\n\n" \
                   'Você poderá retomá-lo até {data_hora_limite}. Basta enviar uma mensagem por aqui.',
    'finalize' => "✅ Seu atendimento foi finalizado automaticamente por falta de interação.\n\n" \
                  'Caso ainda precise de ajuda, basta enviar uma nova mensagem por aqui!',
    'decline' => "Tudo bem, atendimento encerrado.\n\nSe precisar de ajuda, é só enviar uma nova mensagem por aqui!"
  }.freeze

  PERMITTED_KEYS = %i[
    pause_enabled pause_after pause_window max_pauses resume_one_click keep_previous_agent respect_working_hours
    extension_enabled max_extension_minutes max_extensions
    pause_message resume_same_agent_message resume_queue_message resume_out_of_hours_message
    extension_message finalize_message decline_message
  ].freeze

  def initialize(raw)
    @raw = (raw || {}).to_h.with_indifferent_access
  end

  def enabled?
    bool(:pause_enabled, false)
  end

  def pause_after
    positive(:pause_after) || DEFAULT_PAUSE_AFTER
  end

  def pause_window
    positive(:pause_window) || DEFAULT_PAUSE_WINDOW
  end

  def max_pauses
    value = @raw[:max_pauses]
    value.blank? ? DEFAULT_MAX_PAUSES : value.to_i
  end

  def resume_one_click?
    bool(:resume_one_click, true)
  end

  def keep_previous_agent?
    bool(:keep_previous_agent, true)
  end

  # Prazos (aviso, pausa, retomada) so correm no horario de atendimento da
  # caixa. Sem horario de atendimento ligado na caixa, e' relogio corrido.
  def respect_working_hours?
    bool(:respect_working_hours, true)
  end

  def extension_enabled?
    bool(:extension_enabled, true)
  end

  # nil = sem limite (padrao, ate o administrador definir).
  def max_extension_minutes
    positive(:max_extension_minutes)
  end

  def max_extensions
    positive(:max_extensions)
  end

  def message(key)
    @raw["#{key}_message"].presence || DEFAULT_MESSAGES.fetch(key.to_s)
  end

  private

  def positive(key)
    value = @raw[key].to_i
    value if value.positive?
  end

  def bool(key, default)
    return default if @raw[key].nil? || @raw[key] == ''

    ActiveModel::Type::Boolean.new.cast(@raw[key])
  end
end
