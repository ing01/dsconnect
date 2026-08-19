<script>
import NextButton from 'dashboard/components-next/button/Button.vue';

export default {
  components: {
    NextButton,
  },
  props: {
    board: {
      type: Object,
      default: null,
    },
  },
  emits: ['close', 'submit'],
  data() {
    return {
      name: this.board?.name || '',
      error: '',
    };
  },
  computed: {
    isEdit() {
      return !!this.board;
    },
  },
  methods: {
    onClose() {
      this.$emit('close');
    },
    onSubmit() {
      if (!this.name.trim()) {
        this.error = this.$t('TICKET.BOARD_FORM.NAME.REQUIRED_ERROR');
        return;
      }
      this.$emit('submit', { name: this.name.trim() });
    },
  },
};
</script>

<template>
  <div class="flex flex-col h-auto overflow-auto">
    <woot-modal-header
      :header-title="
        isEdit
          ? $t('TICKET.BOARD_FORM.EDIT_TITLE')
          : $t('TICKET.BOARD_FORM.ADD_TITLE')
      "
    />
    <form class="flex flex-wrap mx-0 px-8 pb-8" @submit.prevent="onSubmit">
      <woot-input
        v-model="name"
        class="w-full"
        :label="$t('TICKET.BOARD_FORM.NAME.LABEL')"
        :placeholder="$t('TICKET.BOARD_FORM.NAME.PLACEHOLDER')"
        :error="error"
        @input="error = ''"
      />
      <div class="flex items-center justify-end w-full gap-2 mt-6">
        <NextButton
          faded
          slate
          type="reset"
          :label="$t('TICKET.BOARD_FORM.CANCEL')"
          @click.prevent="onClose"
        />
        <NextButton type="submit" :label="$t('TICKET.BOARD_FORM.SUBMIT')" />
      </div>
    </form>
  </div>
</template>
