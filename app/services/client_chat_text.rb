# O texto de uma mensagem do chat como a Area do Cliente (e o app) o mostram.
#
# O editor da equipe guarda a quebra de linha como Markdown: uma barra invertida no
# fim da linha (`\` + quebra). O painel interpreta isso, mas a Area do Cliente mostra
# o texto como veio - e a mensagem chegava com um `\` solto no fim de cada linha. Aqui a
# marca volta a ser uma quebra de linha comum, so' na saida para o cliente; o que esta
# gravado na mensagem nao muda.
module ClientChatText
  HARD_BREAK = /\\[ \t]*\r?\n/

  def self.plain(content)
    content.to_s.gsub(HARD_BREAK, "\n")
  end
end
