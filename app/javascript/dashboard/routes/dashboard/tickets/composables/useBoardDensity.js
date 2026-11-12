import { computed, ref } from 'vue';
import { useWindowSize } from '@vueuse/core';
import {
  isCompactBoard,
  readDensityPreference,
  writeDensityPreference,
} from '../helpers/boardDensity';

// A escolha de tamanho dos cards e' UMA so' para os quadros (Kanban por Mesa e Sprint
// ativo): fica aqui, fora da funcao, para as duas telas compartilharem o mesmo valor - o
// Kanban fica em KeepAlive e, sem isto, nao saberia que a escolha mudou no Sprint.
const preference = ref(readDensityPreference());

/**
 * Tamanho dos cards do quadro: segue a janela ate a pessoa escolher no botao.
 * @returns {{isCompact: import('vue').ComputedRef<boolean>, toggleDensity: () => void}}
 *   isCompact: o quadro deve usar o modo compacto; toggleDensity: troca e guarda a escolha
 */
export const useBoardDensity = () => {
  const { width, height } = useWindowSize();

  const isCompact = computed(() =>
    isCompactBoard(preference.value, width.value, height.value)
  );

  const toggleDensity = () => {
    preference.value = isCompact.value ? 'comfortable' : 'compact';
    writeDensityPreference(preference.value);
  };

  return { isCompact, toggleDensity };
};
