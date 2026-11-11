// Configuracao do fluxo de pausa por inatividade, compartilhada entre a Caixa de
// entrada (`inactivity_config`) e a Fila (`inactivity_pause_config`). As chaves
// sao as mesmas do backend (Inactivity::PauseConfig); vazio = padrao do sistema.

export const PAUSE_NUMBERS = [
  'pause_after',
  'pause_window',
  'max_pauses',
  'max_extension_minutes',
  'max_extensions',
];

export const PAUSE_TOGGLES = [
  { key: 'pause_enabled', default: false, label: 'ENABLED' },
  { key: 'keep_previous_agent', default: true, label: 'KEEP_PREVIOUS_AGENT' },
  {
    key: 'respect_working_hours',
    default: true,
    label: 'RESPECT_WORKING_HOURS',
  },
  { key: 'extension_enabled', default: true, label: 'EXTENSION_ENABLED' },
];

export const PAUSE_MESSAGES = [
  'pause_message',
  'resume_same_agent_message',
  'resume_queue_message',
  'resume_out_of_hours_message',
  'extension_message',
  'finalize_message',
  'decline_message',
];

// Config vinda da API -> estado do formulario.
export const pauseFromConfig = (config = {}) => {
  const pause = {};
  PAUSE_NUMBERS.forEach(key => {
    pause[key] = config[key] || '';
  });
  PAUSE_TOGGLES.forEach(({ key, default: fallback }) => {
    pause[key] = config[key] === undefined ? fallback : !!config[key];
  });
  PAUSE_MESSAGES.forEach(key => {
    pause[key] = config[key] || '';
  });
  return pause;
};

// Estado do formulario -> payload da API.
export const pauseToConfig = (pause = {}) => {
  const config = {};
  PAUSE_NUMBERS.forEach(key => {
    config[key] = pause[key] || null;
  });
  PAUSE_TOGGLES.forEach(({ key }) => {
    config[key] = !!pause[key];
  });
  PAUSE_MESSAGES.forEach(key => {
    config[key] = pause[key] || '';
  });
  return config;
};
