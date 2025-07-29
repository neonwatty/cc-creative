class ContextItemsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_document
  before_action :set_context_item, only: [:show, :edit, :update, :destroy]
  before_action :authorize_document_access

  def index
    @context_items = @document.context_items
                              .where(user: current_user)
                              .ordered
    
    if params[:search].present?
      @context_items = @context_items.where("title ILIKE ? OR content ILIKE ?", 
                                           "%#{params[:search]}%", 
                                           "%#{params[:search]}%")
    end
    
    if params[:item_type].present?
      @context_items = @context_items.by_type(params[:item_type])
    end

    respond_to do |format|
      format.html
      format.json { render json: @context_items }
    end
  end

  def show
    respond_to do |format|
      format.html
      format.json { render json: @context_item }
    end
  end

  def new
    @context_item = @document.context_items.build(user: current_user)
    @context_item.item_type = params[:item_type] if params[:item_type].present?
  end

  def create
    @context_item = @document.context_items.build(context_item_params)
    @context_item.user = current_user

    if @context_item.save
      if @context_item.item_type == 'version'
        # For versions, capture current document content
        @context_item.update(
          content: @document.content.to_s,
          title: "Version from #{Time.current.strftime('%B %d, %Y at %I:%M %p')}"
        )
      end

      respond_to do |format|
        format.html { redirect_to document_path(@document), notice: "#{@context_item.item_type.capitalize} created successfully." }
        format.turbo_stream
        format.json { render json: @context_item, status: :created }
      end
    else
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @context_item.errors, status: :unprocessable_entity }
      end
    end
  end

  def edit
  end

  def update
    if @context_item.update(context_item_params)
      respond_to do |format|
        format.html { redirect_to document_path(@document), notice: "#{@context_item.item_type.capitalize} updated successfully." }
        format.turbo_stream
        format.json { render json: @context_item }
      end
    else
      respond_to do |format|
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @context_item.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @context_item.destroy

    respond_to do |format|
      format.html { redirect_to document_path(@document), notice: "#{@context_item.item_type.capitalize} deleted successfully." }
      format.turbo_stream
      format.json { head :no_content }
    end
  end

  def reorder
    params[:item_ids].each_with_index do |id, index|
      @document.context_items.find(id).update(position: index + 1)
    end

    head :ok
  end

  def restore
    @context_item = @document.context_items.find(params[:id])
    
    if @context_item.item_type == 'version'
      # Restore the document content from this version
      @document.content = @context_item.content
      
      if @document.save
        # Create a new version to track this restoration
        @document.context_items.create!(
          user: current_user,
          item_type: 'version',
          title: "Restored from: #{@context_item.title}",
          content: @document.content.to_s
        )
        
        respond_to do |format|
          format.html { redirect_to edit_document_path(@document), notice: "Document restored from version." }
          format.json { render json: { success: true, message: "Version restored successfully" } }
        end
      else
        respond_to do |format|
          format.html { redirect_to edit_document_path(@document), alert: "Failed to restore version." }
          format.json { render json: { success: false, errors: @document.errors.full_messages }, status: :unprocessable_entity }
        end
      end
    else
      respond_to do |format|
        format.html { redirect_to edit_document_path(@document), alert: "Only versions can be restored." }
        format.json { render json: { success: false, error: "Only versions can be restored" }, status: :unprocessable_entity }
      end
    end
  end

  private

  def set_document
    @document = Document.find(params[:document_id])
  end

  def set_context_item
    @context_item = @document.context_items.find(params[:id])
  end

  def authorize_document_access
    authorize @document, :show?
  end

  def context_item_params
    params.require(:context_item).permit(:title, :content, :item_type, :position, :metadata)
  end
end
