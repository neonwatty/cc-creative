class SubAgentChannel < ApplicationCable::Channel
  def subscribed
    sub_agent = SubAgent.find_by(id: params[:sub_agent_id])

    if sub_agent && authorized?(sub_agent)
      stream_from "sub_agent_#{sub_agent.id}"
    else
      reject
    end
  end

  def unsubscribed
    stop_all_streams
  end

  def receive(data)
    sub_agent = SubAgent.find_by(id: params[:sub_agent_id])
    return unless sub_agent && authorized?(sub_agent)

    if data["message"]
      service = SubAgentService.new(sub_agent)
      message = service.send_message(current_user, data["message"]["content"])

      if message
        broadcast_message(message)
      end
    end
  end

  def update_status(data)
    sub_agent = SubAgent.find_by(id: params[:sub_agent_id])
    return unless sub_agent && authorized?(sub_agent)

    if sub_agent.update(status: data["status"])
      ActionCable.server.broadcast("sub_agent_#{sub_agent.id}", {
        type: "status_change",
        status: data["status"]
      })
    end
  end

  def typing(data)
    sub_agent = SubAgent.find_by(id: params[:sub_agent_id])
    return unless sub_agent && authorized?(sub_agent)

    ActionCable.server.broadcast("sub_agent_#{sub_agent.id}", {
      type: "typing",
      user_id: current_user.id,
      user_name: current_user.name,
      typing: data["typing"]
    })
  end

  def update_context(data)
    sub_agent = SubAgent.find_by(id: params[:sub_agent_id])
    return unless sub_agent && authorized?(sub_agent)

    if sub_agent.update(context: data["context"])
      ActionCable.server.broadcast("sub_agent_#{sub_agent.id}", {
        type: "context_update",
        context: data["context"]
      })
    end
  end

  def delete_agent
    sub_agent = SubAgent.find_by(id: params[:sub_agent_id])
    return unless sub_agent && authorized?(sub_agent)

    ActionCable.server.broadcast("sub_agent_#{sub_agent.id}", {
      type: "agent_deleted",
      agent_id: sub_agent.id
    })
  end

  private

  def authorized?(sub_agent)
    sub_agent.user_id == current_user.id ||
    sub_agent.document.user_id == current_user.id
  end

  def broadcast_message(message)
    ActionCable.server.broadcast("sub_agent_#{message.sub_agent_id}", {
      message: {
        id: message.id,
        role: message.role,
        content: message.content,
        created_at: message.created_at,
        user_name: message.user.name,
        html: render_message_html(message)
      }
    })
  end

  def render_message_html(message)
    ApplicationController.renderer.render(
      partial: "sub_agent_messages/message",
      locals: { message: message }
    )
  rescue
    # Fallback if partial doesn't exist
    "<div class='message #{message.role}-message'>#{message.content}</div>"
  end
end
