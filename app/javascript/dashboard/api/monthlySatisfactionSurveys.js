import ApiClient from './ApiClient';

// Rota de SO LEITURA, do lado interno: quem grava e o Portal do Cliente (ver
// Api::V1::Client::MonthlySatisfactionSurveysController). `get`/`show` da
// classe base ja servem - a conta vem sozinha da URL, por isso nenhum metodo
// extra e' preciso aqui.
class MonthlySatisfactionSurveysAPI extends ApiClient {
  constructor() {
    super('monthly_satisfaction_surveys', { accountScoped: true });
  }
}

export default new MonthlySatisfactionSurveysAPI();
