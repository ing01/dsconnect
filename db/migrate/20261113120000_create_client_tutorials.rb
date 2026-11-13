class CreateClientTutorials < ActiveRecord::Migration[7.0]
  def change
    create_table :client_tutorials do |t|
      t.references :account, null: false, foreign_key: true
      t.string :title, null: false
      t.text :description
      # Link do YouTube/Vimeo (ou de um arquivo de video). O arquivo enviado fica em
      # `video_file` (ActiveStorage) - um OU o outro, nunca os dois.
      t.string :video_url
      t.integer :position, null: false, default: 0
      t.boolean :active, null: false, default: true

      t.timestamps
    end
  end
end
