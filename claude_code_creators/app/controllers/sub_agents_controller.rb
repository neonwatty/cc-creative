class SubAgentsController < ApplicationController
  before_action :set_document
  before_action :set_sub_agent, only: [:show, :edit, :update, :destroy, :activate, :complete, :pause, :merge]
  
  # GET /documents/:document_id/sub_agents
  # GET /documents/:document_id/sub_agents.json
  def index
    authorize @document, :show?
    
    @sub_agents = policy_scope(@document.sub_agents).includes(:user)
    
    # Apply filters
    @sub_agents = @sub_agents.by_agent_type(params[:agent_type]) if params[:agent_type].present?
    @sub_agents = @sub_agents.where(status: params[:status]) if params[:status].present?
    
    # Default ordering
    @sub_agents = @sub_agents.recent
    
    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @sub_agents.map { |agent| agent_json(agent) } }
      format.turbo_stream
    end
  end
  
  # GET /documents/:document_id/sub_agents/1
  # GET /documents/:document_id/sub_agents/1.json
  def show
    authorize @sub_agent
    
    @recent_messages = @sub_agent.recent_messages(limit: 20)
    
    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: agent_json(@sub_agent, include_messages: true) }
    end
  end
  
  # GET /documents/:document_id/sub_agents/new
  def new
    @sub_agent = @document.sub_agents.build
    @sub_agent.user = current_user
    authorize @sub_agent
  end
  
  # GET /documents/:document_id/sub_agents/1/edit
  def edit
    authorize @sub_agent
  end
  
  # POST /documents/:document_id/sub_agents
  # POST /documents/:document_id/sub_agents.json
  def create
    @sub_agent = @document.sub_agents.build(sub_agent_params)
    @sub_agent.user = current_user
    authorize @sub_agent
    
    respond_to do |format|
      if @sub_agent.save
        # Initialize sub-agent through service
        SubAgentService.new(@sub_agent).initialize_agent
        
        format.html { 
          redirect_to document_sub_agent_path(@document, @sub_agent), 
          notice: 'Sub-agent was successfully created and initialized.' 
        }
        format.json { render json: agent_json(@sub_agent), status: :created }
        format.turbo_stream { 
          render turbo_stream: turbo_stream.prepend('sub_agents', 
                              partial: 'sub_agents/sub_agent', 
                              locals: { sub_agent: @sub_agent }) 
        }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @sub_agent.errors, status: :unprocessable_entity }
        format.turbo_stream { 
          render turbo_stream: turbo_stream.replace('new_sub_agent', 
                              partial: 'sub_agents/form', 
                              locals: { sub_agent: @sub_agent }) 
        }
      end
    end
  end
  
  # PATCH/PUT /documents/:document_id/sub_agents/1
  # PATCH/PUT /documents/:document_id/sub_agents/1.json
  def update
    authorize @sub_agent
    
    respond_to do |format|
      if @sub_agent.update(sub_agent_params)
        format.html { 
          redirect_to document_sub_agent_path(@document, @sub_agent), 
          notice: 'Sub-agent was successfully updated.' 
        }
        format.json { render json: agent_json(@sub_agent) }
        format.turbo_stream { 
          render turbo_stream: turbo_stream.replace(@sub_agent, 
                              partial: 'sub_agents/sub_agent', 
                              locals: { sub_agent: @sub_agent }) 
        }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @sub_agent.errors, status: :unprocessable_entity }
        format.turbo_stream { 
          render turbo_stream: turbo_stream.replace("edit_sub_agent_#{@sub_agent.id}", 
                              partial: 'sub_agents/form', 
                              locals: { sub_agent: @sub_agent }) 
        }
      end
    end
  end
  
  # DELETE /documents/:document_id/sub_agents/1
  # DELETE /documents/:document_id/sub_agents/1.json
  def destroy
    authorize @sub_agent
    @sub_agent.destroy!
    
    respond_to do |format|
      format.html { 
        redirect_to document_sub_agents_path(@document), 
        notice: 'Sub-agent was successfully destroyed.', 
        status: :see_other 
      }
      format.json { head :no_content }
      format.turbo_stream { render turbo_stream: turbo_stream.remove(@sub_agent) }
    end
  end
  
  # POST /documents/:document_id/sub_agents/1/activate
  def activate
    authorize @sub_agent, :update?
    
    service = SubAgentService.new(@sub_agent)
    
    if service.activate
      respond_to do |format|
        format.html { 
          redirect_to document_sub_agent_path(@document, @sub_agent), 
          notice: 'Sub-agent activated successfully.' 
        }
        format.json { render json: agent_json(@sub_agent) }
        format.turbo_stream { 
          render turbo_stream: [
            turbo_stream.replace(@sub_agent, 
                                partial: 'sub_agents/sub_agent', 
                                locals: { sub_agent: @sub_agent }),
            turbo_stream.replace("sub_agent_status_#{@sub_agent.id}", 
                                partial: 'sub_agents/status_badge', 
                                locals: { sub_agent: @sub_agent })
          ]
        }
      end
    else
      respond_to do |format|
        format.html { 
          redirect_to document_sub_agent_path(@document, @sub_agent), 
          alert: 'Failed to activate sub-agent.' 
        }
        format.json { 
          render json: { error: 'Failed to activate sub-agent' }, 
          status: :unprocessable_entity 
        }
      end
    end
  end
  
  # POST /documents/:document_id/sub_agents/1/complete
  def complete
    authorize @sub_agent, :update?
    
    service = SubAgentService.new(@sub_agent)
    
    if service.complete
      respond_to do |format|
        format.html { 
          redirect_to document_sub_agent_path(@document, @sub_agent), 
          notice: 'Sub-agent completed successfully.' 
        }
        format.json { render json: agent_json(@sub_agent) }
        format.turbo_stream { 
          render turbo_stream: [
            turbo_stream.replace(@sub_agent, 
                                partial: 'sub_agents/sub_agent', 
                                locals: { sub_agent: @sub_agent }),
            turbo_stream.replace("sub_agent_status_#{@sub_agent.id}", 
                                partial: 'sub_agents/status_badge', 
                                locals: { sub_agent: @sub_agent })
          ]
        }
      end
    else
      respond_to do |format|
        format.html { 
          redirect_to document_sub_agent_path(@document, @sub_agent), 
          alert: 'Failed to complete sub-agent.' 
        }
        format.json { 
          render json: { error: 'Failed to complete sub-agent' }, 
          status: :unprocessable_entity 
        }
      end
    end
  end
  
  # POST /documents/:document_id/sub_agents/1/pause
  def pause
    authorize @sub_agent, :update?
    
    @sub_agent.pause!
    
    respond_to do |format|
      format.html { 
        redirect_to document_sub_agent_path(@document, @sub_agent), 
        notice: 'Sub-agent paused.' 
      }
      format.json { render json: agent_json(@sub_agent) }
      format.turbo_stream { 
        render turbo_stream: [
          turbo_stream.replace(@sub_agent, 
                              partial: 'sub_agents/sub_agent', 
                              locals: { sub_agent: @sub_agent }),
          turbo_stream.replace("sub_agent_status_#{@sub_agent.id}", 
                              partial: 'sub_agents/status_badge', 
                              locals: { sub_agent: @sub_agent })
        ]
      }
    end
  end
  
  # POST /documents/:document_id/sub_agents/1/merge
  def merge
    authorize @sub_agent, :update?
    
    merge_params = params.permit(:merge_type, :position, :separator)
    
    service = SubAgentService.new(@sub_agent)
    
    if service.merge_to_document(merge_params)
      respond_to do |format|
        format.html { 
          redirect_to document_path(@document), 
          notice: 'Sub-agent content merged successfully.' 
        }
        format.json { render json: { success: true } }
        format.turbo_stream { 
          render turbo_stream: [
            turbo_stream.replace(@sub_agent, 
                                partial: 'sub_agents/sub_agent', 
                                locals: { sub_agent: @sub_agent }),
            turbo_stream.update("document_content", 
                               partial: 'documents/content', 
                               locals: { document: @document })
          ]
        }
      end
    else
      respond_to do |format|
        format.html { 
          redirect_to document_sub_agent_path(@document, @sub_agent), 
          alert: 'Failed to merge sub-agent content.' 
        }
        format.json { 
          render json: { error: 'Failed to merge content' }, 
          status: :unprocessable_entity 
        }
      end
    end
  end
  
  private
  
  def set_document
    @document = Document.find(params[:document_id])
    authorize @document, :show?
  end
  
  def set_sub_agent
    @sub_agent = @document.sub_agents.find(params[:id])
  end
  
  def sub_agent_params
    params.require(:sub_agent).permit(:agent_type, :name, :metadata)
  end
  
  def agent_json(agent, include_messages: false)
    json = {
      id: agent.id,
      name: agent.name,
      agent_type: agent.agent_type,
      agent_type_label: agent.agent_type_label,
      status: agent.status,
      status_badge_color: agent.status_badge_color,
      external_id: agent.external_id,
      metadata: agent.metadata,
      user: {
        id: agent.user.id,
        name: agent.user.name
      },
      document: {
        id: agent.document.id,
        title: agent.document.title
      },
      message_count: agent.message_count,
      created_at: agent.created_at,
      updated_at: agent.updated_at
    }
    
    if include_messages
      json[:recent_messages] = agent.recent_messages.map do |message|
        {
          id: message.id,
          role: message.role,
          content: message.content,
          created_at: message.created_at
        }
      end
    end
    
    json
  end
end