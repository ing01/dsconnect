# A avaliacao mensal de satisfacao do Portal do Cliente.
#
# Uma por CONTATO por MES - nunca por empresa: a opiniao e pessoal, e um colega
# nao responde pela mesma empresa. E por isso que, diferente da Manifestacao
# (SAC), esta tabela nao tem conceito de "ver a da empresa toda": a fronteira
# e sempre o proprio contato, sem a permissao `client_tickets_visibility`
# entrando em jogo.
#
# `reference_month` e sempre o dia 1 do mes (mesmo espirito de `competencia`
# em CrmSale) - uma DATE, e nao colunas separadas de ano/mes, porque agrupar
# por mes e comparar mes-a-mes e so' isso que a feature pede (ver o indice
# unico abaixo, que e quem garante "uma resposta por mes" no BANCO, nao so na
# tela).
#
# As dez perguntas vao para uma tabela FILHA (`monthly_satisfaction_survey_
# answers`), uma linha por pergunta, e nao colunas fixas nem um JSONB: e o que
# deixa "media por pergunta" e "evolucao mensal" uma consulta de GROUP BY
# simples, em vez de espalhar logica de agregacao por JSONB pela aplicacao -
# o mesmo motivo que fez `TicketComplexity`/`Manifestation` evitarem blob.
class CreateMonthlySatisfactionSurveys < ActiveRecord::Migration[7.2]
  def change
    create_surveys
    create_answers
  end

  private

  def create_surveys
    create_table :monthly_satisfaction_surveys do |t|
      t.references :account, null: false, foreign_key: true
      # Nulaveis com `nullify`, o mesmo acordo que Manifestation tem com
      # Company/Contact: excluir uma Empresa ou um Contato nunca pode levar o
      # historico de satisfacao junto. O MODEL exige os dois na criacao
      # (`on: :create`) - so no banco que ficam opcionais.
      t.references :company, null: true, foreign_key: { on_delete: :nullify }
      t.references :contact, null: true, foreign_key: { on_delete: :nullify }

      t.date :reference_month, null: false
      # A pergunta aberta e opcional - "O que podemos melhorar?".
      t.text :comment

      t.timestamps
    end

    # A trava de verdade: UMA resposta por contato por mes, no BANCO - nao so
    # na tela nem so na action do controller. E o que o pedido de seguranca
    # exige ("validar a regra tambem no backend, nao confiar so no frontend").
    add_index :monthly_satisfaction_surveys, %i[account_id contact_id reference_month],
              unique: true, name: 'index_monthly_surveys_unique_per_contact_month'
    # O recorte que a area interna vai usar para "media por empresa" e
    # "evolucao mensal" por empresa.
    add_index :monthly_satisfaction_surveys, %i[company_id reference_month]
  end

  def create_answers
    create_table :monthly_satisfaction_survey_answers do |t|
      t.references :monthly_satisfaction_survey, null: false, foreign_key: true,
                                                 index: { name: 'index_monthly_survey_answers_on_survey' }
      # A pergunta e uma CHAVE ESTAVEL (ex.: "erp_overall"), nunca o texto -
      # o texto mora so no i18n do frontend, pela mesma razao que
      # `Manifestation#kind` e um enum e nao uma string livre: trocar a
      # REDACAO da pergunta um dia nao pode mexer no dado ja gravado.
      t.string :question_key, null: false
      t.integer :rating, null: false

      t.timestamps
    end

    # Nao pode haver duas respostas para a MESMA pergunta na MESMA avaliacao.
    add_index :monthly_satisfaction_survey_answers, %i[monthly_satisfaction_survey_id question_key],
              unique: true, name: 'index_monthly_survey_answers_unique_question'
  end
end
