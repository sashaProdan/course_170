require "sinatra"
require "sinatra/reloader" if development?
require "tilt/erubis"
require "redcarpet"
require "fileutils"

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

get "/" do
  pattern = File.join(data_path, "*")
  @files = Dir.glob(pattern).map {|path| File.basename(path)}

  erb :index, layout: :layout
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

get "/new" do
  erb :new
end

post "/new" do
  new_file = params[:filename].to_s.strip
  dir = File.join(data_path, new_file)
  
  if new_file.size == 0
    session[:message] = "A name is required."
    status 422
    erb :new
  else
    File.write(dir, "")
    session[:message] = "#{new_file} was created."
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
  file = File.join(data_path, params[:file_name])
  @content = File.read(file)

  erb :edit
end

post "/:file_name/delete" do
  file = File.join(data_path, params[:file_name])

  File.delete(file)
  session[:message] = "#{params[:file_name]} was deleted."
  redirect "/"
end

post "/:file_name" do
  file = File.join(data_path, params[:file_name])
  @content = File.read(file)
  
  File.write(file, params[:text])

  session[:message] = "#{params[:file_name]} has been updated."
  redirect "/"
end
