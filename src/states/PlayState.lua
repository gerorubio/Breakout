--[[
    GD50
    Breakout Remake

    -- PlayState Class --

    Author: Colton Ogden
    cogden@cs50.harvard.edu

    Represents the state of the game in which we are actively playing;
    player should control the paddle, with the ball actively bouncing between
    the bricks, walls, and the paddle. If the ball goes below the paddle, then
    the player should lose one point of health and be taken either to the Game
    Over screen if at 0 health or the Serve screen otherwise.
]]

PlayState = Class{__includes = BaseState}

--[[
    We initialize what's in our PlayState via a state table that we pass between
    states as we go from playing to serving.
]]
function PlayState:enter(params)
    self.paddle = params.paddle
    self.bricks = params.bricks
    self.health = params.health
    self.score = params.score
    self.highScores = params.highScores

    --Tables to track all balls on screen
    self.balls = {params.ball}

    self.level = 100--params.level

    self.recoverPoints = 5000
    
    --Number of balls
    self.numB = 1

    --Table to store the powers that spawn
    self.powers = {}

    --Points required to increase paddle width
    self.largePaddlePoints = (params.level * 500)
    self.sScore = 0

end

function PlayState:update(dt)
    if self.paused then
        if love.keyboard.wasPressed('space') then
            self.paused = false
            gSounds['pause']:play()
        else
            return
        end
    elseif love.keyboard.wasPressed('space') then
        self.paused = true
        gSounds['pause']:play()
        return
    end

    -- update positions based on velocity
    self.paddle:update(dt)


    -- For each ball in the table balls we need to check if they collide or go
    --outside the screen
    for b, ball in pairs(self.balls) do
        ball:update(dt)

        if ball:collides(self.paddle) then
            ball.y = self.paddle.y - 8
            ball.dy = -ball.dy

            --
            -- tweak angle of bounce based on where it hits the paddle
            --

            -- if we hit the paddle on its left side while moving left...
            if ball.x < self.paddle.x + (self.paddle.width / 2) and self.paddle.dx < 0 then
                ball.dx = -50 + -(8 * (self.paddle.x + self.paddle.width / 2 - ball.x))
            
            -- else if we hit the paddle on its right side while moving right...
            elseif ball.x > self.paddle.x + (self.paddle.width / 2) and self.paddle.dx > 0 then
                ball.dx = 50 + (8 * math.abs(self.paddle.x + self.paddle.width / 2 - ball.x))
            end

            gSounds['paddle-hit']:play()
        end

        -- detect collision across all bricks with the ball
        for k, brick in pairs(self.bricks) do

            -- only check collision if we're in play
            if brick.inPlay and ball:collides(brick) then

                --if it collides there is a chance of spawning a power up
                if love.math.random() > 0.95 then
                    if love.math.random() > 0.5 then
                        table.insert(self.powers, Power(brick.x + (brick.width / 2), brick.y, 10))
                    else
                        table.insert(self.powers, Power(brick.x + (brick.width / 2), brick.y, 9))
                    end
                end

                -- add to score
                self.score = self.score + (brick.tier * 200 + brick.color * 25)
                self.sScore = self.sScore + (brick.tier * 200 + brick.color * 25)

                -- trigger the brick's hit function, which removes it from play
                brick:hit(self.paddle)

                --Check for increasing paddle width
                if self.sScore > self.largePaddlePoints then
                    --Incresing by two times the points required to the next level of width
                    self.largePaddlePoints = self.largePaddlePoints * 2;
                    self.sScore = 0
                    self.paddle:changeWidth(1)
                end

                -- if we have enough points, recover a point of health
                if self.score > self.recoverPoints then
                    -- can't go above 3 health
                    self.health = math.min(3, self.health + 1)

                    -- multiply recover points by 2
                    self.recoverPoints = math.min(100000, self.recoverPoints * 2)

                    -- play recover sound effect
                    gSounds['recover']:play()
                end

                -- go to our victory screen if there are no more bricks left
                if self:checkVictory() then
                    gSounds['victory']:play()

                    --Reset paddle to balance a little bit the game
                    if self.paddle.size > 1 then
                        self.paddle:reset()
                    end
                    self.paddle.key = false

                    gStateMachine:change('victory', {
                        level = self.level,
                        paddle = self.paddle,
                        health = self.health,
                        score = self.score,
                        highScores = self.highScores,
                        ball = self.ball,
                        recoverPoints = self.recoverPoints
                    })
                end

                --
                -- collision code for bricks
                --
                -- we check to see if the opposite side of our velocity is outside of the brick;
                -- if it is, we trigger a collision on that side. else we're within the X + width of
                -- the brick and should check to see if the top or bottom edge is outside of the brick,
                -- colliding on the top or bottom accordingly 
                --

                -- left edge; only check if we're moving right, and offset the check by a couple of pixels
                -- so that flush corner hits register as Y flips, not X flips
                if ball.x + 2 < brick.x and ball.dx > 0 then
                    
                    -- flip x velocity and reset position outside of brick
                    ball.dx = -ball.dx
                    ball.x = brick.x - 8
                
                -- right edge; only check if we're moving left, , and offset the check by a couple of pixels
                -- so that flush corner hits register as Y flips, not X flips
                elseif ball.x + 6 > brick.x + brick.width and ball.dx < 0 then
                    
                    -- flip x velocity and reset position outside of brick
                    ball.dx = -ball.dx
                    ball.x = brick.x + 32
                
                -- top edge if no X collisions, always check
                elseif ball.y < brick.y then
                    
                    -- flip y velocity and reset position outside of brick
                    ball.dy = -ball.dy
                    ball.y = brick.y - 8
                
                -- bottom edge if no X collisions or top collision, last possibility
                else
                    
                    -- flip y velocity and reset position outside of brick
                    ball.dy = -ball.dy
                    ball.y = brick.y + 16
                end

                -- slightly scale the y velocity to speed up the game, capping at +- 150
                if math.abs(ball.dy) < 150 then
                    ball.dy = ball.dy * 1.02
                end

                -- only allow colliding with one brick, for corners
                break
            end
        end

        -- if ball goes below bounds, revert to serve state and decrease health
        if ball.y >= VIRTUAL_HEIGHT then
            self.numB = self.numB - 1
            table.remove(self.balls, b)
            if self.numB == 0 then
                self.health = self.health - 1
                gSounds['hurt']:play()

                --When we loss a life we are going to change the width of the paddle
                self.paddle:changeWidth(-1)

                if self.health == 0 then
                    gStateMachine:change('game-over', {
                        score = self.score,
                        highScores = self.highScores
                    })
                else
                    gStateMachine:change('serve', {
                        paddle = self.paddle,
                        bricks = self.bricks,
                        health = self.health,
                        score = self.score,
                        highScores = self.highScores,
                        level = self.level,
                        recoverPoints = self.recoverPoints
                    })
                end
            end
        end
    end

    --If a power collides with the paddle the effect will acvtivate
    for k, power in pairs(self.powers) do
        if power:collides(self.paddle) then
            if power.skin == 9 then
                power:addBalls(self.balls)
                self.numB = self.numB + 2
            else
                power:addKey(self.paddle)
            end
            table.remove(self.powers, k)
        end
    end

    -- For moving each power going down
    for k, power in pairs(self.powers) do
        power:update(dt)
    end

    -- for rendering particle systems
    for k, brick in pairs(self.bricks) do
        brick:update(dt)
    end

    if love.keyboard.wasPressed('escape') then
        love.event.quit()
    end
end

function PlayState:render()
    -- render bricks
    for k, brick in pairs(self.bricks) do
        brick:render()
    end

    -- render all particle systems
    for k, brick in pairs(self.bricks) do
        brick:renderParticles()
    end

    --render all powers
    for k, power in pairs(self.powers) do
        power:render()
    end

    self.paddle:render()

    for b, ball in pairs(self.balls)  do
        ball:render()
    end

    renderScore(self.score)
    renderHealth(self.health)
    renderKey(self.paddle)

    -- pause text, if paused
    if self.paused then
        love.graphics.setFont(gFonts['large'])
        love.graphics.printf("PAUSED", 0, VIRTUAL_HEIGHT / 2 - 16, VIRTUAL_WIDTH, 'center')
    end
end

function PlayState:checkVictory()
    if #self.bricks == 1 then
        if self.bricks[1].color == 0 then
            return true
        end
    end

    for k, brick in pairs(self.bricks) do
        if brick.inPlay and brick.color ~= 0 then
            return false
        end 
    end

    return true
end