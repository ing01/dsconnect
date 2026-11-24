// O editor da equipe guarda a quebra de linha como Markdown (barra invertida no fim
// da linha). A Area do Cliente mostra o texto como veio, entao a barra aparecia solta.
// Aqui a marca volta a ser uma quebra de linha comum. O servidor faz o mesmo no
// historico (ClientChatText); este cobre a mensagem que chega em tempo real.
export const plainChatText = content =>
  String(content ?? '').replace(/\\[ \t]*\r?\n/g, '\n');
