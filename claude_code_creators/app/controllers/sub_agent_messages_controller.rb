class SubAgentMessagesController < ApplicationController
  before_action :set_document_and_sub_agent

  def create
    authorize @sub_agent, :update?

    message_content = params[:message]&.strip

    if message_content.present?
      service = SubAgentService.new(@sub_agent)
      @message = service.send_message(current_user, message_content)

      if @message
        respond_to do |format|
          format.json { render json: { success: true, message: message_json(@message) } }
          format.turbo_stream {
            render turbo_stream: turbo_stream.append(
              "sub_agent_messages_#{@sub_agent.id}",
              partial: "sub_agent_messages/message",
              locals: { message: @message }
            )
          }
        end
      else
        respond_to do |format|
          format.json { render json: { error: "Failed to send message" }, status: :unprocessable_entity }
          format.turbo_stream { head :unprocessable_entity }
        end
      end
    else
      respond_to do |format|
        format.json { render json: { error: "Message cannot be blank" }, status: :unprocessable_entity }
        format.turbo_stream { head :unprocessable_entity }
      end
    end
  end

  private

  def set_document_and_sub_agent
    @document = Document.find(params[:document_id])
    @sub_agent = @document.sub_agents.find(params[:sub_agent_id])
    authorize @document, :show?
  end

  def message_json(message)
    {
      id: message.id,
      role: message.role,
      content: message.content,
      user: {
        id: message.user.id,
        name: message.user.name
      },
      created_at: message.created_at,
      formatted_time: message.created_at.strftime("%l:%M %p")
    }
  end
end
