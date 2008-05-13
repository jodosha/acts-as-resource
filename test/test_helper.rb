require File.expand_path(File.dirname(__FILE__) + "/../../../../config/environment")
require 'test_help'
require 'active_resource/http_mock'

class Test::Unit::TestCase
  def assert_same_object(expected, actual)
    assert_instance_of(expected.class, actual)
    expected.attributes.each do |k,v|
      assert_equal(v, actual.send(k))
    end
  end
end
