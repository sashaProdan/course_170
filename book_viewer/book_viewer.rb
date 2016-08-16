require "tilt/erubis"
require "sinatra"
require "sinatra/reloader"

get "/" do
  @title = "The Adventures of Sherlock Holmes"
  @contents = File.readlines("data/toc.txt")

  erb :home
end

get "/chapters/:number" do
  @contents = File.readlines("data/toc.txt")
  number = params[:number]
  chapter_name = @contents[number.to_i - 1]
  @title = "Chapter #{number}: #{chapter_name}"
  @chapter = File.read("data/chp#{number}.txt")
  
  erb :chapter
end

