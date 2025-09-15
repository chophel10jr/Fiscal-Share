# frozen_string_literal: true

require 'csv'

class LedgerController < ApplicationController
  before_action :authenticate_token!, only: [:loan_ledger, :deposit_ledger]

  # Loan Ledger API
  def loan_ledger
    generate_ledger('loan', 'BNBVW_LOAN_LEDGER', [
      'ACCOUNT_NO', 'CUSTOMER_IDENTIFICATION_NUMBER', 'NAME_OF_FSP', 'NAME_OF_THE_CLIENT',
      'CLIENT_TYPE', 'NAME_OF_THE_BUSINESS', 'IDENTIFICATION_TYPE', 'CID_NO', 'TPN',
      'LICENSE_NO', 'DOB_DDMMYYYY', 'GENDER_MF_OTHERS', 'CONTACT_NUMBER', 'SECTOR',
      'SUB_SECTOR', 'BSIC_SECTOR_CODE', 'BSIC_SUB_SECTOR_CODE', 'SUB_SECTOR_CATEGORY_ACTIVITY',
      'ADDITIONAL_DETAILS_FOR_HOTEL_HOUSING_AND_TRANSPORT_SECTOR', 'BRANCH_CODE', 'BRANCH_NAME',
      'BRANCH_LOCATION', 'DZONGKHAG_PROJECT_SITE', 'LOAN_TYPE', 'NORMAL_OR_REVOKE_LC_BG',
      'OFF_BALANCE_SHEET_ITEM_YES_NO', 'TYPE_OF_OFF_BALANCE_SHEET_ITEM', 'APF_DATE_DDMMYYYY',
      'GESTATION_YES_NO', 'GESTATION_EXPIRY_DATE_DDMMYYYY', 'GREEN_FINANCE_LOAN_YES_NO',
      'PSL_LOAN_YES_NO', 'MCSML_CATEGORY', 'REPAYMENT_SOURCE', 'SANCTION_DATE_DDMMYYYY',
      'EXPIRY_DATE_DDMMYYYY', 'AMOUNT_FINANCED', 'PRINICIPAL_OS', 'INTEREST_OS', 'PENALTY_OS',
      'TOTAL_INTEREST_OUTSTANDING', 'TOTAL_LOAN_OUTSTANDING', 'OVERDUE_DAYS',
      'PRINCIPAL_INTEREST_OVERDUE', 'LOAN_CATEGORY_STATUS_BUCKET', 'PROVISION_AMOUNT',
      'EMI_FREQUENCY', 'EMI_AMOUNT', 'INTEREST_RATE', 'PRIMARY_COLLATERAL_TYPE',
      'SECONDARY_COLLATERAL_TYPE', 'TOTAL_COLLATERAL_VALUE', 'RESTRUCTURED_RESCHEDULED_NA',
      'RESTRUCTURED_RESCHEDULED_DATE_DDMMYYYY', 'CHARGED_OFF_LOAN_YES_NO',
      'DATE_OF_CHARGED_OFF_LOAN_DDMMYYYY', 'LOAN_UNDER_OBSERVATION_YES_NO', 'OBSERVATION_STATUS',
      'LOAN_REGULARIZATION_CLOSURE_DATE', 'LOAN_CLASSIFICATION_DURING_REGULARIZATION_CLOSURE',
      'START_DATE_OF_OBSERVATION_PERIOD', 'END_DATE_OF_OBSERVATION_PERIOD',
      'AMOUNT_RECOVERED_DURING_REGULARIZATION_CLOSURE', 'PAST_OVERDUE_DAYS',
      'LOAN_CLOSED_THROUGH_FORECLOSURE_YES_NO', 'LOAN_CLOSED_THROUGH_TRANSFER_YES_NO',
      'LOAN_UNDER_DEFERMENT_YES_NO', 'START_DATE_OF_DEFERMENT_DDMMYYYY',
      'END_DATE_OF_DEFERMENT_DDMMYYYY', 'TOP_10_EXPOSURE_RANK_OVERALL', 'LITIGATION_YES_NO',
      'LITIGATION_BUCKET', 'LITIGATION_DATE'
    ])
  end

  # Deposit Ledger API
  def deposit_ledger
    generate_ledger('deposit', 'BNBVW_DEPOSIT_LEDGER', [
      'NAME_OF_FSP', 'DEPOSIT_AC_NO', 'NAME', 'CLIENT_TYPE', 'IDENTIFICATION_TYPE',
      'CID_NO', 'TPN_NO', 'LICENSE_NO', 'DATE_OF_BIRTH', 'GENDER', 'MOBILE_NUMBER',
      'BRANCH_LOCATION', 'BRANCH_NAME', 'DEPOSIT_AMT', 'DEPOSIT_TYPE', 'RATE',
      'AC_OPEN_DATE', 'MATURITY_DATE', 'MATURITY_AMT'
    ])
  end

  def download_csv
    filename = params[:filename]
    
    # Debug: Log the incoming filename
    Rails.logger.info "📥 Received filename: #{filename}"
    
    # Validate filename to prevent directory traversal attacks
    unless valid_filename?(filename)
      Rails.logger.error "❌ Invalid filename: #{filename}"
      render json: { error: 'Invalid filename', received_filename: filename }, status: :bad_request
      return
    end
    
    # Ensure we have the .csv extension
    filename_with_extension = filename.end_with?('.csv') ? filename : "#{filename}.csv"
    filepath = Rails.root.join('tmp', 'exports', filename_with_extension)
    
    Rails.logger.info "📁 Looking for file at: #{filepath}"
    
    if File.exist?(filepath)
      Rails.logger.info "✅ File found, sending download"
      send_file filepath,
                type: 'text/csv',
                disposition: 'attachment',
                filename: filename_with_extension
    else
      # Debug information
      exports_dir = Rails.root.join('tmp', 'exports')
      existing_files = Dir.glob(exports_dir.join('*')).map { |f| File.basename(f) }
      
      Rails.logger.error "❌ File not found: #{filepath}"
      Rails.logger.error "📂 Directory contents: #{existing_files.inspect}"
      Rails.logger.error "📂 Directory exists: #{File.directory?(exports_dir)}"
      
      render json: { 
        error: 'File not found or expired',
        debug: {
          requested_file: filename,
          searched_file: filename_with_extension,
          search_path: filepath.to_s,
          directory_exists: File.directory?(exports_dir),
          existing_files: existing_files,
          current_time: Time.current.iso8601
        }
      }, status: :not_found
    end
  end

  private

  def generate_ledger(ledger_type, view_name, headers)
    oracle_connection = OracleConnectionService.new().run

    query = <<~SQL
      SELECT * FROM #{view_name}
    SQL

    cursor = oracle_connection.exec(query)
    
    # Generate unique filename
    filename = "#{ledger_type}_ledger_#{Time.current.strftime('%Y%m%d_%H%M%S')}.csv"
    filepath = Rails.root.join('tmp', 'exports', filename)
    
    # Ensure directory exists
    FileUtils.mkdir_p(File.dirname(filepath))
    
    # Generate CSV file using CSV gem
    CSV.open(filepath, 'w') do |csv|
      # Write header
      csv << headers
      
      # Write data rows with NAN for empty values
      while row = cursor.fetch
        processed_row = row.map do |value|
          if value.nil? || value.to_s.strip.empty?
            'NAN'
          else
            value.to_s
          end
        end
        csv << processed_row
      end
    end
    
    # Debug: Check if file was created successfully
    if File.exist?(filepath)
      Rails.logger.info "✅ #{ledger_type.capitalize} CSV file successfully created: #{filepath}"
      Rails.logger.info "✅ File size: #{File.size(filepath)} bytes"
    else
      Rails.logger.error "❌ #{ledger_type.capitalize} CSV file was NOT created: #{filepath}"
      render json: { error: "Failed to create #{ledger_type} CSV file" }, status: :internal_server_error
      return
    end
    
    # Get file size and row count
    file_size = File.size(filepath)
    row_count = `wc -l #{filepath}`.split.first.to_i - 1 # Subtract header row
    
    # Generate download URL
    download_url = download_csv_url(filename: filename, host: request.host_with_port)
    
    Rails.logger.info "✅ Generated download URL: #{download_url}"
    
    render json: {
      success: true,
      message: "#{ledger_type.capitalize} CSV file generated successfully with #{row_count} records",
      download_link: download_url,
      filename: filename,
      file_size: "#{(file_size / 1024.0 / 1024.0).round(2)} MB",
      generated_at: Time.current.iso8601,
      expires_at: 24.hours.from_now.iso8601
    }
    
  rescue OCIError => e
    Rails.logger.error "❌ Database error: #{e.message}"
    render json: { 
      success: false, 
      error: "Database error: #{e.message}" 
    }, status: :internal_server_error
  rescue => e
    Rails.logger.error "❌ File generation error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    render json: { 
      success: false, 
      error: "File generation error: #{e.message}" 
    }, status: :internal_server_error
  ensure
    cursor.close if cursor if defined?(cursor)
    oracle_connection.logoff if oracle_connection if defined?(oracle_connection)
  end

  def valid_filename?(filename)
    filename.match?(/^(loan|deposit)_ledger_\d{8}_\d{6}(\.csv)?$/)
  end

  def authenticate_token!
    api_key = request.headers['X-API-KEY'] || params[:api_key]
    
    unless valid_api_key?(api_key)
      render json: { error: 'Invalid or missing API key' }, status: :unauthorized
    end
  end

  def valid_api_key?(token)
    return false if token.blank?
    
    token == ENV['API_ACCESS_TOKEN']
  end
end
