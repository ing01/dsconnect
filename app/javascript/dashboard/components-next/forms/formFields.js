// O que e' comum a toda tela que PREENCHE um Formulario (o dialogo do artigo, a pagina do cliente
// logado e a pagina publica): ler o tipo da pergunta, comecar vazio e saber o que falta.
//
// As perguntas chegam do servidor em snake_case (`field_type`); depois de passar pelo
// camelcase-keys raso ficam como `fieldType` - os dois formatos sao aceitos.

export const typeOf = field => field.fieldType || field.field_type;

export const CHOICE_TYPES = ['single_choice', 'multiple_choice', 'dropdown'];

/** As respostas iniciais: lista vazia para multipla escolha, texto vazio para o resto. */
export const emptyAnswers = (fields = []) =>
  fields.reduce((answers, field) => {
    answers[field.id] = typeOf(field) === 'multiple_choice' ? [] : '';
    return answers;
  }, {});

/** A pergunta obrigatoria ainda sem resposta? */
export const isMissing = (field, answers = {}, files = {}) => {
  if (!field.required) return false;
  if (typeOf(field) === 'file_upload') return !files[field.id];
  if (typeOf(field) === 'multiple_choice') {
    return !(answers[field.id] || []).length;
  }
  return !String(answers[field.id] || '').trim();
};

/** As perguntas obrigatorias que faltam (para mostrar quais). */
export const missingFields = (fields = [], answers = {}, files = {}) =>
  fields.filter(field => isMissing(field, answers, files));

/**
 * O corpo do envio. Sem arquivo vai JSON; com arquivo vai multipart (o arquivo so' viaja assim).
 * `extra` leva o que nao e' pergunta (numero do chamado, nome, e-mail, campo isca).
 */
export const buildSubmissionBody = ({
  answers = {},
  files = {},
  extra = {},
} = {}) => {
  const hasFiles = Object.values(files).some(Boolean);
  if (!hasFiles) return { ...extra, answers };

  const body = new FormData();
  Object.entries(extra).forEach(([key, value]) => {
    if (value !== null && value !== undefined) body.append(key, value);
  });
  Object.entries(answers).forEach(([id, value]) => {
    if (Array.isArray(value)) {
      value.forEach(item => body.append(`answers[${id}][]`, item));
    } else if (value !== '' && value !== null && value !== undefined) {
      body.append(`answers[${id}]`, value);
    }
  });
  Object.entries(files).forEach(([id, file]) => {
    if (file) body.append(`files[${id}]`, file);
  });
  return body;
};
