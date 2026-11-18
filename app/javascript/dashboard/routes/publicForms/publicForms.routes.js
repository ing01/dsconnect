/**
 * O formulario ABERTO da Central de Ajuda (sem login): `/app/forms/<codigo do link>`.
 *
 * Fica fora do painel e fora da Area do Cliente de proposito - nao pede sessao de ninguem. A guarda
 * em `routes/index.js` conhece o prefixo e deixa passar.
 */
const PublicFormPage = () => import('./PublicFormPage.vue');

export const PUBLIC_FORM_PATH_PREFIX = '/app/forms/';

export default {
  routes: [
    {
      path: `${PUBLIC_FORM_PATH_PREFIX}:token`,
      name: 'public_form',
      component: PublicFormPage,
    },
  ],
};
