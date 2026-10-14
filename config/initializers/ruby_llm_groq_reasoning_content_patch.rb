# frozen_string_literal: true

# A Groq (que hospeda os modelos "openai/gpt-oss-*", configuraveis em
# CAPTAIN_OPEN_AI_MODEL) devolve "reasoning_content" no corpo da resposta de
# um modelo raciocinador, mas RECUSA esse mesmo campo quando ele volta numa
# proxima mensagem ("property 'reasoning_content' is unsupported") - e a gem
# ruby_llm (1.15.0) sempre reenvia esse campo ao continuar a conversa depois
# de uma chamada de ferramenta (`RubyLLM::Providers::OpenAI::Chat#format_thinking`),
# derrubando qualquer segunda chamada nesse caso. Este patch so' remove esse
# campo especifico do pedido de saida; o resto do "thinking" (campo
# "reasoning") continua indo normalmente, e nenhum outro comportamento muda.
#
# Se a gem for atualizada, confira se `format_thinking` ainda tem esta mesma
# forma antes de manter este patch.
Rails.application.config.after_initialize do
  require 'ruby_llm/providers/openai/chat'

  module RubyLLM
    module Providers
      class OpenAI
        module Chat
          module_function

          def format_thinking(msg)
            return {} unless msg.role == :assistant

            thinking = msg.thinking
            return {} unless thinking

            payload = {}
            payload[:reasoning] = thinking.text if thinking.text
            payload[:reasoning_signature] = thinking.signature if thinking.signature
            payload
          end
        end
      end
    end
  end
rescue StandardError => e
  Rails.logger.error "Failed to apply ruby_llm Groq reasoning_content patch: #{e.message}"
end
