import {
  imageKey,
  isImageFile,
  isMarkdownFile,
  listLocalImages,
  parseMarkdownArticle,
  replaceLocalImages,
} from '../markdownArticleImport';

describe('isMarkdownFile', () => {
  it('aceita .md e .markdown, em qualquer caixa', () => {
    expect(isMarkdownFile('manual.md')).toBe(true);
    expect(isMarkdownFile('Manual.MD')).toBe(true);
    expect(isMarkdownFile('guia.markdown')).toBe(true);
  });

  it('recusa o resto', () => {
    expect(isMarkdownFile('manual.pdf')).toBe(false);
    expect(isMarkdownFile('manual.md.exe')).toBe(false);
    expect(isMarkdownFile('')).toBe(false);
    expect(isMarkdownFile(undefined)).toBe(false);
  });
});

describe('parseMarkdownArticle', () => {
  it('usa o primeiro "# titulo" como titulo e o tira do conteudo', () => {
    const result = parseMarkdownArticle(
      '# Emitir nota em lote\n\nPasso 1: abra a tela.\n\n## Passo 2\nClique em emitir.\n',
      'qualquer.md'
    );

    expect(result.title).toBe('Emitir nota em lote');
    expect(result.content).toBe(
      'Passo 1: abra a tela.\n\n## Passo 2\nClique em emitir.'
    );
  });

  it('prefere o title: do cabecalho (front matter) e o remove', () => {
    const result = parseMarkdownArticle(
      '---\ntitle: "Manual do PDV"\nautor: Felipe\n---\n# Outro titulo\n\ntexto',
      'pdv.md'
    );

    expect(result.title).toBe('Manual do PDV');
    expect(result.content).toBe('# Outro titulo\n\ntexto');
  });

  it('sem titulo no texto, usa o nome do arquivo', () => {
    const result = parseMarkdownArticle(
      'So um paragrafo.',
      'manual-do_pedido-de-venda.md'
    );

    expect(result.title).toBe('manual do pedido de venda');
    expect(result.content).toBe('So um paragrafo.');
  });

  it('aceita BOM e quebra de linha do Windows', () => {
    const result = parseMarkdownArticle(
      '\uFEFF# Titulo\r\n\r\nCorpo\r\n',
      'a.md'
    );

    expect(result.title).toBe('Titulo');
    expect(result.content).toBe('Corpo');
  });

  it('nao confunde "#hashtag" ou titulo de nivel 2 com o titulo do artigo', () => {
    const result = parseMarkdownArticle('## Secao\n\n#sem-espaco', 'guia.md');

    expect(result.title).toBe('guia');
    expect(result.content).toBe('## Secao\n\n#sem-espaco');
  });

  it('arquivo vazio vira titulo do nome e conteudo vazio', () => {
    expect(parseMarkdownArticle('', 'vazio.md')).toEqual({
      title: 'vazio',
      content: '',
    });
  });
});

describe('imagens locais', () => {
  const texto =
    'Veja ![tela](./img/Print%201.PNG "legenda") e ![x](<pasta/minha foto.jpg>)\n\n' +
    '<img src="fotos\\logo.png" width="10"> ![web](https://site.com/a.png) ![d](data:image/png;base64,AAA) ![r](/rails/a.png)';

  it('isImageFile aceita so os tipos que a Central usa', () => {
    expect(isImageFile('a.PNG')).toBe(true);
    expect(isImageFile('a.jpeg')).toBe(true);
    expect(isImageFile('a.webp')).toBe(true);
    expect(isImageFile('a.svg')).toBe(false);
    expect(isImageFile('a.md')).toBe(false);
  });

  it('imageKey usa so o nome do arquivo, sem pasta, %20 ou caixa', () => {
    expect(imageKey('./img/Print%201.PNG')).toBe('print 1.png');
    expect(imageKey('<pasta/minha foto.jpg>')).toBe('minha foto.jpg');
    expect(imageKey('fotos' + String.fromCharCode(92) + 'logo.png?x=1')).toBe(
      'logo.png'
    );
    expect(imageKey('100%.png')).toBe('100%.png');
  });

  it('lista so imagens locais, sem repetir', () => {
    expect(listLocalImages(`${texto} ![de novo](./PRINT%201.png)`)).toEqual([
      'print 1.png',
      'minha foto.jpg',
      'logo.png',
    ]);
  });

  it('troca o caminho pelo endereco e mantem o resto', () => {
    const urls = {
      'print 1.png': 'https://dsconnect/a',
      'logo.png': 'https://dsconnect/b',
    };
    const result = replaceLocalImages(texto, key => urls[key]);

    expect(result).toContain('![tela](https://dsconnect/a "legenda")');
    expect(result).toContain('<img src="https://dsconnect/b" width="10">');
    // sem arquivo escolhido, o caminho original fica
    expect(result).toContain('![x](<pasta/minha foto.jpg>)');
    // endereco da internet, data: e caminho do site nao mudam
    expect(result).toContain('https://site.com/a.png');
    expect(result).toContain('data:image/png;base64,AAA');
    expect(result).toContain('![r](/rails/a.png)');
  });
});
