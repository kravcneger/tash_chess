class LocalesController < ApplicationController
  # Members switch the language too, from any phone and without the arbiter's login; all it does is set a cookie.
  skip_before_action :authenticate

  def update
    locale = params[:locale].to_s
    cookies.permanent[:locale] = locale if I18n.available_locales.map(&:to_s).include?(locale)

    redirect_back_or_to root_path, status: :see_other
  end

  private
    def any_browser?
      true
    end
end
