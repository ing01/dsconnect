import { defineComponent, nextTick, ref } from 'vue';
import { mount } from '@vue/test-utils';
import { useTextDraft } from '../useTextDraft';
import { reloadDrafts } from 'dashboard/helper/textDrafts';

// Monta o composable como uma tela faria, com a conta e o usuario na store.
const usar = ({ id = ref(1), userId = 9, scope = 'chat' } = {}) => {
  let draft;
  mount(
    defineComponent({
      setup() {
        draft = useTextDraft(scope, () => id.value);
        return () => null;
      },
    }),
    {
      global: {
        plugins: [
          {
            install: app => {
              app.config.globalProperties.$store = {
                getters: { getCurrentAccountId: 1, getCurrentUserID: userId },
              };
            },
          },
        ],
      },
    }
  );
  return { draft, id };
};

describe('useTextDraft', () => {
  beforeEach(() => {
    localStorage.clear();
    reloadDrafts();
  });

  it('volta o texto numa tela nova, avisando que foi recuperado', () => {
    const first = usar().draft;
    first.text.value = 'metade da frase';
    expect(first.isRestored.value).toBe(false);

    reloadDrafts();
    const second = usar().draft;

    expect(second.text.value).toBe('metade da frase');
    expect(second.isRestored.value).toBe(true);
  });

  it('cada destino tem o seu texto', async () => {
    const { draft, id } = usar();
    draft.text.value = 'para o primeiro';

    id.value = 2;
    await nextTick();
    expect(draft.text.value).toBe('');
    draft.text.value = 'para o segundo';

    id.value = 1;
    await nextTick();
    expect(draft.text.value).toBe('para o primeiro');
    expect(draft.isRestored.value).toBe(true);
  });

  it('outro usuario no mesmo navegador nao ve o texto', () => {
    usar().draft.text.value = 'meu';

    expect(usar({ userId: 10 }).draft.text.value).toBe('');
  });

  it('tipos diferentes nao se misturam', () => {
    usar({ scope: 'ticket-comment' }).draft.text.value = 'nota interna';

    expect(usar({ scope: 'ticket-message' }).draft.text.value).toBe('');
  });

  it('duas telas do mesmo destino andam juntas', () => {
    const first = usar().draft;
    const second = usar().draft;

    first.text.value = 'digitado numa';

    expect(second.text.value).toBe('digitado numa');
    second.clear(second.snapshot());
    expect(first.text.value).toBe('');
  });

  it('apaga o que foi enviado', () => {
    const { draft } = usar();
    draft.text.value = 'enviado';

    draft.clear(draft.snapshot());

    expect(usar().draft.text.value).toBe('');
  });

  it('nao apaga o que mudou depois do envio comecar', () => {
    const { draft } = usar();
    draft.text.value = 'enviado';
    const sent = draft.snapshot();
    draft.text.value = 'enviado e mais';

    draft.clear(sent);

    expect(draft.text.value).toBe('enviado e mais');
  });

  it('confirmado depois da troca de destino, apaga so o enviado', async () => {
    const { draft, id } = usar();
    draft.text.value = 'do primeiro';
    const sent = draft.snapshot();
    id.value = 2;
    await nextTick();
    draft.text.value = 'do segundo';

    draft.clear(sent);

    expect(draft.text.value).toBe('do segundo');
    id.value = 1;
    await nextTick();
    expect(draft.text.value).toBe('');
  });

  it('devolve o texto que falhou antes do que foi digitado depois', () => {
    const { draft } = usar();
    const failed = { key: draft.snapshot().key, text: 'falhou' };

    draft.putBack(failed);
    expect(draft.text.value).toBe('falhou');

    draft.text.value = 'seguinte';
    draft.putBack(failed);
    expect(draft.text.value).toBe('falhou\nseguinte');
  });

  it('descartar limpa o campo e o aviso', () => {
    usar().draft.text.value = 'velho';
    const { draft } = usar();

    draft.discard();

    expect(draft.text.value).toBe('');
    expect(draft.isRestored.value).toBe(false);
  });

  it('so espacos nao viram aviso', () => {
    usar().draft.text.value = '   ';

    expect(usar().draft.isRestored.value).toBe(false);
  });

  it('sem usuario o campo funciona, mas nada e guardado', async () => {
    const { draft, id } = usar({ userId: null });
    draft.text.value = 'solto';

    expect(draft.text.value).toBe('solto');
    expect(localStorage.getItem('textDrafts')).toBeNull();

    id.value = 2;
    await nextTick();
    expect(draft.text.value).toBe('');
  });
});
