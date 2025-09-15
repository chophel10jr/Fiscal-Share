# frozen_string_literal: true

require 'json'

class ApplicationService
  include Assigner

  def initialize(attrs = {})
    assign_attributes(attrs)
  end

  protected

  def send_post_request(url, body, headers)
    HTTP.post(url, json: body, headers: headers)
  end
end
