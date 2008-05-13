require 'test/unit'
require File.dirname(__FILE__) + '/test_helper'
require File.dirname(__FILE__) + '/fixtures/bunny'
require File.dirname(__FILE__) + '/fixtures/carrot'

class ActsAsResourceTest < Test::Unit::TestCase
  def setup
    @bugs   = Bunny.find(1)
    @roger  = Bunny.find(2)
    @orange = Carrot.find(1)
    
    @remote_roger   = { :first_name => @bugs.first_name, :last_name => @bugs.last_name }.to_xml(:root => 'bunny')
    @remote_orange  = { :color => @orange.color, :bunny_id => "1" }.to_xml(:root => 'carrot')
    @remote_cyan    = { :id => 2, :color => 'cyan', :bunny_id => "1"}.to_xml(:root => 'carrot')
    
    @conn = ActiveResource::Connection.new('http://localhost')
    @headers = {}
    
    @default_request_headers = { 'Content-Type' => 'application/xml' }
    ActiveResource::HttpMock.respond_to do |mock|
      mock.post   "/bunnies.xml",     {}, @remote_roger,  201, 'Location' => '/bunnies/1.xml'
      mock.post   "/carrots.xml",     {}, @remote_orange, 201, 'Location' => '/carrots/1.xml'
      mock.get    "/carrots/1.xml",   {}, @remote_orange # rails <= 2.0.x
      mock.head   "/carrots/1.xml",   {}, @remote_orange # rails => 2.1.x
      mock.get    "/carrots/2.xml",   {}, @remote_cyan
      mock.get    "/bunnies/1.xml",   {}, @remote_roger
      mock.put    "/carrots/1.xml",   {}, nil, 204
      mock.delete "/carrots/2.xml",   {}, nil, 200
      mock.get    "/carrots/99.xml",  {}, nil, 404 # rails <= 2.0.x
      mock.head   "/carrots/99.xml",  {}, nil, 404 # rails => 2.1.x
    end
  end
  
  def test_init
    # local
    bunny = Bunny.new(:first_name => @bugs.first_name, :last_name => @bugs.last_name)
    assert_instance_of(Bunny, bunny)
    assert_equal(@bugs.first_name, bunny.first_name)
    assert_equal(@bugs.last_name,  bunny.last_name)
    assert_kind_of(Labs23::Acts::Resource::LocalResource, bunny.storage)
    assert !bunny.remote?

    carrot = Carrot.new(:color => @orange.color, :bunny_id => @orange.bunny)
    assert_instance_of(Carrot, carrot)
    assert_equal(@orange.color,  carrot.color)
    assert_same_object(@orange.bunny, carrot.bunny)
    assert_kind_of(Labs23::Acts::Resource::LocalResource, carrot.storage)
    assert !carrot.remote?
    
    # remote
    bunny = Bunny.new(:first_name => @bugs.first_name, :last_name => @bugs.last_name, :remote => true)
    assert_kind_of(Bunny, bunny)
    assert_equal(@bugs.first_name, bunny.first_name)
    assert_equal(@bugs.last_name,  bunny.last_name)
    assert_kind_of(Labs23::Acts::Resource::RemoteResource, bunny.storage)
    assert bunny.remote?
    
    carrot = Carrot.new(:color => @orange.color, :remote => true)
    assert_kind_of(Carrot, carrot)
    assert_equal(@orange.color, carrot.color)
    assert_kind_of(Labs23::Acts::Resource::RemoteResource, carrot.storage)
    assert carrot.remote?
  end
  
  # LOCAL
  def test_local_create
    bunny = Bunny.new(:first_name => 'Buster', :last_name => 'Bunny')
    assert bunny.save
    assert bunny.reload
    assert_equal('Buster', bunny.first_name)
    
    carrot = Carrot.new(:color => 'red', :bunny_id => bunny.id)
    assert carrot.save
    assert carrot.reload
    assert_equal('red', carrot.color)
    assert_same_object(bunny, carrot.bunny)
  end
  
  def test_local_read
    bunny = Bunny.find(:first)
    assert_same_object(@bugs, bunny)
    
    bunny = Bunny.find(1)
    assert_same_object(@bugs, bunny)
    
    bunny = Bunny.find_by_first_name(@bugs.first_name)
    assert_same_object(@bugs, bunny)
    
    bunny = Bunny.find_by_first_name_and_last_name(@bugs.first_name, @bugs.last_name)
    assert_same_object(@bugs, bunny)
    
    bunny = Bunny.find(1, :conditions => [ "first_name = ?", @bugs.first_name ])
    assert_same_object(@bugs, bunny)
    
    bunny = Bunny.find_by_sql(["select * from bunnies where id = ?", @bugs.id])
    assert_same_object(@bugs, bunny)
    
    assert Bunny.find_by_sql([ "select * from bunnies where id = ?", 99 ]).empty?
    
    assert_raise(ArgumentError) { Bunny.find_by_sql("select * from bunnies", :remote => true)  }
    
    assert_raise(ActiveRecord::RecordNotFound) { Bunny.find(99) }
    
    assert_nil(Bunny.find_by_first_name('uncatchable'))
    
    bunnies = Bunny.find(:all)
    assert !bunnies.empty?
    bunnies.each { |bunny| assert_instance_of(Bunny, bunny) }
    
    bunnies = Bunny.find([1, 2])
    assert !bunnies.empty?
    bunnies.each { |bunny| assert_instance_of(Bunny, bunny) }
    
    bunnies = Bunny.find(1, 2)
    assert !bunnies.empty?
    bunnies.each { |bunny| assert_instance_of(Bunny, bunny) }    
  end
  
  def test_local_update
    @roger.first_name = 'R'
    assert @roger.save
    assert_equal('R', @roger.first_name)
    
    assert @roger.update_attribute(:first_name, 'Rog')
    assert_equal('Rog', @roger.first_name)
    
    assert @roger.update_attributes(:first_name => 'Roger')
    assert_equal('Roger', @roger.first_name)
    
    assert_same_object(@bugs, @orange.bunny)
    @orange.bunny = @roger
    assert @orange.save
    assert_equal(@roger.first_name, @orange.bunny.first_name)
  end
  
  def test_local_destroy
    bunny = Bunny.create(:first_name => 'Sweetie', :last_name => 'Bunny')
    assert bunny.destroy
    assert_nil(Bunny.find_by_first_name('Sweetie'))
  end
  
  # REMOTE
  def test_remote_create
    bunny = Bunny.new(:first_name => @bugs.first_name, :last_name => @bugs.last_name, :remote => true)
    assert bunny.save
    assert_equal("1", bunny.id)
    
    carrot = Carrot.new(:color => @orange.color, :bunny_id => bunny, :remote => true)
    assert carrot.save
    assert_equal("1", carrot.id)
  end
  
  def test_remote_read
    carrot = Carrot.find(1, :remote => true)
    assert_instance_of(Carrot, carrot)
    assert_kind_of(Labs23::Acts::Resource::RemoteResource, carrot.storage)
    assert_equal(@orange.color, carrot.color)
    
    assert_raise(ActiveResource::ResourceNotFound) { Carrot.find(99, :remote => true) }
  end
  
  def test_remote_update
    carrot = Carrot.find(1, :remote => true)
    carrot.color = 'cyan'
    assert carrot.save
  end
  
  def test_remote_destroy
    assert Carrot.find(2, :remote => true).destroy
  end
  
  # OTHER
  def test_remote
    assert !Bunny.new.remote?
    assert  Bunny.new(:remote => true).remote?
  end
  
  def test_exists
    assert Carrot.exists?(1)
    assert Carrot.exists?(1, :remote => true)
    
    assert !Carrot.exists?(99)
    assert !Carrot.exists?(99, :remote => true)
  end
  
  def test_validates_presence_of
    carrot = Carrot.new(:bunny_id => @roger)
    assert !carrot.save
    assert_equal(1, carrot.errors.count)
    assert_equal(ActiveRecord::Errors::default_error_messages[:blank], carrot.errors.on(:color))
  end
  
  def test_validates_uniqueness_of
    carrot = Carrot.new(:color => @orange.color, :bunny_id => @orange.bunny)
    assert !carrot.save
    assert_equal(1, carrot.errors.count)
    assert_equal(ActiveRecord::Errors::default_error_messages[:taken], carrot.errors.on(:color))
  end
  
  def test_validates_length_of
    carrot = Carrot.new(:color => 'a', :bunny => @orange.bunny)
    assert !carrot.save
    assert_equal(1, carrot.errors.count)
    assert_equal(ActiveRecord::Errors::default_error_messages[:too_short] % 2, carrot.errors.on(:color))
  end

  def test_element_name
    assert_equal('carrot', Carrot.find(1, :remote => true).storage.class.element_name)
    assert_equal('bunny',  Bunny.find(1,  :remote => true).storage.class.element_name)
  end
end