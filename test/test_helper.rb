ENV["RAILS_ENV"] = "test"
require File.join(File.dirname(__FILE__), "../config/environment")
require "rails/test_help"
require "ssl_requirement_macros"
require "messaging_test_helper"
require "data_builder_helpers"
require "shoulda"
require "mocha"
require "fast_test_helper"

class ActiveSupport::TestCase
  include AuthenticatedTestHelper
  include Gitorious::Authorization
  include DataBuilderHelpers

  # The only drawback to using transactional fixtures is when you actually
  # need to test transactions.  Since your test is bracketed by a transaction,
  # any transactions started in your code will be automatically rolled back.
  self.use_transactional_fixtures = true

  # Instantiated fixtures are slow, but give you @david where otherwise you
  # would need people(:david).  If you don't want to migrate your existing
  # test cases which use the @david style and don't mind the speed hit (each
  # instantiated fixtures translates to a database query per test method),
  # then set this back to true.
  self.use_instantiated_fixtures  = false

  # Setup all fixtures in test/fixtures/*.(yml|csv) for all tests in alphabetical order.
  #
  # Note: You'll currently still have to declare fixtures explicitly in integration tests
  # -- they do not yet inherit this setting
  fixtures :all

  def repo_path
    File.join(File.dirname(__FILE__), "..", ".git")
  end

  def grit_test_repo(name)
    "#{Rails.root}/vendor/grit/test/#{name}"
  end

  def push_test_repo_path
    (Rails.root + "test/fixtures/push_test_repo.git").to_s
  end

  def assert_incremented_by(obj, meth, value)
    value_before = obj.send(meth)
    yield
    value_after = obj.send(meth)
    error_msg = (value_before == value_after) ? "unchanged" : "incremented by #{(value_after - value_before)}"
    assert_equal(value, (value_after - value_before), "#{obj}##{meth} should be incremented by #{value} but was #{error_msg}")
  end

  def assert_includes(collection, object, message=nil)
    assert(collection.include?(object),
      (message || inclusion_failure(collection, object, true)))
  end

  def assert_not_includes(collection, object, message=nil)
    assert(!collection.include?(object),
      (message || inclusion_failure(collection, object, false)))
  end

  def refute(test, msg=nil)
    msg ||= "Failed refutation, no message given"
    not assert(! test, msg)
  end

  def refute_equal exp, act, msg = nil
    refute exp == act, msg
  end

  def refute_match exp, act, msg = nil
    assert_respond_to act, :"=~"
    exp = (/#{Regexp.escape exp}/) if String === exp and String === act
    refute exp =~ act, msg
  end

  def refute_nil(*args)
    refute(args.shift.nil?, *args)
  end

  def inclusion_failure(collection, object, should_be_included)
    not_message = should_be_included ? "" : " not"
    "Expected collection (#{collection.count} items) #{not_message} to include #{object.class.name}"
  end

  def self.should_scope_pagination_to(action, klass, pluralized = nil, opt = {})
    if Hash === pluralized
      opt = pluralized
      pluralized = nil
    end

    pluralized ||= klass.to_s.downcase.pluralize

    should "redirect to action if page doesn't exist" do
      params = @params || {}
      get action, params.merge({ :page => 10 })

      assert_response :redirect
      assert_redirected_to params.dup.merge({ :action => action })
    end

    should "add flash message explaining that page doesn't exist" do
      params = @params || {}
      get action, params.merge({ :page => 10 })
      assert_not_nil flash[:error]
      assert_match /no #{pluralized}/, flash[:error]
      assert_match /10/, flash[:error]
    end

    should "not redirect in a loop when there are no #{pluralized}" do
      params = @params || {}
      klass.delete_all if !opt.key?(:delete_all) || opt[:delete_all]

      get action, params

      assert_response :success
    end

    should "redirect to action if page is < 0" do
      params = @params || {}
      get action, params.merge({ :page => -1 })

      assert_response :redirect
      assert_redirected_to params.dup.merge({ :action => action })
    end
  end

  def enable_private_repositories(subject = nil)
    Gitorious::Configuration.prepend("enable_private_repositories" => true)
    return subject.make_private if !subject.nil?

    if defined?(@project)
      @project.make_private
    elsif defined?(@repository)
      @repository.make_private
    end
  end
end

class ActionController::TestCase
  include Gitorious::Authorization

  def setup_ssl_from_config
    return unless Gitorious.ssl?

    @request.env["HTTPS"] = "on"
    @request.env["SERVER_PORT"] = 443
  end

  def self.should_render_in_global_context(options = {})
    should_use_class_macro(
      "Render in global context for actions",
      "renders_in_global_context",
      options
    )
  end

  def self.should_render_in_site_specific_context(options = {})
    should_use_class_macro(
      "Render in site specific context for actions",
      "renders_in_site_specific_context",
      options
    )
  end

  # TODO: This is _horrible_. Refactor to an actual API and use that.
  def self.should_use_class_macro(test_name, macro_name, options = {})
    should test_name do
      filter = extract_class_macro(@controller, macro_name)
      assert_not_nil filter, "Class macro #{macro_name} apparently not in use"

      if !options[:except].blank?
        assert_not_nil filter[:except], "no :except specified in controller"
        assert_equal [*options[:except]].flatten.map(&:to_s).sort, filter[:except]
      end

      if !options[:only].blank?
        assert_not_nil filter[:only], "no :only specified in controller"
        assert_equal [*options[:only]].flatten.map(&:to_s).sort, filter[:only]
      end
    end
  end

  def self.should_verify_method(method, action, params = {})
    should "only allow #{method} for #{action}" do
      actions = ActionController::Routing::HTTP_METHODS - [method]

      actions.each do |method|
        send(method, action, params)
        assert_response 400, "Should disallow #{method} for #{action}"
      end
    end
  end

  def options(action, parameters = nil, session = nil, flash = nil)
    process(action, parameters, session, flash, "OPTIONS")
  end

  def logout
    login_as nil
  end

  # TODO: This is _horrible_. Refactor to an actual API and use that.
  def extract_class_macro(controller, macro)
    klass = controller.class.to_s.underscore
    contents = File.read(Rails.root + "app/controllers/#{klass}.rb")
    regexp = /#{macro}(?:[ ,]+:except => (.*))?(?:[ ,]+:only => (.*))?/
    matches = contents.match(regexp)
    return nil if !matches

    { :except => extract_strings(matches[1]),
      :only => extract_strings(matches[2]) }
  end

  def extract_strings(str)
    matches = str && str.match(/\[(.*)\]/)
    matches && matches[1].split(", ").map { |s| s[1..-1] }.sort
  end
end

class FakeMail
  attr_reader :delivered
  def deliver; @delivered = true; end
end
