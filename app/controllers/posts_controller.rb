class PostsController < ApplicationController
  before_action :set_post, only: [:show, :update]

  # GET /posts
  def index
    days_ago = params[:days_ago].to_i
    today = Time.zone.today.to_time

    @posts = if days_ago > 0
      Post.where('created_at >= ? AND created_at < ?', today - days_ago.days, today - (days_ago - 1).days)
    else
      Post.where('created_at >= ?', today)
    end.where(is_active: true).order('payout_value DESC')
    # NOTE: DB indices on `is_active`, `payout_value` are omitted as intended as the number of records on daily posts is small

    render json: @posts
  end

  # GET /posts/@:author/:permlink
  def show
    render json: @post
  end

  # GET /posts/exists
  def exists
    unless valid_web_url?(params[:url])
      render json: { result: 'INVALID' } and return
    end

    if Post.exists?(url: similar_urls(params[:url]))
      render json: { result: 'ALREADY_EXISTS' }
    else
      render json: { result: 'OK' }
    end
  end

  # POST /posts
  def create
    @post = Post.new(post_params)

    if @post.save
      render json: @post, status: :created
    else
      render json: { error: @post.errors.full_messages.first }, status: :unprocessable_entity
    end
  end

  # TODO:
  # Here we just assume users' data is always correct
  # We need to double check them later and potentially need some blacklist controls for abusing users
  # Because this can actually manipulate our sites' rankings
  # PATCH /posts/@:author/:permlink
  def update
    if @post.update(post_update_params)
      render json: { result: 'OK' }
    else
      render json: { error: 'UNPROCESSABLE_ENTITY' }, status: :unprocessable_entity
    end
  end

  private
    def set_post
      @post = Post.find_by(author: params[:author], permlink: params[:permlink])
      render_404 and return unless @post || !@post.active?
    end

    def post_params
      params.require(:post).permit(:author, :url, :title, :tagline, :permlink, :is_active, tags: [],
        beneficiaries: [ :account, :weight ],
        images: [ :id, :name, :link, :width, :height, :type, :deletehash ])
    end

    def post_update_params
      params.require(:post).permit(:payout_value, :children, active_votes: [ :voter, :weight, :rshares, :percent, :reputation, :time ])
    end

    def valid_web_url?(uri)
      uri = URI.parse(uri) and !uri.host.nil? and ['http', 'https'].include?(uri.scheme)
    rescue URI::InvalidURIError
      false
    end

    # Returns canonical urls of given url
    # e.g.
    # IN: 'https://facebook.com' (or any of outputs)
    # OUT: [ 'https://facebook.com', 'http://facebook.com', 'https://www.facebook.com', 'http://www.facebook.com' ]
    def similar_urls(url)
      stripped = url.gsub(/^https?:\/\/(www\.)?/, '')
      [
        "https://#{stripped}",
        "https://www.#{stripped}",
        "http://#{stripped}",
        "http://www.#{stripped}"
      ]
    end
end