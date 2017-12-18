class PlagiarismMatchLink < ActiveRecord::Base
  include LogHelper

  belongs_to :task
  belongs_to :other_task, class_name: 'Task'

  #
  # Ensure file is also deleted
  #
  before_destroy do |match_link|
    begin
      if match_link.task.group_task?
        other_tasks = match_link.task.group_submission.tasks.select { |t| t.id != match_link.task.id }

        other_tasks_using_file = other_tasks.select { |t| t.plagiarism_match_links.where(other_task_id: match_link.other_task_id).count > 0 }
        FileHelper.delete_plagarism_html(match_link) unless other_tasks_using_file.count > 0
      else # individual... so can delete file
        FileHelper.delete_plagarism_html(match_link)
      end
    rescue => e
      logger.error "Error deleting match link for task #{match_link.task.id}. Error: #{e.message}"
    end
  end

  after_destroy do |match_link|
    match_link.other_party.destroy if match_link.other_party
    match_link.task.recalculate_max_similar_pct
  end

  # TODO: Remove once max_pct_similar is deleted
  # #
  # # Update task's cache of pct similar
  # #
  # after_save do | match_link |
  #   task = match_link.task
  #   if (not match_link.dismissed) && task.max_pct_similar < match_link.pct
  #     task.max_pct_similar = match_link.pct
  #     task.save
  #   end
  # end

  def other_party
    PlagiarismMatchLink.where(task_id: other_task.id, other_task_id: task.id).first
  end

  def other_student
    other_task.student
  end

  def other_tutor
    other_task.project.main_tutor
  end

  delegate :student, to: :task

  def tutor
    task.project.main_tutor
  end

  def tutorial
    if task.project.tutorial.nil?
      'None'
    else
      task.project.tutorial.abbreviation
    end
  end

  def other_tutorial
    if other_task.project.tutorial.nil?
      'None'
    else
      other_task.project.tutorial.abbreviation
    end
  end
end
