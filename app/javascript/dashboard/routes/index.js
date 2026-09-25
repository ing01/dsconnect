import { createRouter, createWebHistory } from 'vue-router';

import { frontendURL } from '../helper/URLHelper';
import dashboard from './dashboard/dashboard.routes';
import clientArea, { CLIENT_PUBLIC_PATHS } from './client/client.routes';
import { CLIENT_PATH, hasClientSession } from '../helper/clientSession';
import store from 'dashboard/store';
import { validateLoggedInRoutes } from '../helper/routeHelpers';
import { isOnOnboardingView } from 'v3/helpers/RouteHelper';
import AnalyticsHelper from '../helper/AnalyticsHelper';

const ONBOARDING_STEPS = ['account_details', 'enrichment', 'inbox_setup'];
const routes = [...dashboard.routes, ...clientArea.routes];

// A Área do Cliente tem sessão própria (contato), não a do usuário interno.
const isClientRoute = to => String(to.path || '').startsWith(CLIENT_PATH);

const onboardingPath = step =>
  step === 'inbox_setup' ? 'onboarding/inbox-setup' : 'onboarding';

export const router = createRouter({ history: createWebHistory(), routes });

export const validateAuthenticateRoutePermission = async (to, next) => {
  const { isLoggedIn, getCurrentUser: user } = store.getters;

  // As rotas do cliente são avaliadas ANTES de qualquer checagem de usuário
  // interno: o contato não tem conta, papel nem onboarding, e as regras abaixo
  // o mandariam embora.
  if (isClientRoute(to)) {
    // A definicao de nova senha e a excecao: quem chega por ela justamente nao
    // consegue entrar, e exigir sessao ali deixaria o link do e-mail inutil.
    if (CLIENT_PUBLIC_PATHS.includes(to.path)) return next();

    if (!hasClientSession()) {
      window.location.assign('/app/login');
      return '';
    }
    return next();
  }

  // Sessão de cliente fora da área dele não vira acesso ao painel interno: sem
  // sessão de usuário, o destino é o login, como para qualquer visitante.
  if (!isLoggedIn) {
    window.location.assign('/app/login');
    return '';
  }

  const { accounts = [], account_id: accountId } = user;

  if (!accounts.length) {
    if (to.name === 'no_accounts') {
      return next();
    }
    return next(frontendURL('no-accounts'));
  }

  const routeAccountId = Number(to.params?.accountId || accountId);
  const userAccount = accounts.find(a => a.id === routeAccountId);
  const isAdmin = userAccount?.role === 'administrator';
  const isActive = userAccount?.status === 'active';
  const needsOnboarding =
    ONBOARDING_STEPS.includes(userAccount?.onboarding_step) &&
    isAdmin &&
    isActive;

  if (to.name === 'no_accounts' || !to.name) {
    const target = needsOnboarding
      ? onboardingPath(userAccount?.onboarding_step)
      : 'principal';
    return next(frontendURL(`accounts/${routeAccountId}/${target}`));
  }

  if (needsOnboarding && !isOnOnboardingView(to)) {
    return next(
      frontendURL(
        `accounts/${routeAccountId}/${onboardingPath(userAccount?.onboarding_step)}`
      )
    );
  }
  if (!needsOnboarding && isOnOnboardingView(to)) {
    return next(frontendURL(`accounts/${routeAccountId}/dashboard`));
  }

  const nextRoute = validateLoggedInRoutes(to, store.getters.getCurrentUser);
  return nextRoute ? next(frontendURL(nextRoute)) : next();
};

export const initalizeRouter = () => {
  // Vale também para a Área do Cliente: sem o cookie do usuário interno,
  // `setUser` não chama a API - apenas limpa o usuário e baixa
  // `authUIFlags.isFetching`, que é o que libera o App.vue a renderizar. Pular
  // esta linha deixaria a tela do cliente em branco para sempre.
  const userAuthentication = store.dispatch('setUser');

  router.beforeEach(async (to, _from, next) => {
    AnalyticsHelper.page(to.name || '', {
      path: to.path,
      name: to.name,
    });

    await userAuthentication;
    await validateAuthenticateRoutePermission(to, next, store);
  });
};

export default router;
