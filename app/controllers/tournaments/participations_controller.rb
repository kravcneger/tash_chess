class Tournaments::ParticipationsController < Tournaments::BaseController
  before_action :ensure_members_editable, except: :show
  before_action :set_participation, only: %i[ show destroy withdraw reinstate ]

  # The member's QR code, for the arbiter to show them; the neighbours in the members list are a tap away.
  def show
    members = @tournament.participations.joins(:player).includes(:player).merge(Player.by_rating).to_a
    index = members.index(@participation)
    @previous = members[index - 1] if index.positive?
    @next = members[index + 1]
  end

  def create
    players = Player.where(id: params[:player_ids]).where.not(id: @tournament.players.select(:id)).to_a

    if players.any?
      @tournament.enroll(players)
      redirect_to @tournament, notice: [ t(".added", count: players.size), late_entry_note(@tournament) ].compact.join(" ")
    else
      redirect_to @tournament, alert: t(".none_selected")
    end
  end

  def destroy
    if @tournament.unenroll(@participation)
      redirect_to @tournament, notice: t(".removed", name: @participation.player.name), status: :see_other
    else
      redirect_to @tournament, alert: @participation.errors.full_messages.to_sentence, status: :see_other
    end
  end

  def withdraw
    if @tournament.withdraw(@participation)
      redirect_to @tournament, notice: t(".withdrawn", name: @participation.player.name), status: :see_other
    else
      redirect_to @tournament, alert: @tournament.errors.full_messages.to_sentence, status: :see_other
    end
  end

  def reinstate
    if @tournament.reinstate(@participation)
      redirect_to @tournament, notice: t(".reinstated", name: @participation.player.name), status: :see_other
    else
      redirect_to @tournament, alert: @tournament.errors.full_messages.to_sentence, status: :see_other
    end
  end

  private
    def set_participation
      @participation = @tournament.participations.find(params[:id])
    end

    def ensure_members_editable
      unless @tournament.members_editable?
        redirect_to @tournament, alert: t("tournaments.participations.locked"), status: :see_other
      end
    end
end
