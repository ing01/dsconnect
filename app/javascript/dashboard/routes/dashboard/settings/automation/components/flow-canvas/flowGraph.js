// Converte a lista plana de `steps` (a mesma que o backend roda) num grafo
// para o canvas visual: nodes posicionados e edges com a cor/rotulo certos.
//
// `steps` continua sendo a unica fonte de verdade - nada aqui e guardado
// separado do automation.flow_steps. A posicao de cada node vem do proprio
// step (`ui_position`, gravada so quando alguem arrasta o node) ou, na falta
// dela, de um layout automatico calculado na hora - por isso duas renderizacoes
// com os mesmos steps sempre caem no mesmo lugar, ate alguem mover algo.
import { MarkerType } from '@vue-flow/core';
import { findStepType } from '../../flowSteps';

export const NODE_WIDTH = 272;
const X_GAP = 360;
const Y_GAP = 150;

export const TRIGGER_NODE_ID = '__trigger__';
export const DEFAULT_HANDLE_ID = 'out';
export const TARGET_HANDLE_ID = 'in';
export const branchHandleId = branch => `branch__${branch}`;

const childrenOf = step =>
  [step.next, ...Object.values(step.branches || {})].filter(Boolean);

// A etapa de entrada e a que ninguem aponta para - normalmente a primeira,
// mas um fluxo montado fora de ordem (ou com a primeira etapa removida) pode
// deixar outra no papel de ponto de partida.
export const entryStepId = (steps = []) => {
  if (!steps.length) return null;
  const targeted = new Set(steps.flatMap(childrenOf));
  return steps.find(step => !targeted.has(step.id))?.id || steps[0].id;
};

// Layout em camadas: a coluna e a distancia (em saltos) da entrada, e dentro
// da coluna cada etapa pega a proxima linha livre - simples, deterministico,
// e le exatamente como o fluxo e narrado ("primeiro isso, dai aquilo").
export const autoLayoutPositions = (steps = []) => {
  const byId = new Map(steps.map(step => [step.id, step]));
  const positions = {};
  const nextRowInColumn = {};
  const visited = new Set();

  const visit = (id, column) => {
    if (!id || visited.has(id) || !byId.has(id)) return;
    visited.add(id);
    const row = nextRowInColumn[column] ?? 0;
    nextRowInColumn[column] = row + 1;
    positions[id] = { x: column * X_GAP, y: row * Y_GAP };
    childrenOf(byId.get(id)).forEach(childId => visit(childId, column + 1));
  };

  visit(entryStepId(steps), 0);
  // Etapas que nenhum `next`/branch alcanca (orfas) ainda precisam de um
  // lugar - entram sozinhas numa coluna nova em vez de ficar escondidas.
  steps.forEach(step => {
    if (!positions[step.id]) visit(step.id, 0);
  });

  return positions;
};

export const positionFor = (step, autoPositions) =>
  step.ui_position || autoPositions[step.id] || { x: 0, y: 0 };

export const buildNodes = (steps, { autoPositions, selectedId }) => {
  const entryId = entryStepId(steps);

  const triggerNode = {
    id: TRIGGER_NODE_ID,
    type: 'trigger',
    position: { x: 0, y: autoPositions[entryId]?.y ?? 0 },
    draggable: false,
    selectable: false,
    connectable: false,
    data: {},
  };
  // O resto do fluxo abre espaco a direita do node de gatilho, que fica fixo
  // na coluna 0 - evita o gatilho e a primeira etapa caindo um sobre o outro.
  const offsetX = NODE_WIDTH + 80;

  const stepNodes = steps.map(step => {
    const definition = findStepType(step.type);
    const base = positionFor(step, autoPositions);
    return {
      id: step.id,
      type: 'step',
      position: { x: base.x + offsetX, y: base.y },
      data: { step, definition },
      selected: step.id === selectedId,
    };
  });

  return [triggerNode, ...stepNodes];
};

export const buildEdges = steps => {
  const edges = [];
  const entryId = entryStepId(steps);

  if (entryId) {
    edges.push({
      id: `${TRIGGER_NODE_ID}->${entryId}`,
      source: TRIGGER_NODE_ID,
      sourceHandle: DEFAULT_HANDLE_ID,
      target: entryId,
      targetHandle: TARGET_HANDLE_ID,
      type: 'flowConnector',
      markerEnd: MarkerType.ArrowClosed,
      data: { kind: 'trigger' },
    });
  }

  steps.forEach(step => {
    if (step.next) {
      edges.push({
        id: `${step.id}->${DEFAULT_HANDLE_ID}->${step.next}`,
        source: step.id,
        sourceHandle: DEFAULT_HANDLE_ID,
        target: step.next,
        targetHandle: TARGET_HANDLE_ID,
        type: 'flowConnector',
        markerEnd: MarkerType.ArrowClosed,
        data: { kind: 'next', stepId: step.id },
      });
    }

    Object.entries(step.branches || {}).forEach(([branch, target]) => {
      if (!target) return;
      edges.push({
        id: `${step.id}->${branch}->${target}`,
        source: step.id,
        sourceHandle: branchHandleId(branch),
        target,
        targetHandle: TARGET_HANDLE_ID,
        type: 'flowConnector',
        markerEnd: MarkerType.ArrowClosed,
        data: { kind: 'branch', stepId: step.id, branch },
      });
    });
  });

  return edges;
};
