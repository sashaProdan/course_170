require "sinatra"
require "sinatra/reloader" if development?
require "tilt/erubis"
require "redcarpet"

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

get "/" do
  @files = Dir.glob('data/*').map {|path| File.basename(path)}
  erb :index, layout: :layout
end

def load_content(path)
  extansion = File.extname(path)
  content = File.read(path)

  if extansion == ".md"
    render_markdown(content)
  else
    headers["Content-Type"] = "text/plain"
    content
  end
end

get "/:file_name" do
  file = "data/#{params[:file_name]}"
  
  if File.file? file
    load_content(file)
  else
    session[:error] = "#{File.basename(file)} does not exist" 
    redirect "/"
  end
end

