// O editor da equipe guarda a quebra de linha como Markdown (barra invertida no fim
// da linha). A Area do Cliente mostra o texto como veio, entao a barra aparecia solta.
// Aqui a marca volta a ser uma quebra de linha comum. O servidor faz o mesmo no
// historico (ClientChatText); este cobre a mensagem que chega em tempo real.
export const plainChatText = content =>
  String(content ?? '').replace(/\\[ \t]*\r?\n/g, '\n');

// A citacao da mensagem respondida, para a que chega em tempo real: o cable manda so'
// o id, entao o texto vem da lista que ja esta na tela (mesmo formato do historico).
export const quotedMessage = (id, messages) => {
  const original = id && messages.find(message => message.id === id);
  if (!original) return null;

  return {
    id: original.id,
    content: String(original.content ?? '').slice(0, 200),
    from_you: original.from_you,
    author_name: original.author_name,
  };
};
