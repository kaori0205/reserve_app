require 'rails_helper'

RSpec.describe 'GET /api/hello', type: :request do
  it '名前を渡すと、200 とあいさつを返す' do
    get '/api/hello', params: { name: '山田' }
    expect(response).to have_http_status(200)
    json = JSON.parse(response.body)
    expect(json['message']).to eq 'こんにちは、山田さん'
  end

  it '名前がないと、400 と error を返す' do
    get '/api/hello'
    expect(response).to have_http_status(400)
    json = JSON.parse(response.body)
    expect(json['error']).to be_present
  end
end