# O que o cliente ve na aba "Tutoriais" da Area do Cliente: os modulos ativos (cards)
# e os tutoriais ativos da conta dele, na ordem definida pelo administrador.
# Tutorial de modulo oculto nao aparece; tutorial sem modulo (`module_id` nulo) vai
# para o card "Geral", montado na tela.
class Api::V1::Client::TutorialsController < Api::V1::Client::BaseController
  def index
    modules = Current.account.client_tutorial_modules.visible.ordered.with_attached_logo
    tutorials = Current.account.client_tutorials.visible.ordered.with_attached_video_file
                       .where(client_tutorial_module_id: [nil] + modules.map(&:id))

    render json: {
      modules: modules.map { |tutorial_module| module_json(tutorial_module) },
      tutorials: tutorials.map { |tutorial| tutorial_json(tutorial) }
    }
  end

  private

  def module_json(tutorial_module)
    {
      id: tutorial_module.id,
      name: tutorial_module.name,
      description: tutorial_module.description,
      logo_url: tutorial_module.logo_url
    }
  end

  def tutorial_json(tutorial)
    {
      id: tutorial.id,
      module_id: tutorial.client_tutorial_module_id,
      title: tutorial.title,
      description: tutorial.description,
      video_url: tutorial.video_url,
      video_file_url: tutorial.video_file_url
    }
  end
end
