ENV["RACK_ENV"] = "test"

require "minitest/autorun"
require "rack/test"
require "fileutils"

require_relative "../file_cms"

class AppTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def setup
    FileUtils.mkdir_p(data_path)
  end

  def teardown
    FileUtils.rm_rf(data_path)
  end

  def create_document(name, content = "")
    File.open(File.join(data_path, name), "w") do |file|
      file.write(content)
    end
  end

 def test_index
    create_document "about.md"
    create_document "changes.txt"
    create_document "history.txt"

    get "/"

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "about.md"
    assert_includes last_response.body, "changes.txt"
    assert_includes last_response.body, "history.txt"
  end

  def test_file_content
    create_document "changes.txt", "Hello there!"
    get "/changes.txt"

    assert_equal 200, last_response.status
    assert_equal "text/plain", last_response["Content-Type"]
    assert_equal last_response.body, "Hello there!"
  end

  def test_not_existent_file
    get "/changes.txt"

    assert_equal 302, last_response.status

    get last_response["Location"]

    assert_equal 200, last_response.status
    assert_includes last_response.body, "changes.txt does not exist"
  end

  def test_viewing_markdown_document
    create_document "changes.txt", "Hi, developer!"
      get "/changes.txt"
      
      assert_equal 200, last_response.status
      assert_includes last_response.body, "Hi, developer!"
  end

  def text_edit_document_content
    create_document "about.txt"
    get "/about.txt/edit"

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<textarea>"
    assert_includes last_response.body, '<button type="submit">'
  end

  def test_save_new_content
    create_document "changes.txt"

    post "/changes.txt"
    File.write("changes.txt", "Hey")
    assert_equal 302, last_response.status

    get last_response["Location"]

    assert_includes last_response.body, "changes.txt has been updated."#

    get "/changes.txt"

    assert_equal 200, last_response.status
  end

  def test_create_new_document
    get "/"

    assert_includes last_response.body, '<a href="/new">New Document</a>'

    get "/new"

    assert_equal 200, last_response.status
    assert_includes last_response.body, "New document name"
    assert_includes last_response.body, '<button type="submit">Create</button>'
    assert_includes last_response.body, '<form action="/new" method="post">'
  end

  def test_save_new_document
    post "/new", filename: "hello.txt"
    assert_equal 302, last_response.status

    get last_response["Location"]
    assert_includes last_response.body, "hello.txt was created"

    get "/"
    assert_includes last_response.body, 'hello.txt'
  end

  def test_create_new_document_without_name
    post "/new", filename: ""
    assert_equal 422, last_response.status
    assert_includes last_response.body, "A name is required."
  end

  def test_delete_document
    create_document "hello.txt"
    create_document "bye.txt"

    get "/"
    assert_includes last_response.body, "hello.txt"
    assert_includes last_response.body, "bye.txt"
    assert_includes last_response.body, '<button type="submit">Delete</button>'

    post "/hello.txt/delete"
    assert_equal false, File.exist?('hello.txt')
    get last_response["Location"]

    assert_equal 200, last_response.status
    assert_includes last_response.body, "hello.txt was deleted."
  end
end