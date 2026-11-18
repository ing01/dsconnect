import {
  typeOf,
  emptyAnswers,
  isMissing,
  missingFields,
  buildSubmissionBody,
} from '../formFields';

const fields = [
  { id: 'a', label: 'Motivo', field_type: 'short_text', required: true },
  { id: 'b', label: 'Módulos', fieldType: 'multiple_choice', required: true },
  { id: 'c', label: 'Anexo', field_type: 'file_upload', required: true },
  { id: 'd', label: 'Opcional', field_type: 'paragraph', required: false },
];

describe('formFields', () => {
  it('reads the type in snake_case and camelCase', () => {
    expect(typeOf(fields[0])).toBe('short_text');
    expect(typeOf(fields[1])).toBe('multiple_choice');
  });

  it('starts empty: a list for multiple choice, text for the rest', () => {
    expect(emptyAnswers(fields)).toEqual({ a: '', b: [], c: '', d: '' });
  });

  it('knows what is missing', () => {
    expect(
      missingFields(fields, emptyAnswers(fields), {}).map(f => f.id)
    ).toEqual(['a', 'b', 'c']);
    expect(
      missingFields(fields, { a: 'x', b: ['ERP'] }, { c: new Blob(['x']) })
    ).toEqual([]);
  });

  it('counts blank spaces as empty and never asks for an optional one', () => {
    expect(isMissing(fields[0], { a: '   ' })).toBe(true);
    expect(isMissing(fields[3], { d: '' })).toBe(false);
  });
});

describe('buildSubmissionBody', () => {
  it('sends JSON when there is no file', () => {
    const body = buildSubmissionBody({
      answers: { a: 'x' },
      extra: { ticket_display_id: '12' },
    });

    expect(body).toEqual({ ticket_display_id: '12', answers: { a: 'x' } });
  });

  it('sends multipart when there is a file, with lists as arrays and no blanks', () => {
    const file = new File(['x'], 'nota.txt', { type: 'text/plain' });
    const body = buildSubmissionBody({
      answers: { a: 'x', b: ['ERP', 'PDV'], c: '' },
      files: { doc: file },
      extra: { respondent_name: 'Maria', other: undefined },
    });

    expect(body).toBeInstanceOf(FormData);
    expect(body.get('answers[a]')).toBe('x');
    expect(body.getAll('answers[b][]')).toEqual(['ERP', 'PDV']);
    expect(body.has('answers[c]')).toBe(false);
    expect(body.get('files[doc]').name).toBe('nota.txt');
    expect(body.get('respondent_name')).toBe('Maria');
    expect(body.has('other')).toBe(false);
  });
});
