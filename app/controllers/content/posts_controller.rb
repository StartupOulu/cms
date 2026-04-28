module Content
  class PostsController < ApplicationController
    before_action :require_site
    before_action :set_post, only: %i[show edit update destroy]
    before_action :ensure_admin, only: %i[destroy]

    def index
      @posts = Current.site.content_posts.order(created_at: :desc)
    end

    def show
    end

    def new
      @post = Current.site.content_posts.new
    end

    def create
      @post = Current.site.content_posts.new(post_params)
      @post.user = Current.user

      if @post.save
        if params[:publish]
          begin
            @post.publish!
            redirect_to content_posts_path, notice: "Post published."
          rescue PublishError => e
            redirect_to edit_content_post_path(@post), alert: "Draft saved, but publish failed: #{e.message}"
          end
        else
          redirect_to edit_content_post_path(@post), notice: "Draft saved."
        end
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @post.update(post_params)
        if params[:publish]
          begin
            @post.publish!
            redirect_to content_posts_path, notice: "Post published."
          rescue PublishError => e
            @post.errors.add(:base, "Publish failed: #{e.message}")
            render :edit, status: :unprocessable_entity
          end
        else
          redirect_to edit_content_post_path(@post), notice: "Draft saved."
        end
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @post.destroy
      redirect_to content_posts_path, status: :see_other
    end

    private

    def set_post
      @post = Current.site.content_posts.find(params[:id])
    end

    def post_params
      p = params.require(:content_post).permit(:title, :slug, :description)
      raw = params.dig(:content_post, :blocks)
      p.merge(blocks: raw.present? ? JSON.parse(raw) : [])
    rescue JSON::ParserError
      p
    end

    def require_site
      redirect_to root_path, alert: "No site configured." unless Current.site
    end

    def ensure_admin
      redirect_to content_posts_path, alert: "Not authorized." unless Current.user.admin_of?(Current.site)
    end
  end
end
