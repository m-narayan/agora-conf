class AddSiteLoginToSite < ActiveRecord::Migration
  def self.up
    add_column :sites, :site_agora_login, :boolean
    add_column :sites, :site_agora_login_server, :string
    add_column :sites, :site_agora_login_port, :string
  end

  def self.down
  end
end
