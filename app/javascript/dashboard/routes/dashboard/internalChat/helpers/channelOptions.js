// Os mesmos valores dos enums do servidor (`ChatChannel#visibility` e
// `#posting_policy`). Ficam num módulo próprio, e não no componente do
// formulário, porque `<script setup>` não pode exportar nada - e os dois
// diálogos, criar e editar, precisam deles.
//
// Com 'public'/'private' ou 'moderator' o servidor recusa a gravação inteira,
// então errar aqui só aparece na hora de salvar.
export const PUBLIC = 'public_channel';
export const PRIVATE = 'private_channel';
export const EVERYONE = 'everyone';
export const MODERATORS = 'moderators';

// Um canal novo, ou a base que a edição preenche.
export const emptyChannelForm = () => ({
  name: '',
  description: '',
  visibility: PUBLIC,
  memberIds: [],
  pinned: false,
  postingPolicy: EVERYONE,
  moderatorIds: [],
});
