#!/bin/env ruby
# encoding: utf-8

class WorkEntry < TimeEntry
  
  attr_accessor :before_status, :after_status, :css_class, :to_drop, :overdue, :overwork
  
  # Получение затраченного времени по пользователю к дате затраченного времени(включительно)
  def spent_hours_user_on_date
    return 0 unless issue
    
    return @spent_hours_user_on_date if @spent_hours_user_on_date
    
    sum = 0
    issue.time_entries.each do |time_entry|
      if (time_entry.user_id == user_id && time_entry.spent_on <= spent_on)
        sum += time_entry.hours
      end
    end
    @spent_hours_user_on_date ||= sum || 0
  end

  # Пользователю была назначена задача после переданной даты
  def user_was_assigned_after_date( start_date = spent_on)
    return false unless issue
    
    begin_date_ranges = []
    
    journal_details = Journal.includes(:details).where(:journalized_id => issue.id).where(:journal_details => {:prop_key => 'assigned_to_id', :value => user_id.to_s})
    
    # проходим по всем изменениям в задаче, где есть смена пользователя на нужного нам и добавляем начало этого дня в даты начала работы над задачей
    journal_details.each do |journal|
      if begin_date_ranges.size == 0 && issue.created_on
        begin_date_ranges.unshift issue.created_on
      end
      begin_date_ranges.push(journal.created_on)
    end
    
    if begin_date_ranges.size == 0 && issue.created_on
      begin_date_ranges.unshift issue.created_on
    end
      
    for i in 0..begin_date_ranges.size - 1
      return true if start_date <= begin_date_ranges[i].to_date
    end
    return false
  end

  # Пользователю была назначена задача до переданной даты
  def user_was_assigned_before_date( start_date = spent_on)
    return false unless issue
    
    begin_date_ranges = []
    end_date_ranges = []
    
    # Берем все изменения задачи в которых есть смена пользователя
    journal_details = Journal.includes(:details).where(:journalized_id => issue.id).where(:journal_details => {:prop_key => 'assigned_to_id'})
    
    journal_details.each do |journal|
      # проходим по всем деталям изменений в задаче
      journal.details.each do |detail|
        # если есть смена пользователя на нужного нам, добавляем конец этого дня в даты конца работы над задачей
        if detail.value.to_s == user_id.to_s
          begin_date_ranges.push(journal.created_on.beginning_of_day)
        end
        # если есть смена пользователя c нужного нам, добавляем конец этого дня в даты конца работы над задачей
        if detail.old_value.to_s == user_id.to_s
          end_date_ranges.push(journal.created_on.end_of_day)
        end
      end
    end
    if begin_date_ranges.size == 0 || (end_date_ranges.size > 0 && end_date_ranges[0] < begin_date_ranges[0] )
      # если первая дата конца периода стоит перед первой датой начала, значит пользователь был изначально назначенным на задачу, добавляем к датам начала
      begin_date_ranges.unshift issue.created_on.beginning_of_day
    end
    for i in 0..begin_date_ranges.size - 1
      begin_range = begin_date_ranges[i]
      end_range = end_date_ranges[i] || Date::Infinity.new

      if (begin_range..end_range).cover?(start_date.to_time)
        return true
      end
    end
    return false
  end
  
  # Назначена ли пользователю задача на конец текущего дня
  def user_assigned_at_end_of_day
    return false unless issue
    
    return @user_assigned_at_end_of_day if @user_assigned_at_end_of_day
    
    begin_date_ranges = []
    end_date_ranges = []
    
    # Берем все изменения задачи в которых есть смена пользователя
    journal_details = Journal.includes(:details).where(:journalized_id => issue.id).where(:journal_details => {:prop_key => 'assigned_to_id'})
    
    journal_details.each do |journal|
      # проходим по всем деталям изменений в задаче
      journal.details.each do |detail|
        # если есть смена пользователя на нужного нам, добавляем конец этого дня в даты конца работы над задачей
        if detail.value.to_s == user_id.to_s
          begin_date_ranges.push(journal.created_on)
        end
        # если есть смена пользователя c нужного нам, добавляем конец этого дня в даты конца работы над задачей
        if detail.old_value.to_s == user_id.to_s
          end_date_ranges.push(journal.created_on)
        end
      end
    end
    
    if begin_date_ranges.size == 0 || (end_date_ranges.size > 0 && end_date_ranges[0] < begin_date_ranges[0] )
      # если первая дата конца периода стоит перед первой датой начала, значит пользователь был изначально назначенным на задачу, добавляем к датам начала
      begin_date_ranges.unshift issue.created_on
    end

    for i in 0..begin_date_ranges.size - 1
      if end_date_ranges[i] && end_date_ranges[i].to_date == spent_on && ((begin_date_ranges[i+1] && begin_date_ranges[i+1].to_date > spent_on) || !begin_date_ranges[i+1])
        @user_assigned_at_end_of_day = false
        return false
      end
    end
    @user_assigned_at_end_of_day = true
  end
  
  # Получение даты выполнения на дату строки
  def due_date_on_date
    return '' unless issue
    
    return @due_date_on_date if @due_date_on_date
    
    res = IssueExt.get_periodic_value_on_time IssueExt.issue_field_periodics(issue, 'due_date'), spent_on # получаем все периодики изменения даты выполнения
    @get_due_date_on_date = res ? res.to_date : ''
  end
  
  # получение планового количества часов
  def plan_hours
    return '' unless issue
    return @plan_hours if @plan_hours
    
    res = IssueExt.get_periodic_value_on_time IssueExt.issue_field_periodics(issue, IssueExt.time_field_by_user(user_id)), spent_on # получаем все периодики изменения оценки времени по полю для данного пользователя
    @plan_hours = res ? res.to_f : 0
  end
  
end