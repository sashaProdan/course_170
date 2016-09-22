require "sinatra"
require "sinatra/reloader" if development?
require "tilt/erubis"
require "redcarpet"
require 'yaml'
require "bcrypt"

configure do
  enable :sessions
  set :session_secret, 'super secret'
end

helpers do
  def render_markdown(text)
    markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
    markdown.render(text)
  end
end

def data_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/data", __FILE__)
  else
    File.expand_path("../data", __FILE__)
  end
end

def load_user_credentials
  credentials_path = if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/users.yml", __FILE__)
  else
    File.expand_path("../users.yml", __FILE__)
  end

  YAML.load_file(credentials_path)
end

def valid_credentials?(username, password)
  credentials = load_user_credentials

  if credentials.key?(username)
    bcrypt_password = BCrypt::Password.new(credentials[username])
    bcrypt_password == password
  else
    false
  end
end

get "/" do
  pattern = File.join(data_path, "*")
  @files = Dir.glob(pattern).map {|path| File.basename(path)}

  erb :index, layout: :layout
end

get "/users/signin" do
  erb :signin
end

post "/users/signin" do
  username = params[:username]

  if valid_credentials?(username, params[:password])
    session[:username] = username
    session[:message] = "Welcome!"
    redirect "/"
  else
    session[:message] = "Invalid Credentials"
    status 422
    erb :signin
  end
end

post "/users/signout" do
  session.delete(:username)
  session[:message] = "You have been signed out."
  redirect "/"
end


def load_content(path)
  extansion = File.extname(path)
  content = File.read(path)

  if extansion == ".md"
    erb render_markdown(content)
  else
    headers["Content-Type"] = "text/plain"
    content
  end
end

def user_signed_in?
  session.key?(:username)
end

def require_signed_in_user
  unless user_signed_in?
    session[:message] = "You must be signed in to do that."
    redirect "/"
  end
end

get "/new" do
  require_signed_in_user
  
  erb :new
end

post "/new" do
  require_signed_in_user

  new_file = params[:filename].to_s.strip
  dir = File.join(data_path, new_file)
  
  if new_file.size == 0
    session[:message] = "A name is required."
    status 422
    erb :new
  else
    File.write(dir, "")
    session[:message] = "#{new_file} has been created."
    redirect "/"
  end
end

get "/:file_name" do
  file = File.join(data_path, params[:file_name])
  
  if File.file? file
    load_content(file)
  else
    session[:message] = "#{params[:file_name]} does not exist" 
    redirect "/"
  end
end

get "/:file_name/edit" do
  require_signed_in_user

  file = File.join(data_path, params[:file_name])
  @content = File.read(file)

  erb :edit
end

post "/:file_name/delete" do
  require_signed_in_user

  file = File.join(data_path, params[:file_name])

  File.delete(file)
  session[:message] = "#{params[:file_name]} has been deleted."
  redirect "/"
end

post "/:file_name" do
  require_signed_in_user

  file = File.join(data_path, params[:file_name])
  @content = File.read(file)
  
  File.write(file, params[:text])

  session[:message] = "#{params[:file_name]} has been updated."
  redirect "/"
end
