RedmineApp::Application.routes.draw do
  match '/reports', :to => 'swan_reports#index'
  match '/reports/user_work', :to => 'swan_reports#user_work'
  match '/reports/user_work/:id', :to => 'swan_reports#user_work'
  match "/reports/get_users" => "swan_reports#get_users"
end