// Importacao de manuais escritos em Markdown (.md) para a Central de Ajuda. O artigo da
// Central ja guarda o conteudo em Markdown, entao o texto vai como esta; o que se descobre
// aqui e' o TITULO, que o artigo guarda a parte, e as IMAGENS locais, que precisam ser
// enviadas ao DSConnect para o artigo ter um endereco delas.

// Acima disto um .md deixa de ser um manual e vira outra coisa (ou um arquivo errado).
export const MAX_MARKDOWN_FILE_BYTES = 1024 * 1024;
// Uma imagem de manual (print de tela) passa raramente disto.
export const MAX_IMAGE_FILE_BYTES = 10 * 1024 * 1024;

const BOM = /^\uFEFF/;
const FRONT_MATTER = /^---\r?\n([\s\S]*?)\r?\n---[ \t]*(?:\r?\n|$)/;
// So conta como titulo do artigo o `# ...` que ABRE o texto: um `# comentario` dentro de um
// bloco de codigo, mais adiante, nao e' titulo.
const LEADING_HEADING = /^\s*#[ \t]+(.+?)[ \t]*#*[ \t]*(?:\r?\n|$)/;
// `![alt](caminho "titulo")` - o caminho pode vir entre <> quando tem espaco.
const MD_IMAGE = /(!\[[^\]]*\]\(\s*)(<[^>\n]+>|[^)\s]+)/g;
// `<img src="caminho">`
const HTML_IMAGE = /(<img\b[^>]*?\bsrc\s*=\s*)(["'])([^"'\n]+)\2/gi;

const unquote = value => value.trim().replace(/^(['"])(.*)\1$/, '$2');

const titleFromFileName = fileName =>
  String(fileName || '')
    .replace(/\.(md|markdown)$/i, '')
    .replace(/[-_]+/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();

/**
 * E' um arquivo Markdown pelo nome?
 * @param {string} fileName nome do arquivo
 * @returns {boolean} true para .md e .markdown
 */
export const isMarkdownFile = fileName =>
  /\.(md|markdown)$/i.test(fileName || '');

/**
 * E' uma imagem que a Central aceita, pelo nome?
 * @param {string} fileName nome do arquivo
 * @returns {boolean} true para png, jpg, jpeg, gif e webp
 */
export const isImageFile = fileName =>
  /\.(png|jpe?g|gif|webp)$/i.test(fileName || '');

/**
 * Extrai titulo e conteudo de um .md. O titulo vem, na ordem, do `title:` do cabecalho
 * (front matter), do `# ...` que abre o texto ou do nome do arquivo. O cabecalho e esse
 * `# ...` saem do conteudo: a Central ja mostra o titulo no topo do artigo e repeti-lo no
 * corpo deixaria dois titulos iguais.
 * @param {string} text conteudo do arquivo
 * @param {string} fileName nome do arquivo, usado quando o texto nao traz titulo
 * @returns {{title: string, content: string}} titulo e conteudo (Markdown) do artigo
 */
export const parseMarkdownArticle = (text, fileName = '') => {
  let body = String(text || '').replace(BOM, '');
  let title = '';

  const front = body.match(FRONT_MATTER);
  if (front) {
    const line = front[1].split(/\r?\n/).find(item => /^title\s*:/i.test(item));
    if (line) title = unquote(line.replace(/^title\s*:/i, ''));
    body = body.slice(front[0].length);
  }

  if (!title) {
    const heading = body.match(LEADING_HEADING);
    if (heading) {
      title = heading[1].trim();
      body = body.slice(heading[0].length);
    }
  }

  return {
    title: title || titleFromFileName(fileName) || 'Sem título',
    content: body.trim(),
  };
};

// Endereco da internet (http:, https:, data:...), do proprio site (/...) ou ancora: fica como
// esta. So o que parece um arquivo ao lado do .md precisa ser enviado.
const isLocalPath = path => !!path && !/^([a-z][a-z0-9+.-]*:|\/|#)/i.test(path);

/**
 * Chave de uma imagem: o nome do arquivo, em minusculas e sem a pasta. E' por ela que o
 * caminho do .md (`./img/Print%201.PNG`) encontra o arquivo escolhido (`print 1.png`), ja
 * que o navegador nao informa a pasta de onde o arquivo veio.
 * @param {string} path caminho como escrito no .md, ou nome de um arquivo
 * @returns {string} nome do arquivo normalizado
 */
export const imageKey = path => {
  let name = String(path || '')
    .replace(/^<|>$/g, '')
    .split(/[?#]/)[0]
    .split(/[\\/]/)
    .pop();
  try {
    name = decodeURIComponent(name);
  } catch (error) {
    // Nome com "%" solto: usa como veio.
  }
  return name.trim().toLowerCase();
};

/**
 * Troca o caminho de cada imagem local do texto. `resolve` recebe a chave da imagem e
 * devolve o endereco novo; sem retorno, o caminho original fica.
 * @param {string} content Markdown do artigo
 * @param {(key: string) => string|undefined} resolve endereco novo da imagem, se houver
 * @returns {string} Markdown com os caminhos trocados
 */
export const replaceLocalImages = (content, resolve) => {
  const swap = raw => {
    const path = raw.replace(/^<|>$/g, '');
    if (!isLocalPath(path)) return null;
    return resolve(imageKey(path)) || null;
  };

  return String(content || '')
    .replace(MD_IMAGE, (match, open, destination) => {
      const url = swap(destination);
      return url ? `${open}${url}` : match;
    })
    .replace(HTML_IMAGE, (match, open, quote, destination) => {
      const url = swap(destination);
      return url ? `${open}${quote}${url}${quote}` : match;
    });
};

/**
 * Imagens locais que o texto usa (sem repetir), pela chave.
 * @param {string} content Markdown do artigo
 * @returns {string[]} chaves das imagens que precisam de um arquivo
 */
export const listLocalImages = content => {
  const keys = new Set();
  replaceLocalImages(content, key => {
    keys.add(key);
    return undefined;
  });
  return Array.from(keys);
};
