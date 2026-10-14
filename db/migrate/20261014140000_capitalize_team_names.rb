class CapitalizeTeamNames < ActiveRecord::Migration[7.1]
  # So capitaliza a primeira letra - preserva o resto do nome como esta, e so
  # mexe em quem realmente comeca com minuscula (o `WHERE` evita reprocessar
  # Mesas que ja estao certas).
  def up
    execute <<~SQL.squish
      UPDATE teams
      SET name = upper(substring(name from 1 for 1)) || substring(name from 2)
      WHERE name ~ '^[[:lower:]]'
    SQL
  end

  def down
    execute <<~SQL.squish
      UPDATE teams
      SET name = lower(name)
    SQL
  end
end
