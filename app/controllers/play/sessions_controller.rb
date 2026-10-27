class Play::SessionsController < Play::BaseController
  skip_before_action :require_member, only: :create

  # Where the QR code leads. The code doesn't stay in the address bar, so it can't be read off the phone's screen.
  def create
    participation = Participation.find_by(access_token: params[:token].to_s)

    if participation
      sign_in participation
      redirect_to play_tournament_path(participation.tournament), notice: t(".signed_in", name: participation.player.name)
    else
      render :new, status: :not_found, locals: { invalid: true }
    end
  end

  def destroy
    sign_out @participation
    redirect_to play_tournament_path(@tournament), notice: t(".signed_out"), status: :see_other
  end
end
