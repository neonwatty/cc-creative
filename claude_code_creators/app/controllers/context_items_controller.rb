class ContextItemsController < ApplicationController
  before_action :set_document
  before_action :set_context_item, only: [ :show, :edit, :update, :destroy ]

  # GET /documents/:document_id/context_items
  # GET /documents/:document_id/context_items.json
  def index
    authorize @document, :show?

    @context_items = policy_scope(@document.context_items).includes(:user)

    # Apply search and filters
    if params[:q].present? || params[:item_type].present? || params[:date_from].present? || params[:date_to].present?
      @context_items = @context_items.filtered_search(
        query: params[:q],
        item_type: params[:item_type],
        date_from: params[:date_from],
        date_to: params[:date_to]
      )
    else
      @context_items = @context_items.recent
    end

    respond_to do |format|
      format.html # index.html.erb
      format.json {
        if params[:q].present? && params[:include_highlights] == "true"
          render json: @context_items.map { |item|
            {
              id: item.id,
              title: item.title,
              content: item.content,
              item_type: item.item_type,
              created_at: item.created_at,
              user: { id: item.user.id, name: item.user.name },
              highlights: item.search_highlights(params[:q])
            }
          }
        else
          render json: @context_items
        end
      }
    end
  end

  # GET /documents/:document_id/context_items/1
  # GET /documents/:document_id/context_items/1.json
  def show
    authorize @context_item

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @context_item }
    end
  end

  # GET /documents/:document_id/context_items/new
  def new
    @context_item = @document.context_items.build
    @context_item.user = current_user
    authorize @context_item
  end

  # GET /documents/:document_id/context_items/1/edit
  def edit
    authorize @context_item
  end

  # POST /documents/:document_id/context_items
  # POST /documents/:document_id/context_items.json
  def create
    @context_item = @document.context_items.build(context_item_params)
    @context_item.user = current_user
    authorize @context_item

    respond_to do |format|
      if @context_item.save
        format.html { redirect_to document_context_item_path(@document, @context_item),
                      notice: "Context item was successfully created." }
        format.json { render json: @context_item, status: :created }
        format.turbo_stream { render turbo_stream: turbo_stream.prepend("context_items",
                              partial: "context_items/context_item",
                              locals: { context_item: @context_item }) }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @context_item.errors, status: :unprocessable_entity }
        format.turbo_stream { render turbo_stream: turbo_stream.replace("new_context_item",
                              partial: "context_items/form",
                              locals: { context_item: @context_item }) }
      end
    end
  end

  # PATCH/PUT /documents/:document_id/context_items/1
  # PATCH/PUT /documents/:document_id/context_items/1.json
  def update
    authorize @context_item

    respond_to do |format|
      if @context_item.update(context_item_params)
        format.html { redirect_to document_context_item_path(@document, @context_item),
                      notice: "Context item was successfully updated." }
        format.json { render json: @context_item }
        format.turbo_stream { render turbo_stream: turbo_stream.replace(@context_item,
                              partial: "context_items/context_item",
                              locals: { context_item: @context_item }) }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @context_item.errors, status: :unprocessable_entity }
        format.turbo_stream { render turbo_stream: turbo_stream.replace("edit_context_item_#{@context_item.id}",
                              partial: "context_items/form",
                              locals: { context_item: @context_item }) }
      end
    end
  end

  # DELETE /documents/:document_id/context_items/1
  # DELETE /documents/:document_id/context_items/1.json
  def destroy
    authorize @context_item
    @context_item.destroy!

    respond_to do |format|
      format.html { redirect_to document_context_items_path(@document),
                    notice: "Context item was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
      format.turbo_stream { render turbo_stream: turbo_stream.remove(@context_item) }
    end
  end

  # POST /documents/:document_id/context_items/reorder
  def reorder
    authorize @document, :update?

    params[:item_ids].each_with_index do |id, index|
      @document.context_items.find(id).update_column(:position, index + 1)
    end

    head :ok
  end

  # GET /documents/:document_id/context_items/search
  # GET /documents/:document_id/context_items/search.json
  def search
    authorize @document, :show?

    # Use ranked search for better relevance
    @context_items = policy_scope(@document.context_items)

    if params[:q].present?
      @context_items = @context_items.ranked_search(params[:q])
    else
      @context_items = @context_items.includes(:user)
    end

    # Apply additional filters
    @context_items = @context_items.by_type(params[:item_type]) if params[:item_type].present?
    @context_items = @context_items.by_date_range(params[:date_from], params[:date_to])

    # Paginate results if needed
    @context_items = @context_items.page(params[:page]).per(params[:per_page] || 25) if defined?(Kaminari)

    respond_to do |format|
      format.html { render :index }
      format.json {
        results = @context_items.map do |item|
          item_json = {
            id: item.id,
            title: item.title,
            content: item.content,
            item_type: item.item_type,
            created_at: item.created_at,
            user: { id: item.user.id, name: item.user.name },
            document: { id: item.document.id, title: item.document.title }
          }

          # Add search rank if available
          item_json[:rank] = item.rank if item.respond_to?(:rank)

          # Add highlights if requested
          if params[:q].present? && params[:include_highlights] == "true"
            item_json[:highlights] = item.search_highlights(params[:q])
          end

          item_json
        end

        render json: {
          results: results,
          meta: {
            total: @context_items.respond_to?(:total_count) ? @context_items.total_count : @context_items.count,
            page: params[:page] || 1,
            per_page: params[:per_page] || 25,
            query: params[:q],
            filters: {
              item_type: params[:item_type],
              date_from: params[:date_from],
              date_to: params[:date_to]
            }
          }
        }
      }
      format.turbo_stream {
        render turbo_stream: turbo_stream.replace("context_items",
                            partial: "context_items/search_results",
                            locals: { context_items: @context_items, query: params[:q] })
      }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_document
      @document = Document.find(params[:document_id])
      authorize @document, :show?
    end

    def set_context_item
      @context_item = @document.context_items.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def context_item_params
      params.require(:context_item).permit(:content, :item_type, :title, :metadata)
    end
end
