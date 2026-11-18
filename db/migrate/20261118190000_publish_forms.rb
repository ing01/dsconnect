# Formularios publicaveis na Central de Ajuda: o cliente (logado na Area do Cliente) ou qualquer
# pessoa (formulario "aberto") preenche, e a resposta fica guardada SEM chamado.
#
# - forms.access_mode: 'login' (so' cliente logado - o padrao, o mais seguro) ou 'open' (sem login);
# - forms.public_token: o codigo do link do formulario aberto. Nao e' o id do banco (sequencial,
#   adivinhavel): quem nao recebeu o link nao consegue listar os formularios abertos;
# - forms.success_message: o texto mostrado depois de enviar;
# - form_responses.ticket_id passa a aceitar nulo, e ganha quem respondeu (contato, nome e e-mail
#   opcionais do formulario aberto) e a origem (ticket, internal, client, public).
class PublishForms < ActiveRecord::Migration[7.2]
  def up
    add_column :forms, :access_mode, :string, default: 'login', null: false
    add_column :forms, :public_token, :string
    add_column :forms, :success_message, :text
    add_index :forms, :public_token, unique: true

    # Quem ja existia ganha o codigo agora (so' vale como link se o formulario for "aberto").
    select_values('SELECT id FROM forms').each do |id|
      execute("UPDATE forms SET public_token = #{quote(SecureRandom.base58(24))} WHERE id = #{id.to_i}")
    end

    change_column_null :form_responses, :ticket_id, true
    add_reference :form_responses, :contact, foreign_key: true, index: true
    add_column :form_responses, :source, :string, default: 'ticket', null: false
    add_column :form_responses, :respondent_name, :string
    add_column :form_responses, :respondent_email, :string
  end

  def down
    remove_column :form_responses, :respondent_email
    remove_column :form_responses, :respondent_name
    remove_column :form_responses, :source
    remove_reference :form_responses, :contact, foreign_key: true
    # Respostas avulsas nao cabem de volta na regra antiga (sempre com chamado).
    execute('DELETE FROM form_responses WHERE ticket_id IS NULL')
    change_column_null :form_responses, :ticket_id, false

    remove_index :forms, :public_token
    remove_column :forms, :success_message
    remove_column :forms, :public_token
    remove_column :forms, :access_mode
  end
end
