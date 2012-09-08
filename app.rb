require 'sinatra/base'
require 'slim'
require 'oauth2'
require 'json'
require 'sass'
require 'coffee-script'
require 'httmultiparty'

class App < Sinatra::Base

  configure do
    TAB_URL = 'https://tab.do/'
    REDIRECT_URI = 'http://editable.herokuapp.com/oauth2_callback'
    CLIENT_ID = ENV['CLIENT_ID']
    CLIENT_SECRET = ENV['CLIENT_SECRET']
    set :public, File.dirname(__FILE__) + '/public'
    set :sessions, true
  end

  configure :development do
    REDIRECT_URI = 'http://localhost:9292/oauth2_callback'
    Bundler.require :development
    register Sinatra::Reloader
  end

  get '/', :agent => %r{Chrome/(\d+).} do
    if params[:agent][0].to_i < 19
      slim :sorry
      return
    end
    prepare_token
    slim :new, locals: { me: me, streams: streams }
  end

  get '/' do
    slim :sorry
  end

  post '/' do
    prepare_token
    file, type = get_file_and_type(params['data-url'])
    response = HTTMultiParty.post("#{TAB_URL}/api/1/items",
      :query => {
        :title => params['title'],
        :stream_id => params['stream-id'],
        'item_images[]' => file,
      },
      :headers => {
        "Authorization" => 'Bearer %s' % @access_token.token
      })
    redirect response.parsed_response['item']['site_url']
  end

  get '/oauth2_callback' do
    if params[:error]
      return "#{params[:error]}: #{params[:error_description]}"
    end
    @access_token = oauth2_client.auth_code.get_token(params[:code], redirect_uri: REDIRECT_URI)
    session[:access_token] = @access_token.token
    session[:refresh_token] = @access_token.refresh_token
    redirect '/'
  end

  get '/style.css' do
    content_type 'text/css', :charset => 'utf-8'
    scss :'css/style'
  end

  get '/application.js' do
    coffee :'js/application'
  end

  private
  def oauth2_client
    OAuth2::Client.new(CLIENT_ID, CLIENT_SECRET,
      site: TAB_URL,
      authorize_url: '/oauth2/authorize',
      token_url: '/api/1/oauth2/token')
  end

  def prepare_token
    token = session[:access_token]
    refresh = session[:refresh_token]

    if token
      @access_token = OAuth2::AccessToken.from_hash(oauth2_client, { :access_token => token, :refresh_token => refresh })
      response = @access_token.refresh!
      session[:access_token] = response.token
    else
      redirect oauth2_client.auth_code.authorize_url(redirect_uri: REDIRECT_URI)
    end
  end

  def me
    @me ||= JSON.parse(@access_token.get('/api/1/users/me').body)["user"]
  end

  def streams
    @streams ||= JSON.parse(@access_token.get("/api/1/users/#{me['id']}/streams").body)["streams"]
  end

  def get_file_and_type data_url
    %r{data:image/(.+?);base64,(.+)} =~ data_url
    type = $1
    data = $2.unpack('m')[0]
    file = Tempfile.new(['editable', ".#{type}"])
    file.write(data)
    file.rewind
    return file, "image/#{type}"
  end
end
