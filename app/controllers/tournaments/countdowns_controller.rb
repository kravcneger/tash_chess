class Tournaments::CountdownsController < Tournaments::BaseController
  def create
    if @tournament.start_countdown(params[:minutes])
      redirect_back_or_to @tournament, notice: t(".started", count: params[:minutes].to_i)
    else
      redirect_back_or_to @tournament, alert: @tournament.errors.full_messages.to_sentence
    end
  end

  def destroy
    @tournament.cancel_countdown
    redirect_back_or_to @tournament, notice: t(".cancelled"), status: :see_other
  end
end
