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

  def session
    last_request.env["rack.session"]
  end

  def admin_session
    { "rack.session" => { username: "admin", 
                          password: "$2a$10$NVDsI6DYmtjDQx8zy6w1qe8kNupoWGj2wMLyKfVdRjiCvTnuCRR7e" } }
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
    get "/xoxox.txt"

    assert_equal 302, last_response.status

    get last_response["Location"]

    assert_equal 200, last_response.status
    assert_includes last_response.body, "xoxox.txt does not exist"
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
    create_document "changes.txt", "Hey"

    post "/changes.txt", {content: "Bye"}
    assert_equal 302, last_response.status

    get last_response["Location"]
    assert_includes last_response.body, "changes.txt has been updated."

    get "/changes.txt"

    assert_equal 200, last_response.status
    assert_includes last_response.body, "Bye"
  end

  def test_create_new_document
    skip
    get "/"

    assert_includes last_response.body, '<a href="/new">New Document</a>'

    get "/new"

    assert_equal 200, last_response.status
    assert_includes last_response.body, "New document name"
    assert_includes last_response.body, '<button type="submit">Create</button>'
    assert_includes last_response.body, '<form action="/new" method="post">'
  end

  def test_save_new_document
    skip
    post "/new", filename: "hello.txt"
    assert_equal 302, last_response.status

    get last_response["Location"]
    assert_includes last_response.body, "hello.txt was created"

    get "/"
    assert_includes last_response.body, 'hello.txt'
  end

  def test_create_new_document_without_name
    skip
    post "/new", filename: ""
    assert_equal 422, last_response.status

    get last_response["Location"]
    assert_equal last_response.body, "A name is required."
  end

  def test_delete_document
    skip
    create_document "hello.txt"

    get "/"
    assert_includes last_response.body, "hello.txt"
    assert_includes last_response.body, '<button type="submit">Delete</button>'

    post "/hello.txt/delete"
    assert_equal 302, last_response.status
    assert_equal false, File.exist?('hello.txt')
    get last_response["Location"]
    assert_includes last_response.body, "hello.txt was deleted."

    get "/"
    refute_includes last_response.body, "hello.txt"
  end

  def test_signin_form
    get "/users/signin"
    
    assert_equal 200, last_response.status
    assert_includes last_response.body, '<button type="submit">Sign In</button>'
  end

  def test_signin_right_credentials
    post "/users/signin", username: 'admin', password: 'secret'

    assert_equal 302, last_response.status
    assert_equal "Welcome!", session[:message]
    assert_equal "admin", session[:username]

    get last_response["Location"]
    assert_includes last_response.body, "Signed in as admin"
    assert_includes last_response.body, "Sign Out"
  end

  def test_signin_bad_credentials
    post "/users/signin", username: 'some111', password: 'pass'

    assert_equal 422, last_response.status
    assert_equal nil, session[:username]
    assert_includes last_response.body, "Invalid Credentials"
  end

  def test_signout
    get "/", {}, {"rack.session" => {username: 'admin'}}
    assert_includes last_response.body, "Signed in as admin"

    post "/users/signout"
    get last_response["Location"]

    assert_equal nil, session[:username]

    assert_includes last_response.body, "You have been signed out"
    assert_includes last_response.body, "Sign In"
  end

  def test_visit_edit_page_signed_in
    create_document "changes.txt", "Hi, developer!"

    get "/changes.txt/edit", {}, admin_session

    assert_equal 200, last_response.status
    assert_includes last_response.body, "Hi, developer!"
    assert_includes last_response.body, "<textarea"
    assert_includes last_response.body, %q(<button type="submit")
  end
  
  def test_visit_edit_page_not_signed_in
    create_document "changes.txt", "Hi, developer!"

    get "/changes.txt/edit"

    assert_equal 302, last_response.status
    get last_response["Location"]
    assert_includes last_response.body, "You must be signed in to do that."
  end 

  def test_update_document_signed_in
    skip
    post "/changes.txt", {content: "new content"}, admin_session
    
    assert_equal 302, last_response.status
    assert_includes last_response.body, "changes.txt has been updated."

    get "/changes.txt"

    assert_equal 200, last_response.status
    assert_includes last_response.body, "new content"
  end
##################################
  def test_updating_document_signed_out
    post "/changes.txt", {content: "new content"}

    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
  end

  def test_view_new_document_form
    get "/new", {}, admin_session

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<input"
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_view_new_document_form_signed_out
    get "/new"

    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
  end

  def test_create_new_document
    post "/new", {filename: "test.txt"}, admin_session
    assert_equal 302, last_response.status
    assert_equal "test.txt has been created.", session[:message]

    get "/"
    assert_includes last_response.body, "test.txt"
  end

  def test_create_new_document_signed_out
    post "/new", {filename: "test.txt"}

    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
  end

  def test_create_new_document_without_filename
    post "/new", {filename: ""}, admin_session
    assert_equal 422, last_response.status
    assert_includes last_response.body, "A name is required"
  end

  def test_deleting_document
    create_document("test.txt")

    post "/test.txt/delete", {}, admin_session
    assert_equal 302, last_response.status
    assert_equal "test.txt has been deleted.", session[:message]

    get "/"
    refute_includes last_response.body, %q(href="/test.txt")
  end

  def test_deleting_document_signed_out
    create_document("test.txt")

    post "/test.txt/delete"
    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
  end
end