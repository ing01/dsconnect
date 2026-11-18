class ArticlePolicy < ApplicationPolicy
  def index?
    @account.users.include?(@user)
  end

  def update?
    @account_user.administrator?
  end

  def show?
    @account_user.administrator?
  end

  def edit?
    @account_user.administrator?
  end

  def create?
    @account_user.administrator?
  end

  def destroy?
    @account_user.administrator?
  end

  def reorder?
    @account_user.administrator?
  end

  # A arvore da Base de Conhecimento: qualquer um da conta consulta (a arvore e o artigo aberto no
  # painel central - a lista ja devolve o conteudo inteiro a todos); reorganizar segue a regra de
  # reordenar (administrador, e quem tem `knowledge_base_manage` pelo enterprise).
  def tree?
    index?
  end

  def move?
    reorder?
  end
end

ArticlePolicy.prepend_mod_with('ArticlePolicy')
