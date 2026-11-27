import { computed, ref, toValue, watch } from 'vue';
import { useStore } from 'dashboard/composables/store';
import { draftKey, readDraft, writeDraft } from 'dashboard/helper/textDrafts';

// A chave do rascunho para quem esta usando a tela. Nula sem conta, usuario ou
// destino - e sem chave nada e' guardado.
export function useDraftKey() {
  const store = useStore();

  return (scope, id) =>
    draftKey({
      accountId: store?.getters?.getCurrentAccountId,
      userId: store?.getters?.getCurrentUserID,
      scope,
      id,
    });
}

// Um campo de texto que nao se perde: `text` serve direto no `v-model`, salva a
// cada mudanca e volta quando a pessoa retorna ao mesmo destino (`id`, que pode
// mudar com a tela aberta). Quem envia tira uma `snapshot` antes e chama `clear`
// so' depois da confirmacao.
export function useTextDraft(scope, id) {
  const keyFor = useDraftKey();
  const key = computed(() => keyFor(scope, toValue(id)));
  const unsaved = ref('');
  const recovered = ref(false);

  const read = target => (target ? readDraft(target) : unsaved.value);
  const write = (target, value) => {
    if (target) writeDraft(target, value);
    else unsaved.value = value;
  };

  const text = computed({
    get: () => read(key.value),
    set: value => {
      write(key.value, value);
      if (!value) recovered.value = false;
    },
  });

  // Marca se o que esta no campo veio de antes. Chamado sozinho na troca de
  // destino; uma janela que reabre chama de novo.
  const refresh = () => {
    recovered.value = !!(key.value && readDraft(key.value).trim());
  };

  watch(
    () => toValue(id),
    () => {
      unsaved.value = '';
    }
  );
  watch(key, refresh, { immediate: true });

  const snapshot = () => ({ key: key.value, text: text.value });

  // Apaga o que foi enviado. Se o campo mudou depois da `snapshot`, o texto novo
  // fica.
  const clear = ({ key: target, text: sent }) => {
    if (read(target) !== sent) return;

    write(target, '');
    if (target === key.value) recovered.value = false;
  };

  // O envio falhou: o texto volta, antes do que tenha sido digitado depois.
  const putBack = ({ key: target, text: failed }) => {
    const current = read(target);
    write(target, current.trim() ? `${failed}\n${current}` : failed);
  };

  const discard = () => clear(snapshot());

  const isRestored = computed(() => recovered.value && !!text.value.trim());

  return { text, isRestored, refresh, snapshot, clear, putBack, discard };
}
