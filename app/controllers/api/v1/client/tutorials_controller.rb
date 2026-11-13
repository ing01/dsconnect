# Os tutoriais que o cliente ve na aba "Tutoriais" da Area do Cliente: so' os
# ativos da conta dele, na ordem definida pelo administrador.
class Api::V1::Client::TutorialsController < Api::V1::Client::BaseController
  def index
    tutorials = Current.account.client_tutorials.visible.ordered.with_attached_video_file

    render json: tutorials.map { |tutorial|
      {
        id: tutorial.id,
        title: tutorial.title,
        description: tutorial.description,
        video_url: tutorial.video_url,
        video_file_url: tutorial.video_file_url
      }
    }
  end
end
