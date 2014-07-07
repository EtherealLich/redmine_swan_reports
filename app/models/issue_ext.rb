class IssueExt < Issue
  
  attr_accessor :plan_status, :css_class, :overwork
  
  # Получение поля оценки времени, выбираемого в зависимости от пользователя, на дату
  def user_plan_hours_on_date(dt, user_id)
    (IssueExt.get_periodic_value_on_time IssueExt.issue_field_periodics(self, IssueExt.time_field_by_user(user_id)), dt) || 0
  end
  
  # Получение поля Даты окончания на дату
  def due_date_on_date(dt)
    IssueExt.get_periodic_value_on_time IssueExt.issue_field_periodics(self, 'due_date'), dt
  end
  
  # Получение затраченного времени по пользователю к дате(включительно)
  def spent_hours_user_on_date(dt, user_id)
    sum = 0
    time_entries.each do |time_entry|
      if (time_entry.user_id.to_s == user_id.to_s && time_entry.spent_on.to_time <= dt.to_time)
        sum += time_entry.hours
      end
    end
    @spent_hours_user_on_date ||= sum || 0
  end
  
  # Получение всех периодик по переданному полю
  def self.issue_field_periodics(issue, field)
    periodics = {}
    journal_details = Journal.includes(:details).where(:journalized_id => issue.id).where(:journal_details => {:prop_key => field})
    journal_details.each do |journal| # проходим по всем изменениям, где есть смена нужного нам поля
      detail = journal.details.first # так как мы взяли только те детали, в которых смена нужного нам поля, она всего одна на изменение
      if periodics.size == 0 && detail.old_value # запоминаем предыдущую дату изменения из первой периодики если она там была
        periodics[issue.created_on] = detail.old_value
      end
      periodics[journal.created_on] = detail.value # запоминаем дату изменения из периодики
    end
    if periodics.size == 0 # если в периодиках пусто, значит поле не менялось, попробуем получить его из задачи
      if !(field.is_a? Integer) # некастомное поле
          periodics[issue.created_on] = issue[field] if issue[field]
      else # кастомное поле
        if issue.custom_field_values.detect {|f| f.custom_field_id == field.to_i }
          periodics[issue.created_on] = issue.custom_field_values.detect {|f| f.custom_field_id == field.to_i }.value
        end
      end
    end
    periodics
  end
  
  # Получение последнего значения периодики на дату
  def self.get_periodic_value_on_time(periodics, on_time)
    res = nil
    return nil if !periodics.size == 0 # если периодик нет, то возвращаем безысходность
    periodics.each do |k, v| # проходим по всем периодикам
      if k.to_time <= on_time.to_time # пока дата изменения поля меньше искомой
        res = v # сохраняем значение поля
      else
        break # если дата изменения поля стала больше даты строки, выходим из итератора
      end
    end
    res
  end
  
  # Получение поля с оценкой времени для конкретного пользователя
  def self.time_field_by_user(user_id)
    user_groups = Setting.plugin_redmine_swan_reports['user_groups']
    @groups = User.find(user_id).groups.map(&:id)

    if ( @groups.include?(user_groups[:op]) )
      '15'
    elsif ( @groups.include?(user_groups[:osz]) || @groups.include?(user_groups[:orbd]) )
      '19'
    elsif ( @groups.include?(user_groups[:ot]) )
      '18'
    else
      '16'
    end
  end
  
  # Пользователю была назначена задача после переданной даты
  def user_was_assigned_after_date(start_date, user_id)
    
    begin_date_ranges = []
    
    journal_details = Journal.includes(:details).where(:journalized_id => id).where(:journal_details => {:prop_key => 'assigned_to_id', :value => user_id.to_s})
    
    # проходим по всем изменениям в задаче, где есть смена пользователя на нужного нам и добавляем начало этого дня в даты начала работы над задачей
    journal_details.each do |journal|
      if begin_date_ranges.size == 0 && created_on
        begin_date_ranges.unshift created_on
      end
      begin_date_ranges.push(journal.created_on)
    end
    
    if begin_date_ranges.size == 0 && created_on
      begin_date_ranges.unshift created_on
    end
      
    for i in 0..begin_date_ranges.size - 1
      return true if start_date <= begin_date_ranges[i].to_date
    end
    return false
  end
  
end