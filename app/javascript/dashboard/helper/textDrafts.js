// Rascunhos de texto guardados no navegador: o que a pessoa digitou e ainda nao
// enviou (chat interno e tickets). Um por destino, separado por conta e usuario,
// por 7 dias. Os rascunhos das Conversas continuam no `store/draftMessages`.
import { shallowRef } from 'vue';
import { LocalStorage } from 'shared/helpers/localStorage';
import { LOCAL_STORAGE_KEYS } from 'dashboard/constants/localStorage';

const STORAGE_KEY = LOCAL_STORAGE_KEYS.TEXT_DRAFTS;
export const DRAFT_TTL = 7 * 24 * 60 * 60 * 1000;
export const MAX_DRAFTS = 100;

// Descarta o que venceu ou veio quebrado e, passando do limite, os mais antigos.
const prune = drafts => {
  const limit = Date.now() - DRAFT_TTL;
  return Object.fromEntries(
    Object.entries(drafts || {})
      .filter(
        ([, draft]) => typeof draft?.text === 'string' && draft.at > limit
      )
      .sort(([, a], [, b]) => b.at - a.at)
      .slice(0, MAX_DRAFTS)
  );
};

// Nulo quando o navegador nao deixa ler o armazenamento.
const readStorage = () => {
  try {
    const saved = LocalStorage.get(STORAGE_KEY);
    return prune(saved && typeof saved === 'object' ? saved : {});
  } catch (error) {
    return null;
  }
};

// A copia em memoria e' o que as telas leem: todas as que mostram o mesmo
// rascunho andam juntas, e o campo continua funcionando mesmo sem armazenamento.
const drafts = shallowRef(readStorage() || {});
let writeFailed = false;

export const reloadDrafts = () => {
  writeFailed = false;
  drafts.value = readStorage() || {};
};

export const draftKey = ({ accountId, userId, scope, id }) =>
  accountId && userId && id ? `${accountId}:${userId}:${scope}:${id}` : null;

export const readDraft = key => drafts.value[key]?.text || '';

export const writeDraft = (key, text) => {
  if (!key) return;

  // Parte do que esta gravado, para nao apagar o que outra aba do navegador
  // escreveu em outros campos.
  const base = (!writeFailed && readStorage()) || drafts.value;
  const next = { ...base };
  if (text) next[key] = { text, at: Date.now() };
  else delete next[key];

  drafts.value = prune(next);
  try {
    LocalStorage.set(STORAGE_KEY, drafts.value);
    writeFailed = false;
  } catch (error) {
    // Armazenamento cheio ou bloqueado: o rascunho vale so' enquanto a tela
    // estiver aberta.
    writeFailed = true;
  }
};

export const clearAllDrafts = () => {
  drafts.value = {};
  writeFailed = false;
  try {
    LocalStorage.remove(STORAGE_KEY);
  } catch (error) {
    // Sem armazenamento nao ha o que apagar.
  }
};
