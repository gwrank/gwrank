module Administration
  class TeambuildTagsController < ApplicationController
    def index
      @team_build_tags = TeambuildTag.ordered
      @team_build_tag = TeambuildTag.new
    end

    def create
      @team_build_tag = TeambuildTag.new(teambuild_tag_params)
      if @team_build_tag.save
        redirect_to administration_teambuild_tags_path, notice: "Tag ajouté."
      else
        @team_build_tags = TeambuildTag.ordered
        flash.now[:alert] = @team_build_tag.errors.full_messages.to_sentence
        render :index, status: :unprocessable_entity
      end
    end

    def update
      @team_build_tag = TeambuildTag.find(params[:id])
      if @team_build_tag.update(teambuild_tag_params)
        redirect_to administration_teambuild_tags_path, notice: "Tag mis à jour."
      else
        redirect_to administration_teambuild_tags_path,
                    alert: @team_build_tag.errors.full_messages.to_sentence
      end
    end

    private

    def teambuild_tag_params
      params.require(:teambuild_tag).permit(:name, :position, :active)
    end
  end
end
