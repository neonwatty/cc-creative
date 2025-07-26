class DocumentsController < ApplicationController
  before_action :set_document, only: [:show, :edit, :update, :destroy, :duplicate, :autosave]
  # Authorization is handled per action using Pundit

  def index
    @documents = policy_scope(Document).recent
  end

  def new
    @document = Current.user.documents.build
    authorize @document
  end

  def create
    @document = Current.user.documents.build(document_params)
    authorize @document
    
    if @document.save
      redirect_to @document, notice: 'Document was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    authorize @document
  end

  def edit
    authorize @document
  end

  def update
    authorize @document
    if @document.update(document_params)
      respond_to do |format|
        format.html { redirect_to @document, notice: 'Document was successfully updated.' }
        format.turbo_stream { render turbo_stream: turbo_stream_update_response }
        format.json { render json: { status: 'success', updated_at: @document.updated_at } }
      end
    else
      respond_to do |format|
        format.html { render :edit, status: :unprocessable_entity }
        format.turbo_stream { render turbo_stream: turbo_stream_error_response, status: :unprocessable_entity }
        format.json { render json: { status: 'error', errors: @document.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    authorize @document
    @document.destroy!
    redirect_to documents_url, notice: 'Document was successfully deleted.'
  end

  def duplicate
    authorize @document, :show?
    @new_document = @document.duplicate_for(Current.user)
    
    if @new_document.save
      redirect_to edit_document_url(@new_document), notice: 'Document was successfully duplicated.'
    else
      redirect_to @document, alert: 'Failed to duplicate document.'
    end
  end

  def autosave
    authorize @document, :update?
    if @document.update(autosave_params)
      render json: { status: 'saved', updated_at: @document.updated_at }
    else
      render json: { status: 'error', errors: @document.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def set_document
    @document = Document.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to documents_url, alert: 'Document not found.'
  end

  def document_params
    params.require(:document).permit(:title, :content, :description, :tag_list)
  end

  def autosave_params
    params.require(:document).permit(:content)
  end

  def turbo_stream_update_response
    [
      turbo_stream.replace("document_status", partial: "documents/status", locals: { document: @document, status: 'saved' }),
      turbo_stream.replace("document_last_saved", partial: "documents/last_saved", locals: { document: @document })
    ]
  end

  def turbo_stream_error_response
    turbo_stream.replace("document_status", partial: "documents/status", locals: { document: @document, status: 'error' })
  end

end