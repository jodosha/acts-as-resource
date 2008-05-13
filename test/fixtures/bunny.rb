class Bunny
  acts_as_resource

  self.site = 'http://localhost:3001'
  has_many :carrots
end