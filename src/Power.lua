--[[
	Power class

	Represents the powers that will spawn sometimes when the ball hits a brick
	Each power have a skin and a unique ability
]]--
Power = Class{}

function Power:init(x, y, skin)
	
	self.x = x
	self.y = y

	self.width = 16
	self.height = 16

	self.dy = 0

	self.skin = skin
end

function Power:collides(paddle)
	if self.x > paddle.x + paddle.width or paddle.x > self.x + self.width then
		return false
	end

	if self.y > paddle.y + paddle.height or paddle.y > self.y + self.height then
	    return false
	end

	return true
end

function Power:update(dt)
	self.y = self.y + 2
end

function Power:render()
    love.graphics.draw(gTextures['main'], gFrames['powers'][self.skin],
        self.x, self.y)
end

-- Power of adding 2 extra balls, the balls are insert into a table of balls
function Power:addBalls(balls)
	for i = 1, 2 do
		ball = Ball(math.random(7))
		ball.x = balls[1].x
		ball.y = balls[1].y
		table.insert(balls, ball)
	end
end

function Power:addKey(paddle)
	paddle.key = true
end