class PortfolioEvidenceMailer < ActionMailer::Base
  @doubtfire_host = Doubtfire::Application.config.institution[:host]
  @unsubscribe_url = "https://#{@doubtfire_host}/#/home?notifications"

  def task_pdf_failed(project, tasks)
    return nil if project.nil? || tasks.nil? || tasks.length.zero?

    @student = project.student
    @project = project
    @tasks = tasks.sort_by { |t| t.task_definition.abbreviation }
    @tutor = project.main_tutor
    @convenor = project.main_convenor

    email_with_name = %("#{@student.name}" <#{@student.email}>)
    tutor_email = %("#{@tutor.name}" <#{@tutor.email}>)
    subject = "#{project.unit.name}: Task PDFs ready to view"
    mail(to: email_with_name, from: tutor_email, subject: subject)
  end

  def task_pdf_ready_message(project, tasks)
    return nil if project.nil? || tasks.nil? || tasks.length.zero?

    @student = project.student
    @project = project
    @tasks = tasks.sort_by { |t| t.task_definition.abbreviation }
    @tutor = project.main_tutor
    @convenor = project.main_convenor

    email_with_name = %("#{@student.name}" <#{@student.email}>)
    tutor_email = %("#{@tutor.name}" <#{@tutor.email}>)
    subject = "#{project.unit.name}: Task PDFs ready to view"
    mail(to: email_with_name, from: tutor_email, subject: subject)
  end

  def task_feedback_ready(project, tasks)
    return nil if project.nil? || tasks.nil? || tasks.length.zero?

    @student = project.student
    @project = project
    @tasks = tasks.sort_by { |t| t.task_definition.abbreviation }
    @tutor = project.main_tutor
    @has_comments = !@tasks.select { |t| t.is_last_comment_by?(@tutor) }.empty?
    return nil if @tutor.nil? || @student.nil?

    email_with_name = %("#{@student.name}" <#{@student.email}>)
    tutor_email = %("#{@tutor.name}" <#{@tutor.email}>)
    subject = "#{project.unit.name}: Feedback ready to review"
    mail(to: email_with_name, from: tutor_email, subject: subject)
  end

  def portfolio_ready(project)
    return nil if project.nil?

    @student = project.student
    @project = project
    @convenor = project.unit.convenors.first.user

    email_with_name = %("#{@student.name}" <#{@student.email}>)
    convenor_email = %("#{@convenor.name}" <#{@convenor.email}>)
    subject = "#{project.unit.name}: Portfolio ready to review"
    mail(to: email_with_name, from: convenor_email, subject: subject)
  end

  def portfolio_failed(project)
    return nil if project.nil?

    @student = project.student
    @project = project
    @convenor = project.unit.convenors.first.user

    email_with_name = %("#{@student.name}" <#{@student.email}>)
    convenor_email = %("#{@convenor.name}" <#{@convenor.email}>)
    subject = "#{project.unit.name}: Portfolio failed to compile"
    mail(to: email_with_name, from: convenor_email, subject: subject)
  end
end
