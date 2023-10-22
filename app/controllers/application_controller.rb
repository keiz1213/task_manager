class ApplicationController < ActionController::Base
  include SessionsHelper

  before_action :set_search_form
  before_action :set_tag_names
  before_action :logged_in_user

  def set_search_form
    @search_form = TaskSearchForm.new(search_params)
  end

  def set_tag_names
    tags = Tag.joins(taggings: { task: :user }).where(users: { id: current_user.id })
    @tag_names = tags.map(&:name).uniq
  end

  def logged_in_user
    unless logged_in?
      store_location
      flash[:danger] = 'ログインしてください'
      redirect_to login_url, status: :see_other
    end
  end

  private

  def search_params
    params[:search].present? ? params.require(:search).permit(:keyword, :sort_by, :state, :tag_name) : {}
  end
end
