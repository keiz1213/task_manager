class TasksController < ApplicationController
  def index
    @tasks = Task.all
  end

  def new
    @task = Task.new
  end

  def create
    task = Task.new(task_params)
    task.save!
    redirect_to tasks_url, notice: "タスク: #{task.title}を登録しました"
  end

  private

  def task_params
    params.require(:task).permit(:title, :description, :priority, :deadline, :state)
  end
end
