Rails.application.routes.draw do
  get '/loan-ledger', to: 'ledger#loan_ledger'
  get '/deposit-ledger', to: 'ledger#deposit_ledger'
  get 'downloads/:filename', to: 'ledger#download_csv', as: 'download_csv'
end
