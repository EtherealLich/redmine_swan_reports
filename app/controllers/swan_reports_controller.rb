#!/bin/env ruby
# encoding: utf-8

class SwanReportsController < ApplicationController
  unloadable
  
    
  def index
    render "index"
  end
  
  # Отчет о работе сотрудника
  def user_work
    @user_groups = Setting.plugin_redmine_swan_reports['user_groups']
    @groups = Group.where(:id => @user_groups.values).compact.sort.to_a.uniq
    @users = User.includes(:groups).where(:status => 1).where(:groups_users => {'id' => @user_groups.values}).compact.sort.to_a.uniq
    @user_id = params[:user_id] || User.current.id
    
    if request.post?
      @start_date = params['start_date']
      @end_date = params['end_date']
      @work_entries = WorkEntry.includes(:issue, :activity, :issue => :status).where(:spent_on => @start_date..@end_date, :user_id => @user_id).order(:spent_on, 'issues.id')
      completed_issues = [] # список завершенных задач, чтобы считать вернувшиеся
      @work_entries.each do |work_entry|
        if !work_entry.to_drop
          # ищем записи по той же задаче с той же датой и активностью, не совпадающие с этой
          doubles = @work_entries.select{|e| e.issue && work_entry.issue_id == e.issue_id && work_entry.spent_on == e.spent_on && work_entry.activity_id == e.activity_id && e.id != work_entry.id}
          doubles.each do |double|
            # копируем из них данные и помечаем на удаление
            work_entry.hours += double.hours
            work_entry.comments += "<br/>" + double.comments
            double.to_drop = true
          end
          
          if work_entry.issue
            if completed_issues.include? work_entry.issue.id # уже была задача, считаем вернувшейся
              work_entry.before_status = '↔'
            elsif work_entry.user_was_assigned_before_date Time.parse(@start_date) # назначена до даты
              work_entry.before_status = '→'
            elsif work_entry.user_was_assigned_after_date Time.parse(@start_date) # новая задача назначена после даты
              work_entry.before_status = '↗'
            else
              work_entry.before_status = '☺' # задачи вообще не стояло
            end
            if !work_entry.user_assigned_at_end_of_day # если задача перестала стоять на конец дня, то считаем завершенной
              completed_issues.push(work_entry.issue.id)
              work_entry.after_status = '↘'
            end
            work_entry.css_class = ''
            if work_entry.issue.priority_id == 7 # немедленные задачи
              work_entry.css_class += " immediate"
            end
            
            if work_entry.issue.custom_field_values.detect {|f| f.custom_field_id == 13 }.value.to_s == "1" # проектные задачи
              work_entry.css_class += " project"
            end
            
            work_entry.overdue = (work_entry.due_date_on_date == '' || (work_entry.due_date_on_date < work_entry.spent_on) ) # превышение фактической даты над плановой
            work_entry.overwork = (work_entry.spent_hours_user_on_date > work_entry.plan_hours) # превышение фактическими трудозатратами плановых
            
            if work_entry.issue.project.identifier == 'other-activity' # по проекту Другая активность убираем все css классы, делаем серым
              work_entry.css_class = " other_activity"
            end
          end
        end
      end
      # удаляем все повторные записи
      @work_entries.delete_if {|e| e.to_drop}
      
      @end_date_end_of_day = Time.parse(@end_date).end_of_day
      where_sql = %>
        ( 
          exists(
            SELECT 1
            FROM #{Journal.table_name}
            inner join #{JournalDetail.table_name} on 
              #{Journal.table_name}.id = #{JournalDetail.table_name}.journal_id
              and #{JournalDetail.table_name}.property = 'attr'
              and #{JournalDetail.table_name}.prop_key = 'assigned_to_id'
              and (#{JournalDetail.table_name}.value = '#{@user_id}' or #{JournalDetail.table_name}.old_value = '#{@user_id}')
            WHERE 
              #{Journal.table_name}.journalized_type='Issue'
              and #{Journal.table_name}.journalized_id = #{Issue.table_name}.id
              and #{Journal.table_name}.created_on between #{Issue.table_name}.created_on and '#{@end_date_end_of_day}'
          ) or #{Issue.table_name}.assigned_to_id =  #{@user_id}
        )
      >

      # берем все открытые на конец периода задачи, в которых когда-либо был назначен пользователь
      # Сразу одним запросом проверить пользователя на дату конца не получается, коррелирующий подзапрос с сортировкой оказывается настолько сложным, что не выполняется
      @issues_list = IssueExt.includes(:project, :tracker, :status, :time_entries).where(:projects => {:status => 1}).where("coalesce(#{Issue.table_name}.closed_on, '2030-01-01') > '#{@end_date_end_of_day}'").where(where_sql) 
      
      # проходим по списку и берем только задачи назначенные на пользователя к концу отчетного срока
      @planned_issues = @issues_list.select {|issue| IssueExt.get_periodic_value_on_time(IssueExt.issue_field_periodics(issue, 'assigned_to_id'), @end_date_end_of_day) == @user_id }
      
      # Расставляем стрелки и прочие css классы
      @planned_issues.each do |issue|
        issue.css_class = ''
        if issue.priority_id == 7 # немедленные задачи
          issue.css_class += " immediate"
        end
        
        if issue.custom_field_values.detect {|f| f.custom_field_id == 13 }.value.to_s == "1" # проектные задачи
          issue.css_class += " project"
        end
        
        if issue.project.identifier == 'other-activity' # по проекту Другая активность убираем все css классы, делаем серым
          issue.css_class = " other_activity"
        end
        
        issue.overwork = (issue.spent_hours_user_on_date(@end_date_end_of_day, @user_id).to_f > issue.user_plan_hours_on_date(@end_date_end_of_day, @user_id).to_f) # превышение фактическими трудозатратами плановых
        
        if completed_issues.include? issue.id # уже была задача, считаем вернувшейся
          issue.plan_status = '↔'
        elsif issue.user_was_assigned_after_date Time.parse(@start_date), @user_id # новая задача назначена после даты
          issue.plan_status = '↗'
        else 
          issue.plan_status = '→'
        end
      end
      
    end
    
    render "user_work"
  end
  
  # Получение комбобокса с пользователями в зависимости от переданной группы для ajax запросов
  def get_users
    return unless params[:group_id]
    if params[:group_id] != ""
      @users = User.includes(:groups).where(:status => 1).where(:groups_users => {'id' => params[:group_id]}).compact.sort.to_a.uniq
    else
      @users = User.includes(:groups).where(:status => 1).where(:groups_users => {'id' => @user_groups.values}).compact.sort.to_a.uniq
    end
    render :partial => "users_list", :locals => { :users => @users, :current_user_id => nil }
  end
  
end
