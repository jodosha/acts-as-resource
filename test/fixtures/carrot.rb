class Carrot
  acts_as_resource
  self.site = 'http://localhost:3000'
  
  belongs_to :bunny

  validates_presence_of :color
  validates_uniqueness_of :color
  validates_length_of :color, :within => 2..23,
                      :if => lambda { |c| c.color && !c.color.empty? }
  validates_format_of :color,
                      :with => /[\w\s]+$/,
                      :if => lambda { |c| c.color && !c.color.empty? }

  before_create :please_call_me_before_create
  def self.validate
    logger.debug("VALIDATE #{title}")
  end
  
  def please_call_me_before_create
    logger.debug("Ohhh, so you called me..")
  end  
end