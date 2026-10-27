# Members on their phones. The arbiter's login doesn't apply here: a member signs in to one tournament by scanning
# the QR code of their participation, and sees only that tournament.
class Play::BaseController < ApplicationController
  skip_before_action :authenticate
  before_action :require_member

  layout "play"

  private
    # Members come with whatever phone they have, not only the latest browsers.
    def any_browser?
      true
    end

    def require_member
      token = member_tokens[params[:tournament_id].to_s]
      @participation = Participation.find_by(tournament_id: params[:tournament_id], access_token: token) if token

      if @participation
        @tournament = @participation.tournament
      else
        render "play/sessions/new", status: :unauthorized
      end
    end

    # The codes this browser signed in with, by tournament id. They last long enough that a phone never needs
    # the QR code again in the middle of a tournament.
    def member_tokens
      cookies.encrypted[:member_tokens].presence || {}
    end

    def sign_in(participation)
      store_member_tokens member_tokens.merge(participation.tournament_id.to_s => participation.access_token)
    end

    def sign_out(participation)
      store_member_tokens member_tokens.except(participation.tournament_id.to_s)
    end

    def store_member_tokens(tokens)
      cookies.encrypted[:member_tokens] = { value: tokens, expires: 1.year, httponly: true }
    end
end
