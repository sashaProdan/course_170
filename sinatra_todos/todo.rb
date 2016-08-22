require "sinatra"
require "sinatra/reloader"
require "sinatra/content_for"
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

# Return the error message if the name is invalid.
# Return nil if name is valid.
def error_for_list_name(name)
  if !(1..100).cover? name.size
    "The list name must be between 1-100 characters."
  elsif session[:lists].any? { |list| list[:name] == name }
    "The list name must be unique."
  end
end

# Create a new list
post "/lists" do
  list_name = params[:list_name].strip

  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    session[:lists] << { name: list_name, todos: [] }
    session[:success] = "The list has been created."
    redirect "/lists"
  end
end

# Render list todos
get "/lists/:id" do
  id = params[:id].to_i
  @list = session[:lists][id]
  erb :list, layout: :layout
end

# Edit an existing todo list
get "/lists/:id/edit" do
  id = params[:id].to_i
  @list = session[:lists][id]
  erb :edit_list, layout: :layout
end

# Update an existing todo list
post "/lists/:id" do
  list_name = params[:list_name].strip
  id = params[:id].to_i
  @list = session[:lists][id]

  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :edit_list, layout: :layout
  else
    @list[:name] = list_name
    session[:success] = "The list has been updated."
    redirect "/lists/#{id}"
  end
end

delete "/lists/:id/delete" do
  list_name = params[:list_name].strip
  id = params[:id].to_i
  @list = session[:lists][id]
  @list.delete([:name])
  redirect "/lists"
end
