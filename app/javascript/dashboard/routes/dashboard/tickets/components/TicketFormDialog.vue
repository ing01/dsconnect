<script>
import NextButton from 'dashboard/components-next/button/Button.vue';

export default {
  components: {
    NextButton,
  },
  props: {
    ticket: {
      type: Object,
      default: null,
    },
    agents: {
      type: Array,
      default: () => [],
    },
    isSubmitting: {
      type: Boolean,
      default: false,
    },
  },
  emits: ['close', 'submit'],
  data() {
    return {
      title: this.ticket?.title || '',
      description: this.ticket?.description || '',
      priority: this.ticket?.priority || '',
      assigneeId: this.ticket?.assignee_id || '',
      titleError: '',
    };
  },
  computed: {
    isEdit() {
      return !!this.ticket;
    },
  },
  methods: {
    onClose() {
      this.$emit('close');
    },
    onSubmit() {
      if (!this.title.trim()) {
        this.titleError = this.$t('TICKET.FORM.TITLE.REQUIRED_ERROR');
        return;
      }

      this.$emit('submit', {
        title: this.title.trim(),
        description: this.description.trim(),
        priority: this.priority || null,
        assignee_id: this.assigneeId || null,
      });
    },
  },
};
</script>

<template>
  <div class="flex flex-col h-auto overflow-auto">
    <woot-modal-header
      :header-title="
        isEdit ? $t('TICKET.FORM.EDIT_TITLE') : $t('TICKET.FORM.ADD_TITLE')
      "
    />
    <form class="flex flex-wrap mx-0 px-8 pb-8" @submit.prevent="onSubmit">
      <woot-input
        v-model="title"
        class="w-full"
        :label="$t('TICKET.FORM.TITLE.LABEL')"
        :placeholder="$t('TICKET.FORM.TITLE.PLACEHOLDER')"
        :error="titleError"
        @input="titleError = ''"
      />
      <label class="w-full mb-3">
        <span class="text-sm text-n-slate-11">
          {{ $t('TICKET.FORM.DESCRIPTION.LABEL') }}
        </span>
        <textarea
          v-model="description"
          rows="3"
          class="w-full mt-1 rounded-xl border border-n-strong bg-transparent px-3 py-2 text-sm"
          :placeholder="$t('TICKET.FORM.DESCRIPTION.PLACEHOLDER')"
        />
      </label>

      <div class="flex w-full gap-3">
        <label class="w-1/2 mb-3">
          <span class="text-sm text-n-slate-11">
            {{ $t('TICKET.FORM.PRIORITY.LABEL') }}
          </span>
          <select
            v-model="priority"
            class="w-full mt-1 rounded-xl border border-n-strong bg-transparent px-3 py-2 text-sm"
          >
            <option value="">{{ $t('TICKET.FORM.PRIORITY.NONE') }}</option>
            <option value="low">{{ $t('TICKET.FORM.PRIORITY.LOW') }}</option>
            <option value="medium">
              {{ $t('TICKET.FORM.PRIORITY.MEDIUM') }}
            </option>
            <option value="high">{{ $t('TICKET.FORM.PRIORITY.HIGH') }}</option>
            <option value="urgent">
              {{ $t('TICKET.FORM.PRIORITY.URGENT') }}
            </option>
          </select>
        </label>

        <label class="w-1/2 mb-3">
          <span class="text-sm text-n-slate-11">
            {{ $t('TICKET.FORM.ASSIGNEE.LABEL') }}
          </span>
          <select
            v-model="assigneeId"
            class="w-full mt-1 rounded-xl border border-n-strong bg-transparent px-3 py-2 text-sm"
          >
            <option value="">{{ $t('TICKET.FORM.ASSIGNEE.NONE') }}</option>
            <option v-for="agent in agents" :key="agent.id" :value="agent.id">
              {{ agent.name }}
            </option>
          </select>
        </label>
      </div>

      <div class="flex items-center justify-end w-full gap-2 mt-6">
        <NextButton
          faded
          slate
          type="reset"
          :label="$t('TICKET.FORM.CANCEL')"
          @click.prevent="onClose"
        />
        <NextButton
          type="submit"
          :is-loading="isSubmitting"
          :label="isEdit ? $t('TICKET.FORM.UPDATE') : $t('TICKET.FORM.CREATE')"
        />
      </div>
    </form>
  </div>
</template>
