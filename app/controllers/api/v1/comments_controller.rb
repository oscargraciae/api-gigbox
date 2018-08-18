class Api::V1::CommentsController < BaseController
  before_filter :auth, only: [:index, :create]

  def index
    @service = Service.find(params[:service_id])
    @comments = @service.comments.where(active: true).order(created_at: :desc).page(params[:page]).per(5)
    render json: @comments, status: :ok
  end

  def create
    @service = Service.find(params[:service_id])
    @comment = @service.comments.create(comment_params)
    render json: @comment, status: :ok
  end

  def destroy
    @comment = Comment.find(params[:id])
    if @comment.update_attribute(:active, false)
      render json: @comment, status: :ok
    else
      render json: {message: "No se pudo eliminar"}, status: :ok
    end
    
  end

  private
  def comment_params
    params.permit(:body, :user_id, :service_id, :page, :id)
  end
end
