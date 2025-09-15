# frozen_string_literal: true

require 'ruby-oci8'

class OracleConnectionService < ApplicationService
  def run
    validate_credentials
    establish_connection
  end

  private

  def validate_credentials
    %w[DB_HOST DB_PORT DB_SERVICE_NAME DB_USER DB_PASSWORD].each do |var|
      raise "Missing environment variable: #{var}" unless ENV[var].present?
    end
  end

  def establish_connection
    binding.pry
    connection_string = "//#{ENV['DB_HOST']}:#{ENV['DB_PORT']}/#{ENV['DB_SERVICE_NAME']}"
    
    connection = OCI8.new(ENV['DB_USER'], ENV['DB_PASSWORD'], connection_string)
    Rails.logger.info "Oracle database connection established"
    
    connection
  rescue OCIError => e
    Rails.logger.error "Oracle connection failed: #{e.message}"
    raise
  end
end
