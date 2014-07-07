#!/bin/env ruby
# encoding: utf-8

require 'redmine'

Redmine::Plugin.register :redmine_swan_reports do
  name 'Отчеты для SWAN'
  author 'Ivan Petukhov'
  description 'Отчеты по работе сотрудников SWAN'
  version '0.1.0'
  url 'http://swan.perm.ru/'
  author_url 'https://github.com/EtherealLich'
  
  settings :default => {
    # Идентификаторы отделов
    'user_groups' => {
      :orppo => 55,
      :op => 106,
      :orbd => 166,
      :osz => 175,
      :oro => 206,
      :ot => 226,
      :orias => 264,
      :orss=> 269,
      :er => 339,
      :design => 343
    }
  }

end
