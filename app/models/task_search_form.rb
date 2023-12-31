class TaskSearchForm
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :sort_by, :string
  attribute :keyword, :string
  attribute :state, :string
  attribute :tag_name, :string

  def sort_task(user)
    tasks = user.tasks.preload(:tags)
    case sort_by
    when 'deadline'
      tasks.deadline
    when 'low'
      tasks.low_priority_first
    when 'high'
      tasks.high_priority_first
    else
      tasks.recent
    end
  end

  def narrow_down_by_state(sorted_tasks)
    case state
    when 'not_started'
      sorted_tasks.not_started
    when 'in_progress'
      sorted_tasks.in_progress
    when 'done'
      sorted_tasks.done
    end
  end

  def narrow_down_by_tag_name(sorted_tasks)
    sorted_tasks.tag(tag_name)
  end

  def search(user)
    sorted_tasks = sort_task(user)
    sorted_tasks = sorted_tasks.matches(keyword) if keyword.present?
    sorted_tasks = narrow_down_by_state(sorted_tasks) if state.present?
    sorted_tasks = narrow_down_by_tag_name(sorted_tasks) if tag_name.present?
    sorted_tasks
  end
end
