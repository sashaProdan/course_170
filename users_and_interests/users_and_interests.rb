require 'sinatra'
require 'sinatra/reloader'
require 'yaml'

helpers do
  def count_interests
    @users.inject(0) do |total, (name, hash)|
      total + hash[:interests].size
    end
  end 

  def count_users
    @users.keys.size
  end
end

before do
  @users = YAML.load_file('users.yaml')
end

get '/' do
  redirect 'users'
end

get '/users' do
  erb :users
end

get '/users/:name' do
  name = params[:name] 
  @user = @users.fetch(name.to_sym)
  @links = @users.keys.select { |user| user.to_s != name }

  erb :user
end