class CreateApiRequestLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :api_request_logs, id: :uuid do |t|
      t.jsonb :body, null: false, default: {}
      t.datetime :created_at, null: false
    end
  end
end
