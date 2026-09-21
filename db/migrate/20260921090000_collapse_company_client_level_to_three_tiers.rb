class CollapseCompanyClientLevelToThreeTiers < ActiveRecord::Migration[7.2]
  # A prioridade de cliente vira 3 niveis (Baixa/Media/Alta), computados a
  # partir da mensalidade, em vez de 5 niveis manuais. Mapeamento de
  # compactacao: 1-2 -> Baixa(1), 3-4 -> Media(2), 5 -> Alta(3) - o mesmo
  # agrupamento que Tickets::HelpdeskPriority::LEVEL_BASELINE ja usava.
  # `down` expande de volta para um valor representativo, nao o exato
  # original - a compactacao e irreversivel por natureza.
  def up
    execute <<~SQL.squish
      UPDATE companies SET client_level = CASE
        WHEN client_level <= 2 THEN 1
        WHEN client_level <= 4 THEN 2
        ELSE 3
      END
    SQL
  end

  def down
    execute <<~SQL.squish
      UPDATE companies SET client_level = CASE
        WHEN client_level = 1 THEN 1
        WHEN client_level = 2 THEN 3
        ELSE 5
      END
    SQL
  end
end
