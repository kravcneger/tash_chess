class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  # Pages meant for the hall TV opt out (see #any_browser?): TV browsers lag years behind.
  allow_browser versions: :modern, unless: :any_browser?

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  around_action :switch_locale
  before_action :authenticate

  private
    def any_browser?
      false
    end

    # One shared login for the whole app (HTTP Basic auth) from BASIC_AUTH_USERNAME and BASIC_AUTH_PASSWORD.
    # Unless both are set, the app is open to everyone.
    def authenticate
      name, password = ENV["BASIC_AUTH_USERNAME"].presence, ENV["BASIC_AUTH_PASSWORD"].presence
      return unless name && password

      http_basic_authenticate_or_request_with name:, password:, realm: "Tash Chess", message: t("authentication.denied")
    end

    # When players join a running tournament, says from which round they play.
    def late_entry_note(tournament)
      return unless tournament.in_progress?

      if !tournament.rounds_ahead?
        t("tournaments.late_entry.no_rounds_left")
      elsif tournament.round_robin?
        t("tournaments.late_entry.replanned", number: tournament.fixed_rounds_count + 1)
      else
        t("tournaments.late_entry.next_round")
      end
    end

    # Russian unless the visitor picked another language (there are no accounts, so the choice lives in a cookie).
    def switch_locale(&action)
      locale = cookies[:locale].presence_in(I18n.available_locales.map(&:to_s)) || I18n.default_locale
      I18n.with_locale(locale, &action)
    end
end
