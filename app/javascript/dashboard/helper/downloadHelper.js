import fromUnixTime from 'date-fns/fromUnixTime';
import format from 'date-fns/format';

export const downloadCsvFile = (fileName, content) => {
  const contentType = 'data:text/csv;charset=utf-8;';
  const blob = new Blob([content], { type: contentType });
  const url = URL.createObjectURL(blob);

  const link = document.createElement('a');
  link.setAttribute('download', fileName);
  link.setAttribute('href', url);
  link.click();
  return link;
};

/**
 * Entrega ao navegador um arquivo que veio pronto do servidor.
 *
 * Serve para qualquer binario (xlsx, pdf), diferente de `downloadCsvFile`, que
 * monta o conteudo aqui. O nome vem do cabecalho Content-Disposition da
 * resposta quando ele existir, para que o servidor continue mandando no nome.
 * @param {Blob} blob conteudo recebido
 * @param {string} fallbackName nome usado quando a resposta nao trouxer um
 * @param {string} disposition cabecalho Content-Disposition, se houver
 * @returns {HTMLAnchorElement} o link usado para disparar o download
 */
export const downloadBlob = (blob, fallbackName, disposition = '') => {
  // O nome que o servidor mandou, quando ele mandou um.
  const match = /filename[^;=\n]*=(?:UTF-8'')?"?([^";\n]*)"?/i.exec(
    disposition
  );
  const url = URL.createObjectURL(blob);

  const link = document.createElement('a');
  link.setAttribute(
    'download',
    match ? decodeURIComponent(match[1]) : fallbackName
  );
  link.setAttribute('href', url);
  link.click();
  // Sem isto o blob fica preso na memoria da aba ate ela ser fechada.
  URL.revokeObjectURL(url);
  return link;
};

export const generateFileName = ({ type, to, businessHours = false }) => {
  let name = `${type}-report-${format(fromUnixTime(to), 'dd-MM-yyyy')}`;
  if (businessHours) {
    name = `${name}-business-hours`;
  }
  return `${name}.csv`;
};
