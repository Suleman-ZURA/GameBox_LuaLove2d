-- Updated Bird.lua
Bird = Class{}  -- Using class system

function Bird:init(image)
  -- Use the passed image or fall back to default
  self.image = image or love.graphics.newImage('Assets/birddrawing1.png')
  
  -- Initialize properties using the actual image
  self.x = 75
  self.y = 180
  self.width = self.image:getWidth()
  self.height = self.image:getHeight()
  self.gravity = 0
end

function Bird:update(dt)
  self.gravity = self.gravity + 956 * dt
  self.y = self.y + self.gravity * dt
end

function Bird:jump()
  if self.y > 0 then
    self.gravity = -265
  end
end

function Bird:collision(p)
  if self.x > p.x + p.width or p.x > self.x + self.width then
    return false
  end
  if self.y > p.y + p.height or p.y > self.y + self.height then
    return false
  end
  return true
end

function Bird:render()
  love.graphics.draw(self.image, self.x, self.y)
  love.graphics.setColor(1, 1, 1)
end