<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'dashboard/composables/store';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const props = defineProps({
  ticketId: {
    type: [Number, String],
    required: true,
  },
});

const ACTIVITY_ICONS = {
  created: 'i-lucide-plus-circle',
  status_changed: 'i-lucide-refresh-cw',
  column_changed: 'i-lucide-move-horizontal',
  priority_changed: 'i-lucide-flag',
  assignee_changed: 'i-lucide-user',
  team_changed: 'i-lucide-users',
  comment_added: 'i-lucide-message-square',
  resolved: 'i-lucide-check',
  reopened: 'i-lucide-rotate-ccw',
  closed: 'i-lucide-check-check',
  conversation_linked: 'i-lucide-link',
  conversation_unlinked: 'i-lucide-unlink',
  blocked: 'i-lucide-octagon-pause',
  unblocked: 'i-lucide-play',
  automation_note: 'i-lucide-zap',
  imported: 'i-lucide-file-input',
};

// `te` diz se a chave existe. Sem ele, `t` de uma chave ausente devolve o
// PROPRIO caminho - foi assim que "TICKET.ACTIVITY.FIELDS.COMMENT_ADDED"
// apareceu na tela como se fosse texto.
const { t, te } = useI18n();
const store = useStore();

// Quais entradas estao com o detalhe aberto. Um Set porque varias podem estar
// abertas ao mesmo tempo - fechar uma para abrir outra obrigaria a pessoa a
// comparar de memoria.
const abertas = ref(new Set());

const activities = computed(() =>
  store.getters['tickets/getActivities'](props.ticketId)
);
const isLoading = computed(
  () => store.getters['tickets/getUIFlags'].isFetchingActivities
);

const chave = tipo => (tipo || '').toUpperCase();

// A comunicacao com o cliente produz a MESMA atividade tenha saido por e-mail
// ou nao - o que muda e o `meta.notify_customer`. Sem esta distincao o Historico
// diria "Comunicacao enviada" sobre algo que ninguem enviou.
const REGISTRADA_SEM_EMAIL = {
  CUSTOMER_COMMUNICATION_SENT: 'CUSTOMER_COMMUNICATION_REGISTERED',
};

const tipoEfetivo = activity => {
  const tipo = chave(activity.activity_type);
  if (activity.meta?.notify_customer === false && REGISTRADA_SEM_EMAIL[tipo]) {
    return REGISTRADA_SEM_EMAIL[tipo];
  }
  return tipo;
};

const titulo = activity => {
  const tipo = tipoEfetivo(activity);
  if (te(`TICKET.ACTIVITY.TITLES.${tipo}`)) {
    return t(`TICKET.ACTIVITY.TITLES.${tipo}`);
  }

  // Tipo sem titulo proprio cai no rotulo antigo, que e uma frase completa com
  // o autor - melhor uma frase em prosa do que o nome da chave.
  if (te(`TICKET.ACTIVITY.TYPES.${tipo}`)) {
    return t(`TICKET.ACTIVITY.TYPES.${tipo}`, {
      actor: activity.user?.name || t('TICKET.ACTIVITY.SYSTEM'),
    });
  }

  return '';
};

// Nem toda atividade e mudanca de campo: "duplicou", "comentou" e "criou" nao
// tem campo nenhum, e a linha "Mudanca em" simplesmente nao aparece.
const campo = activity => {
  const alvo = `TICKET.ACTIVITY.FIELDS.${chave(activity.activity_type)}`;
  return te(alvo) ? t(alvo) : '';
};

const temValores = activity =>
  Boolean(activity.previous_value || activity.new_value);

const vazio = () => t('TICKET.ACTIVITY.EMPTY_VALUE');

const dataHora = activity =>
  new Date(activity.created_at * 1000).toLocaleString(undefined, {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  });

const soData = activity =>
  new Date(activity.created_at * 1000).toLocaleDateString();

// Agrupa por dia, e o dia recebe um rotulo em vez da data crua quando e hoje ou
// ontem - e assim que a pessoa pensa sobre o que acabou de acontecer.
const grupos = computed(() => {
  const hoje = new Date().toLocaleDateString();
  const ontem = new Date(Date.now() - 86400000).toLocaleDateString();

  return activities.value.reduce((acc, activity) => {
    const dia = soData(activity);
    const anterior = acc[acc.length - 1];

    if (!anterior || anterior.dia !== dia) {
      let rotulo = dia;
      if (dia === hoje) rotulo = t('TICKET.ACTIVITY.TODAY');
      else if (dia === ontem) rotulo = t('TICKET.ACTIVITY.YESTERDAY');

      acc.push({ dia, rotulo, itens: [activity] });
    } else {
      anterior.itens.push(activity);
    }

    return acc;
  }, []);
});

const estaAberta = id => abertas.value.has(id);

const alternar = id => {
  const proximo = new Set(abertas.value);
  if (proximo.has(id)) proximo.delete(id);
  else proximo.add(id);
  abertas.value = proximo;
};

const autor = activity =>
  activity.user?.name || t('TICKET.ACTIVITY.SYSTEM_ACTOR');

// Nome e e-mail saem de uma frase so: os sinais < > sao pontuacao do texto, e
// soltos no template viram string nao traduzida.
const autorCompleto = activity =>
  activity.user?.email
    ? t('TICKET.ACTIVITY.ACTOR_WITH_EMAIL', {
        name: autor(activity),
        email: activity.user.email,
      })
    : autor(activity);

onMounted(() => store.dispatch('tickets/fetchActivities', props.ticketId));
</script>

<template>
  <div class="flex flex-col gap-3">
    <div v-if="isLoading" class="flex justify-center py-4">
      <Spinner />
    </div>
    <p v-else-if="!activities.length" class="text-sm text-n-slate-11">
      {{ t('TICKET.ACTIVITY.EMPTY') }}
    </p>

    <div v-else class="flex flex-col gap-5">
      <section v-for="grupo in grupos" :key="grupo.dia" class="flex flex-col">
        <span
          class="self-start px-2 py-0.5 mb-3 text-xs font-medium rounded bg-n-alpha-2 text-n-slate-11"
        >
          {{ grupo.rotulo }}
        </span>

        <!-- O trilho vertical corre pela borda esquerda, e cada entrada
             pendura o proprio icone nele. -->
        <ul
          class="flex flex-col gap-4 ltr:pl-3 rtl:pr-3 ltr:border-l rtl:border-r border-n-weak"
        >
          <li
            v-for="activity in grupo.itens"
            :key="activity.id"
            class="relative flex items-start gap-2.5 min-w-0"
          >
            <span
              class="flex items-center justify-center size-6 flex-shrink-0 rounded-full bg-n-amber-2 text-n-amber-11 ltr:-ml-[27px] rtl:-mr-[27px] mt-0.5 ring-4 ring-n-background"
            >
              <Icon
                :icon="ACTIVITY_ICONS[activity.activity_type] || 'i-lucide-dot'"
                class="size-3.5"
              />
            </span>

            <div class="flex flex-col min-w-0 gap-0.5 flex-1">
              <time class="text-xs text-n-slate-10">
                {{ dataHora(activity) }}
              </time>

              <p class="m-0 text-sm font-medium text-n-slate-12">
                {{ titulo(activity) }}
              </p>

              <p v-if="campo(activity)" class="m-0 text-sm text-n-slate-11">
                {{
                  t('TICKET.ACTIVITY.CHANGED_IN', { field: campo(activity) })
                }}
              </p>

              <button
                class="flex items-center gap-1 mt-1 text-sm cursor-pointer text-n-teal-11 hover:underline ltr:self-start rtl:self-end"
                :aria-expanded="estaAberta(activity.id)"
                @click="alternar(activity.id)"
              >
                <Icon
                  :icon="
                    estaAberta(activity.id) ? 'i-lucide-minus' : 'i-lucide-plus'
                  "
                  class="size-3.5"
                />
                {{ t('TICKET.ACTIVITY.MORE') }}
              </button>

              <div
                v-if="estaAberta(activity.id)"
                class="flex flex-col gap-3 p-3 mt-2 border rounded-lg border-n-weak bg-n-alpha-1"
              >
                <p class="m-0 text-sm font-medium text-n-slate-12">
                  {{
                    t('TICKET.ACTIVITY.DETAILS_TITLE', {
                      title: titulo(activity),
                    })
                  }}
                </p>

                <!-- Antes riscado, seta, depois. O valor antigo fica legivel de
                     proposito: e ele que explica o que mudou. -->
                <p
                  v-if="temValores(activity)"
                  class="m-0 text-sm break-words text-n-slate-12"
                >
                  <span v-if="campo(activity)" class="font-medium">
                    {{ campo(activity) }}:
                  </span>
                  <s v-if="activity.previous_value" class="text-n-slate-10">
                    {{ activity.previous_value }}
                  </s>
                  <Icon
                    v-if="activity.previous_value && activity.new_value"
                    icon="i-lucide-arrow-right"
                    class="inline-block mx-1 align-middle size-3.5 text-n-slate-10 rtl:rotate-180"
                  />
                  <span v-if="activity.new_value">
                    {{ activity.new_value }}
                  </span>
                  <span v-else-if="!activity.previous_value">
                    {{ vazio() }}
                  </span>
                </p>

                <p class="m-0 text-sm text-n-slate-11">
                  <span class="font-medium text-n-slate-12">
                    {{ t('TICKET.ACTIVITY.CHANGED_BY') }}
                  </span>
                  {{ autorCompleto(activity) }}
                </p>
              </div>
            </div>
          </li>
        </ul>
      </section>
    </div>
  </div>
</template>
