require "gitorious/messaging"
require File.join(File.dirname(__FILE__), "gitorious_config") if !defined?(Gitorious) || !Gitorious.respond_to?(:configured?) || !Gitorious.configured?
Gitorious::Messaging.configure(Gitorious::Messaging.adapter) unless Gitorious::Messaging::Consumer.configured?
