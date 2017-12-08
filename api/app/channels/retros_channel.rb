# Be sure to restart your server when you modify this file.
# Action Cable runs in a loop that does not support auto reloading.
class RetrosChannel < ApplicationCable::Channel
  def self.broadcast(retro)
    broadcast_to retro, retro: retro.as_json(include: {items: {}, action_items: {}, archives: {only: :id}})
  end

  def self.broadcast_force_relogin(retro, originator_id)
    broadcast_to retro, command: 'force_relogin', payload: { originator_id: originator_id, retro: retro.as_json(only: :slug) }

    RetroSessionService.instance
        .get_retro_consumers(retro.id)
        .each do |uuid|
          ApplicationCable::Connection.disconnect(uuid)
          RetroSessionService.instance.remove_retro_consumer(retro.id, uuid)
        end
  end

  def subscribed
    retro = Retro.friendly.find(params[:retro_id])
    api_token = params[:api_token]
    return unless user_allowed_to_access_retro?(retro, api_token)

    RetroSessionService.instance.add_retro_consumer(retro.id, request_uuid)

    stream_for(retro, lambda do |message|
      transmit ActiveSupport::JSON.decode(message)
    end)
  end

  def unsubscribed
    retro = Retro.friendly.find(params[:retro_id])
    api_token = params[:api_token]
    return unless user_allowed_to_access_retro?(retro, api_token)

    RetroSessionService.instance.remove_retro_consumer(retro.id, request_uuid)
  end

  private

  def user_allowed_to_access_retro?(retro, api_token)
    return true unless retro.is_private?
    !retro.requires_authentication? || valid_token_provided?(retro, api_token)
  end

  def valid_token_provided?(retro, api_token)
    ActiveSupport::SecurityUtils.variable_size_secure_compare(
      api_token,
      retro.encrypted_password
    )
  end
end
