import {
  KINDS,
  SUBJECT_AREAS,
  STATUSES,
  STATUS_LABEL_COLORS,
  KIND_LABEL_COLORS,
  statusColor,
  kindColor,
  isFinished,
  kindOptions,
  subjectAreaOptions,
  statusOptions,
} from '../manifestationLabels';

// `Label.vue` valida `color` contra esta lista e, para qualquer outro valor,
// renderiza SEM fundo - foi assim que `green` e `violet` produziram crachás
// invisíveis no módulo de Tickets. Este teste é o que impede a repetição.
const CORES_ACEITAS = ['slate', 'amber', 'teal', 'ruby', 'blue', 'iris'];

describe('os rótulos do SAC', () => {
  it('gives every status a color the Label accepts', () => {
    STATUSES.forEach(status => {
      expect(CORES_ACEITAS).toContain(statusColor(status));
    });
  });

  it('gives every kind a color the Label accepts', () => {
    KINDS.forEach(kind => {
      expect(CORES_ACEITAS).toContain(kindColor(kind));
    });
  });

  // Nenhuma cor declarada fora da lista, nem nos mapas que não passam pelas
  // funções acima.
  it('declares no colour outside the allow-list', () => {
    Object.values({ ...STATUS_LABEL_COLORS, ...KIND_LABEL_COLORS }).forEach(
      cor => {
        expect(CORES_ACEITAS).toContain(cor);
      }
    );
  });

  // Um valor desconhecido não pode render crachá invisível: cai no neutro.
  it('falls back to a visible colour for an unknown value', () => {
    expect(statusColor('inventado')).toBe('slate');
    expect(kindColor(undefined)).toBe('slate');
  });

  describe('o encerramento', () => {
    it('treats completed and cancelled as finished', () => {
      expect(isFinished('completed')).toBe(true);
      expect(isFinished('cancelled')).toBe(true);
    });

    // Estes são os estados em que o cliente AINDA responde - dizer que estão
    // encerrados esconderia o campo de resposta dele.
    it('treats every other status as open', () => {
      ['received', 'under_review', 'in_progress', 'awaiting_customer'].forEach(
        status => {
          expect(isFinished(status)).toBe(false);
        }
      );
    });
  });

  describe('as opções dos selects', () => {
    const t = chave => `t:${chave}`;

    it('offers every kind, translated', () => {
      expect(kindOptions(t)).toEqual(
        KINDS.map(value => ({ value, label: `t:MANIFESTATION.KINDS.${value}` }))
      );
    });

    it('offers every subject area, translated', () => {
      expect(subjectAreaOptions(t).map(o => o.value)).toEqual(SUBJECT_AREAS);
    });

    it('offers every status, translated', () => {
      expect(statusOptions(t).map(o => o.value)).toEqual(STATUSES);
    });

    // As listas são as mesmas dos enums do servidor. Um valor a mais aqui
    // apareceria no formulário e seria recusado na gravação.
    it('matches the server enums', () => {
      expect(KINDS).toEqual([
        'suggestion',
        'complaint',
        'compliment',
        'improvement',
        'other',
      ]);
      expect(SUBJECT_AREAS).toEqual([
        'erp',
        'support',
        'agent',
        'implementation',
        'portal',
        'commercial',
        'other',
      ]);
      expect(STATUSES).toEqual([
        'received',
        'under_review',
        'in_progress',
        'awaiting_customer',
        'completed',
        'cancelled',
      ]);
    });
  });
});
