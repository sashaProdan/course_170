require "sinatra"
require "sinatra/reloader"
require "tilt/erubis"

configure do
  enable :sessions
  set :sessions_secret, 'secret'
end

before do
  session[:lists] ||= [] # when there are no lists yet, we have an empty array,so
                        # in lists.erb method `each` is not being called on nil.
                        # And homepage shows just empty page instead of error.
end

get "/" do
  redirect "/lists"
end

# View all the lists
get "/lists" do
  @lists = session[:lists]
  erb :lists, layout: :layout
end

# Render the new list form
get "/lists/new" do
  erb :new_list, layout: :layout
end

# Create a new list
post "/lists" do
  list_name = params[:list_name].strip
  if (1..100).cover? list_name.size
    session[:lists] << { name: list_name, todos: [] }
    session[:success] = "The list has been created."
    redirect "/lists"
  else
    session[:error] = "The list name must be between 1-100 characters."
    erb :new_list, layout: :layout
  end
end
