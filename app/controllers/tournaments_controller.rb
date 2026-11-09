class TournamentsController < ApplicationController
  before_action :set_tournament, except: %i[ index new create ]

  def index
    @tournaments = Tournament.ordered.includes(:participations)
  end

  def show
    @participations = @tournament.participations.joins(:player).includes(:player).merge(Player.by_rating)
    @available_players = Player.alphabetical.where.not(id: @tournament.participations.select(:player_id))
    @players_with_games = @tournament.fixed_games.pluck(:white_player_id, :black_player_id).flatten.compact.to_set
  end

  def new
    @tournament = Tournament.new(pairing_system: :swiss, rounds_count: 5, starts_on: Date.current)
  end

  def edit
  end

  def create
    @tournament = Tournament.new(tournament_params)

    if @tournament.save
      redirect_to @tournament, notice: t(".created")
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    if @tournament.update(tournament_params)
      redirect_to @tournament, notice: t(".updated")
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @tournament.destroy!
    redirect_to tournaments_path, notice: t(".destroyed", name: @tournament.name), status: :see_other
  end

  def start
    if @tournament.start
      redirect_to tournament_round_path(@tournament, @tournament.rounds.first), notice: t(".started")
    else
      redirect_to @tournament, alert: @tournament.errors.full_messages.to_sentence
    end
  end

  def finish
    if @tournament.finish
      redirect_to tournament_standings_path(@tournament), notice: t(".finished")
    else
      redirect_back_or_to @tournament, alert: @tournament.errors.full_messages.to_sentence
    end
  end

  def reset
    if @tournament.reset
      redirect_to @tournament, notice: t(".reopened")
    else
      redirect_back_or_to @tournament, alert: @tournament.errors.full_messages.to_sentence
    end
  end

  private
    def set_tournament
      @tournament = Tournament.find(params[:id])
    end

    def tournament_params
      permitted = %i[ name location starts_on rounds_count quiz_url ]
      permitted << :pairing_system if @tournament.nil? || @tournament.registration?
      params.expect(tournament: permitted)
    end
end
