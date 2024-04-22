# Set env var LOG_TO_CONSOLE if you want logging to dump to the console
# e.g. LOG_TO_CONSOLE=true ruby spec/models/vm.rb
$log.logdev = STDERR if ENV['LOG_TO_CONSOLE']

# Set env var LOGLEVEL if you want custom log level during a local test
# e.g. LOG_LEVEL=debug ruby spec/models/vm.rb
env_level = Logger.const_get(ENV['LOG_LEVEL'].to_s.upcase) rescue nil if ENV['LOG_LEVEL']
env_level ||= Logger::INFO
$log.level = env_level
Rails.logger.level = env_level

module EvmSpecHelper
  extend RSpec::Mocks::ExampleMethods

  def self.assign_role(role_name, miq_server: nil, create_options: {})
    MiqRegion.seed
    miq_server ||= local_miq_server
    role = ServerRole.find_by(:name => role_name) || FactoryBot.create(:server_role, :name => role_name, **create_options)
    miq_server.assign_role(role).update(:active => true)
  end

  def self.assign_embedded_terraform_role(miq_server = nil)
    assign_role("embedded_terraform", :miq_server => miq_server, :create_options => {:max_concurrent => 0})
  end
end
