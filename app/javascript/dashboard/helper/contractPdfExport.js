// Exporta um Contrato como PDF sem nenhuma dependencia nova: monta um
// documento HTML autonomo numa aba nova e aciona o dialogo de impressao do
// navegador, onde "Salvar como PDF" ja e' um destino padrao em qualquer
// browser - nao precisa de gem/binario nenhum no servidor pra isso.
const formatMoney = value =>
  Number(value || 0).toLocaleString('pt-BR', {
    style: 'currency',
    currency: 'BRL',
  });

const formatDate = value => {
  if (!value) return null;
  // `value` vem como "YYYY-MM-DD" (input type=date) - parseia como local,
  // nao UTC, senao a data exibida pode ficar um dia atras dependendo do fuso.
  const [year, month, day] = value.split('-').map(Number);
  return new Date(year, month - 1, day).toLocaleDateString('pt-BR');
};

// Escapa texto vindo de dados do usuario (nome de empresa, grupo, etc.) antes
// de colocar no HTML montado a mao abaixo.
const escapeHtml = value =>
  String(value ?? '').replace(
    /[&<>"']/g,
    char =>
      ({
        '&': '&amp;',
        '<': '&lt;',
        '>': '&gt;',
        '"': '&quot;',
        "'": '&#39;',
      })[char]
  );

export const exportContractToPdf = (contract, t) => {
  const win = window.open('', '_blank');
  if (!win) return;

  const contractTypeLabel = contract.contractType
    ? t(`CONTRACTS.FORM.CONTRACT_TYPE.${contract.contractType.toUpperCase()}`)
    : t('CONTRACTS.PRINT.NOT_INFORMED');

  const companiesLabel = contract.companies?.length
    ? contract.companies.map(company => escapeHtml(company.name)).join(', ')
    : t('CONTRACTS.NO_COMPANIES');

  const responsibleLabel = contract.responsibleName
    ? escapeHtml(contract.responsibleName)
    : t('CONTRACTS.PRINT.NOT_INFORMED');

  const signedOnLabel = formatDate(contract.signedOn) || t('CONTRACTS.PRINT.NOT_SIGNED');

  const productRows = contract.lines
    .map(
      line => `
        <tr>
          <td>${escapeHtml(line.productGroupName)}</td>
          <td>${formatMoney(line.unitValue)}</td>
          <td>${escapeHtml(line.licensesQty)}</td>
          <td>${formatMoney(line.implementationFee)}</td>
        </tr>
      `
    )
    .join('');

  const generatedAt = new Date().toLocaleString('pt-BR');
  const heading = contract.description
    ? escapeHtml(contract.description)
    : escapeHtml(t('CONTRACTS.PRINT.TITLE'));

  win.document.write(`
    <!DOCTYPE html>
    <html>
      <head>
        <meta charset="utf-8" />
        <title>${heading} - ${companiesLabel}</title>
        <style>
          @page { margin: 2cm; }
          body { font-family: Arial, Helvetica, sans-serif; color: #1a1a1a; font-size: 12px; line-height: 1.6; }
          h1 { font-size: 18px; margin-bottom: 2px; }
          .muted { color: #777; font-size: 11px; margin-bottom: 24px; }
          .section { margin-bottom: 22px; }
          .section-title { font-size: 13px; font-weight: bold; border-bottom: 1px solid #ccc; padding-bottom: 4px; margin-bottom: 10px; }
          .row { display: flex; justify-content: space-between; gap: 12px; margin-bottom: 6px; }
          .row span:first-child { color: #555; }
          .row span:last-child { font-weight: 600; text-align: right; }
          table { width: 100%; border-collapse: collapse; margin-top: 4px; }
          th, td { border: 1px solid #ccc; padding: 6px 8px; text-align: left; font-size: 11px; }
          th { background: #f5f5f5; }
          .total { text-align: right; font-size: 15px; font-weight: bold; margin-top: 14px; }
          .signatures { display: flex; justify-content: space-between; margin-top: 70px; }
          .signature-block { width: 45%; text-align: center; }
          .signature-line { border-top: 1px solid #333; margin-top: 50px; padding-top: 6px; font-size: 11px; }
          .footer { margin-top: 50px; font-size: 10px; color: #999; text-align: center; }
          @media print {
            .footer { position: fixed; bottom: 0; left: 0; right: 0; }
          }
        </style>
      </head>
      <body>
        <h1>${heading} - ${companiesLabel}</h1>
        <p class="muted">${escapeHtml(t('CONTRACTS.PRINT.TITLE'))} #${contract.id} &middot; ${escapeHtml(t('CONTRACTS.PRINT.GENERATED_AT', { date: generatedAt }))}</p>

        <div class="section">
          <div class="row"><span>${t('CONTRACTS.FORM.RESPONSIBLE.LABEL')}</span><span>${responsibleLabel}</span></div>
          <div class="row"><span>${t('CONTRACTS.FORM.CONTRACT_TYPE.LABEL')}</span><span>${escapeHtml(contractTypeLabel)}</span></div>
          <div class="row"><span>${t('CONTRACTS.FORM.SIGNED_ON.LABEL')}</span><span>${escapeHtml(signedOnLabel)}</span></div>
          <div class="row"><span>${t('CONTRACTS.FORM.COMPANIES.LABEL')}</span><span>${companiesLabel}</span></div>
        </div>

        <div class="section">
          <div class="section-title">${t('CONTRACTS.FORM.PRODUCTS.LABEL')}</div>
          <table>
            <thead>
              <tr>
                <th>${t('CONTRACTS.PRINT.PRODUCT_TABLE.GROUP')}</th>
                <th>${t('CONTRACTS.PRINT.PRODUCT_TABLE.MONTHLY_VALUE')}</th>
                <th>${t('CONTRACTS.PRINT.PRODUCT_TABLE.LICENSES_QTY')}</th>
                <th>${t('CONTRACTS.PRINT.PRODUCT_TABLE.IMPLEMENTATION_FEE')}</th>
              </tr>
            </thead>
            <tbody>${productRows}</tbody>
          </table>
          <div class="total">${t('CONTRACTS.FORM.TOTAL_VALUE.LABEL')}: ${formatMoney(contract.totalValue)}</div>
        </div>

        <div class="signatures">
          <div class="signature-block"><div class="signature-line">${t('CONTRACTS.PRINT.SIGNATURE_CONTRACTOR')}</div></div>
          <div class="signature-block"><div class="signature-line">${t('CONTRACTS.PRINT.SIGNATURE_CONTRACTED')}</div></div>
        </div>
      </body>
    </html>
  `);
  win.document.close();
  win.focus();
  win.onload = () => win.print();
};
