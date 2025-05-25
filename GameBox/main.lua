-- Combined Game Box: Tetris, Flappy Bird, and Space War

local math = require 'math'
local json = require 'json' -- Ensure json is required globally for all games that use it

love.graphics.setDefaultFilter('nearest','nearest')

-- --- Class.lua content (from Flappy Bird) ---
-- This section is included for the Flappy Bird game's Class system.
local function include_helper(to, from, seen)
    if from == nil then
        return to
    elseif type(from) ~= 'table' then
        return from
    elseif seen[from] then
        return seen[from]
    end

    seen[from] = to
    for k,v in pairs(from) do
        k = include_helper({}, k, seen) -- keys might also be tables
        if to[k] == nil then
            to[k] = include_helper({}, v, seen)
        end
    end
    return to
end

local function include(class, other)
    return include_helper(class, other, {})
end

local function clone(other)
    return setmetatable(include({}, other), getmetatable(other))
end

local function new(class)
    class = class or {}
    local inc = class.__includes or {}
    if getmetatable(inc) then inc = {inc} end

    for _, other in ipairs(inc) do
        if type(other) == "string" then
            other = _G[other]
        end
        include(class, other)
    end

    class.__index = class
    class.init    = class.init    or class[1] or function() end
    class.include = class.include or include
    class.clone   = class.clone   or clone

    return setmetatable(class, {__call = function(c, ...)
        local o = setmetatable({}, c)
        o:init(...)
        return o
    end})
end

if _G.class_commons ~= false and not _G.common then
    _G.common = {}
    function _G.common.class(name, prototype, parent)
        return new{__includes = {prototype, parent}}
    end
    function _G.common.instance(class, ...)
        return class(...)
    end
end

Class = setmetatable({new = new, include = include, clone = clone},
    {__call = function(_,...) return new(...) end})
-- --- End Class.lua content ---


-- --- Flappy Bird: Bird Class ---
Bird = Class{}

function Bird:init(image)
    self.image = image
    self.x = 75
    self.y = 180
    self.width = self.image:getWidth()
    self.height = self.image:getHeight()
    self.gravity = 0
    self.rotation = 0
end

function Bird:update(dt)
    self.gravity = self.gravity + 956 * dt
    self.y = self.y + self.gravity * dt

    -- Simple rotation based on velocity
    if self.gravity < 0 then
        self.rotation = math.max(-0.5, self.rotation - 5 * dt) -- Rotate up
    else
        self.rotation = math.min(0.8, self.rotation + 3 * dt) -- Rotate down
    end
end

function Bird:jump()
    if self.y > 0 then -- Prevent jumping if already above screen (though collision should handle)
        self.gravity = -265
        self.rotation = -0.5 -- Immediate upward tilt
    end
end

function Bird:collision(p)
    if not p or not p.x or not p.width or not p.y or not p.height then return false end
    if self.x + self.width < p.x or p.x + p.width < self.x then
        return false
    end
    if self.y + self.height < p.y or p.y + p.height < self.y then
        return false
    end
    return true
end

function Bird:render()
    love.graphics.draw(self.image, self.x + self.width/2, self.y + self.height/2, self.rotation, 1, 1, self.width/2, self.height/2)
end
-- --- End Bird.lua content ---


-- --- Flappy Bird: DownwardPipes Class ---
DownwardPipes = Class{}

function DownwardPipes:init(x, y, image)
    self.image = image
    self.x = x
    self.y = y
    self.width = self.image:getWidth()
    self.height = self.image:getHeight()
    self.speed = 140 -- Adjusted speed
end

function DownwardPipes:update(dt)
    self.x = self.x - self.speed * dt
end

function DownwardPipes:render()
    love.graphics.draw(self.image, self.x , self.y)
end

function DownwardPipes:reset(x, y)
    self.x = x
    self.y = y
end
-- --- End downwardPipes.lua content ---


-- --- Flappy Bird: Ground Class ---
Ground = Class{}

function Ground:init(x, y, width, height, color)
    self.x = x
    self.y = y
    self.width = width
    self.height = height
    self.color = color
end

function Ground:render()
    love.graphics.setColor(self.color)
    love.graphics.rectangle('fill', self.x, self.y, self.width, self.height)
    love.graphics.setColor(1, 1, 1) -- Reset color
end
-- --- End Ground.lua content ---


-- --- Flappy Bird: UpwardPipes Class ---
UpwardPipes = Class{}

function UpwardPipes:init(x, y, image)
    self.image = image
    self.x = x
    self.y = y
    self.width = self.image:getWidth()
    self.height = self.image:getHeight()
    self.speed = 140 -- Adjusted speed
end

function UpwardPipes:update(dt)
    self.x = self.x - self.speed * dt
end

function UpwardPipes:render()
    love.graphics.draw(self.image, self.x, self.y)
end

function UpwardPipes:reset(x, y)
    self.x = x
    self.y = y
end
-- --- End upwardPipes.lua content ---


-- --- FlappyBirdGame Object Definition ---
FlappyBirdGame = {
    currentGameState = "menu", -- "menu", "characterSelect", "game", "gameOver"
    gamePaused = false,
    selectedMenuOption = 1,
    selectedCharacter = 1,

    score = 0,
    upcomingPipe = 1,
    player = nil,
    pipe1 = nil, pipe2 = nil, pipe3 = nil, pipe4 = nil,
    dirt = nil, grass = nil,

    font = nil, menuFont = nil, titleFont = nil,
    backgroundImage = nil,
    pipeDownImage = nil, pipeUpImage = nil,
    scoreSound = nil,
    characterImages = {},

    -- Flappy Bird's own dimensions (400x600)
    WINDOW_WIDTH = 600,
    WINDOW_HEIGHT = 450,

    characterOptions = {
        {name = "Bird 1", imagePath = 'Assets/birddrawing1.png'},
        {name = "Bird 2", imagePath = 'Assets/birddrawing.png'},
    },
    pauseMenuOptions = {"Resume", "Return to Game Box"},

    skyBlue = {.43, .77, .80},
    purple = {0.58, 0.44, 0.86},
    darkPurple = {0.37, 0.31, 0.63},
    menuOverlayColor = {0.2, 0.2, 0.2, 0.8},

    isInitialized = false,

    init = function(self)
        if self.isInitialized then return end

        local success
        success, self.font = pcall(love.graphics.newFont, 'Fonts/DIMIS___.TTF', 30)
        if not success then print("Error loading FlappyBird font: " .. tostring(self.font)) end
        success, self.menuFont = pcall(love.graphics.newFont, 'Fonts/DIMIS___.TTF', 25)
        if not success then print("Error loading FlappyBird menuFont: " .. tostring(self.menuFont)) end
        success, self.titleFont = pcall(love.graphics.newFont, 'Fonts/DIMIS___.TTF', 30)
        if not success then print("Error loading FlappyBird titleFont: " .. tostring(self.titleFont)) end

        success, self.backgroundImage = pcall(love.graphics.newImage, 'Assets/gamebackground.jpg')
        if not success then print("Error loading FlappyBird backgroundImage: " .. tostring(self.backgroundImage)) end
        success, self.pipeDownImage = pcall(love.graphics.newImage, 'Assets/Pipe-down.png')
        if not success then print("Error loading FlappyBird pipeDownImage: " .. tostring(self.pipeDownImage)) end
        success, self.pipeUpImage = pcall(love.graphics.newImage, 'Assets/Pipe-up.png')
        if not success then print("Error loading FlappyBird pipeUpImage: " .. tostring(self.pipeUpImage)) end

        success, self.scoreSound = pcall(love.audio.newSource, 'Sound effects/score.wav', 'static')
        if not success then print("Error loading FlappyBird scoreSound: " .. tostring(self.scoreSound)) end

        for i, char in ipairs(self.characterOptions) do
            local imgSuccess, img = pcall(love.graphics.newImage, char.imagePath)
            if imgSuccess then
                self.characterImages[i] = img
            else
                print("Error loading character image " .. char.imagePath .. ": " .. tostring(img))
                self.characterImages[i] = love.graphics.newImage(love.image.newImageData(32,32))
            end
        end
        self.isInitialized = true
        print("FlappyBirdGame initialized.")
    end,

    startGame = function(self, birdImagePath)
        if not self.isInitialized then self:init() end

        self.score = 0
        self.upcomingPipe = 1
        self.currentGameState = "game"
        self.gamePaused = false

        local birdImgSuccess, selectedBirdImage = pcall(love.graphics.newImage, birdImagePath)
        if not birdImgSuccess then
            print("Error loading bird image for game start: " .. birdImagePath)
            selectedBirdImage = self.characterImages[1] or love.graphics.newImage(love.image.newImageData(32,32))
        end
        self.player = Bird(selectedBirdImage)

        self.dirt = Ground(0, self.WINDOW_HEIGHT - 60, self.WINDOW_WIDTH, 60, self.darkPurple)
        self.grass = Ground(0, self.WINDOW_HEIGHT - 75, self.WINDOW_WIDTH, 15, self.purple)

        local pipeGap = 115
        local pipeHeight = self.pipeDownImage:getHeight() +20

        local function CreatePipes(xPos)
            local maxTopPipeY = -40
            local minTopPipeY = - (pipeHeight - 90)
            local topPipeBottomY = love.math.random(minTopPipeY, maxTopPipeY)

            local newPipe1 = DownwardPipes(xPos, topPipeBottomY, self.pipeDownImage)
            local newPipe2 = UpwardPipes(xPos, topPipeBottomY + pipeHeight + pipeGap, self.pipeUpImage)
            return newPipe1, newPipe2
        end

        self.pipe1, self.pipe2 = CreatePipes(self.WINDOW_WIDTH + 50)
        self.pipe3, self.pipe4 = CreatePipes(self.WINDOW_WIDTH + 50 + (self.WINDOW_WIDTH / 2)+50)
    end,

    update = function(self, dt)
        if self.currentGameState ~= "game" or self.gamePaused or not self.player then return end

        local pipePairSpacing = 325

        if self.pipe1.x + self.pipe1.width < 0 then
            local pipeGap = 115; local pipeHeight = self.pipeDownImage:getHeight()
            local maxTopPipeY = -40; local minTopPipeY = - (pipeHeight - 90)
            local topPipeBottomY = love.math.random(minTopPipeY, maxTopPipeY)
            self.pipe1:reset(self.pipe3.x + pipePairSpacing, topPipeBottomY)
            self.pipe2:reset(self.pipe3.x + pipePairSpacing, topPipeBottomY + pipeHeight + pipeGap)
        end

        if self.pipe3.x + self.pipe3.width < 0 then
            local pipeGap = 115; local pipeHeight = self.pipeDownImage:getHeight()
            local maxTopPipeY = -40; local minTopPipeY = - (pipeHeight - 90)
            local topPipeBottomY = love.math.random(minTopPipeY, maxTopPipeY)
            self.pipe3:reset(self.pipe1.x + pipePairSpacing, topPipeBottomY)
            self.pipe4:reset(self.pipe1.x + pipePairSpacing, topPipeBottomY + pipeHeight + pipeGap)
        end

        self.player:update(dt)
        if self.pipe1 then self.pipe1:update(dt) end; if self.pipe2 then self.pipe2:update(dt) end
        if self.pipe3 then self.pipe3:update(dt) end; if self.pipe4 then self.pipe4:update(dt) end

        if self.player:collision(self.pipe1) or self.player:collision(self.pipe2) or
           self.player:collision(self.pipe3) or self.player:collision(self.pipe4) or
           self.player:collision(self.grass) or
           self.player.y < -self.player.height then
            self.currentGameState = "gameOver"
        end

        if self.upcomingPipe == 1 and self.player.x > (self.pipe1.x + self.pipe1.width) then
            self.score = self.score + 1; self.upcomingPipe = 2
            if self.scoreSound and not self.scoreSound:isPlaying() then self.scoreSound:play() end
        end
        if self.upcomingPipe == 2 and self.player.x > (self.pipe3.x + self.pipe3.width) then
            self.score = self.score + 1; self.upcomingPipe = 1
            if self.scoreSound and not self.scoreSound:isPlaying() then self.scoreSound:play() end
        end
    end,

    draw = function(self)
        if not self.isInitialized then return end

        -- Save the current graphics state
        love.graphics.push()

        -- Set up a centered viewport for Flappy Bird
        local scaleX = love.graphics.getWidth() / self.WINDOW_WIDTH
        local scaleY = love.graphics.getHeight() / self.WINDOW_HEIGHT
        local scale = math.min(scaleX, scaleY)
        local offsetX = (love.graphics.getWidth() - self.WINDOW_WIDTH * scale) / 2
        local offsetY = (love.graphics.getHeight() - self.WINDOW_HEIGHT * scale) / 2

        love.graphics.translate(offsetX, offsetY)
        love.graphics.scale(scale, scale)

        love.graphics.setColor(1,1,1,1)
        if self.font then love.graphics.setFont(self.font) else love.graphics.setFont(love.graphics.getFont()) end

        if self.backgroundImage then
             love.graphics.draw(self.backgroundImage, 0, 0, 0, self.WINDOW_WIDTH / self.backgroundImage:getWidth(), self.WINDOW_HEIGHT / self.backgroundImage:getHeight())
        else
            love.graphics.setColor(self.skyBlue)
            love.graphics.rectangle("fill", 0,0, self.WINDOW_WIDTH, self.WINDOW_HEIGHT)
            love.graphics.setColor(1,1,1,1)
        end

        if self.currentGameState == "menu" then
            self:drawFlappyMainMenuScreen()
        elseif self.currentGameState == "characterSelect" then
            self:drawCharacterSelectScreen()
        elseif self.currentGameState == "game" then
            self:drawGamePlayScreen()
        elseif self.currentGameState == "gameOver" then
            self:drawGamePlayScreen()
            self:drawGameOverlayScreen()
        end

        love.graphics.pop()
    end,

    keypressed = function(self, key)
        if not self.isInitialized then return end

        if self.currentGameState == "gameOver" then
            if key == 'return' then
                self:startGame(self.characterOptions[self.selectedCharacter].imagePath)
            elseif key == 'escape' then
                self.currentGameState = "menu"
                -- Ensure all game music is stopped when returning to main menu
                if tetris_gameMusic and tetris_gameMusic:isPlaying() then tetris_gameMusic:stop() end
                if SpaceWarGame.game_music and SpaceWarGame.game_music:isPlaying() then SpaceWarGame.game_music:stop() end
                globalGameMode = "mainMenu"
                love.window.setTitle("Game Box") -- Reset title when returning to main menu
            end
        elseif self.currentGameState == "characterSelect" then
            if key == 'left' then
                self.selectedCharacter = self.selectedCharacter - 1
                if self.selectedCharacter < 1 then self.selectedCharacter = #self.characterOptions end
            elseif key == 'right' then
                self.selectedCharacter = self.selectedCharacter + 1
                if self.selectedCharacter > #self.characterOptions then self.selectedCharacter = 1 end
            elseif key == 'return' then
                self:startGame(self.characterOptions[self.selectedCharacter].imagePath)
            elseif key == 'escape' then
                self.currentGameState = "menu"
                -- Ensure all game music is stopped when returning to main menu
                if tetris_gameMusic and tetris_gameMusic:isPlaying() then tetris_gameMusic:stop() end
                if SpaceWarGame.game_music and SpaceWarGame.game_music:isPlaying() then SpaceWarGame.game_music:stop() end
                globalGameMode = "mainMenu"
                love.window.setTitle("Game Box") -- Reset title when returning to main menu
            end
        elseif self.currentGameState == "menu" then
            if key == 'return' then
                self.currentGameState = "characterSelect"
            elseif key == 'escape' then
                -- Ensure all game music is stopped when returning to main menu
                if tetris_gameMusic and tetris_gameMusic:isPlaying() then tetris_gameMusic:stop() end
                if SpaceWarGame.game_music and SpaceWarGame.game_music:isPlaying() then SpaceWarGame.game_music:stop() end
                globalGameMode = "mainMenu"
                love.window.setTitle("Game Box") -- Reset title when returning to main menu
            end
        elseif self.currentGameState == "game" then
            if key == 'escape' then
                self.gamePaused = not self.gamePaused
                if self.gamePaused then self.selectedMenuOption = 1 end
            end

            if self.gamePaused then
                if key == 'up' then
                    self.selectedMenuOption = self.selectedMenuOption - 1
                    if self.selectedMenuOption < 1 then self.selectedMenuOption = #self.pauseMenuOptions end
                elseif key == 'down' then
                    self.selectedMenuOption = self.selectedMenuOption + 1
                    if self.selectedMenuOption > #self.pauseMenuOptions then self.selectedMenuOption = 1 end
                elseif key == 'return' then
                    if self.pauseMenuOptions[self.selectedMenuOption] == "Resume" then
                        self.gamePaused = false
                    elseif self.pauseMenuOptions[self.selectedMenuOption] == "Return to Game Box" then
                        -- Ensure all game music is stopped when returning to main menu
                        if tetris_gameMusic and tetris_gameMusic:isPlaying() then tetris_gameMusic:stop() end
                        if SpaceWarGame.game_music and SpaceWarGame.game_music:isPlaying() then SpaceWarGame.game_music:stop() end
                        globalGameMode = "mainMenu"
                        self.gamePaused = false
                        self.currentGameState = "menu"
                        love.window.setTitle("Game Box") -- Reset title when returning to main menu
                    end
                end
            else
                if key == 'space' and self.player then
                    self.player:jump()
                end
            end
        end
    end,

    drawFlappyMainMenuScreen = function(self)
        love.graphics.setColor(self.menuOverlayColor)
        love.graphics.rectangle('fill', 0, 0, self.WINDOW_WIDTH, self.WINDOW_HEIGHT)
        love.graphics.setColor(1, 1, 1)
        if self.titleFont then love.graphics.setFont(self.titleFont) end
        love.graphics.printf("Flappy Bird!", 0, 100, self.WINDOW_WIDTH, 'center')
        if self.menuFont then love.graphics.setFont(self.menuFont) end
        love.graphics.printf("Press ENTER to start", 0, 200, self.WINDOW_WIDTH, 'center')
        love.graphics.printf("Press ESC for Game Box Menu", 0, 250, self.WINDOW_WIDTH, 'center')
    end,

    drawCharacterSelectScreen = function(self)
        love.graphics.setColor(self.purple)
        love.graphics.rectangle('fill', 0, 0, self.WINDOW_WIDTH, self.WINDOW_HEIGHT)

        love.graphics.setColor(0,0,0)
        if self.titleFont then love.graphics.setFont(self.titleFont) end
        love.graphics.printf("Flappy Bird", 0, 50, self.WINDOW_WIDTH, 'center')

        love.graphics.setColor(1,1,1)
        local choiceFont = self.menuFont
        if choiceFont then love.graphics.setFont(choiceFont) end
        love.graphics.printf("CHOOSE YOUR CHARACTER", 0, 120, self.WINDOW_WIDTH, 'center')

        local containerSize = 120; local padding = 20
        local totalWidth = (#self.characterOptions * containerSize) + ((#self.characterOptions - 1) * padding)
        local startX = (self.WINDOW_WIDTH - totalWidth) / 2

        for i, charData in ipairs(self.characterOptions) do
            local containerX = startX + (i-1) * (containerSize + padding)
            local containerY = self.WINDOW_HEIGHT / 2 - containerSize / 2

            if i == self.selectedCharacter then
                love.graphics.setColor(1, 0.84, 0); love.graphics.setLineWidth(4)
            else
                love.graphics.setColor(0.3, 0.3, 0.3); love.graphics.setLineWidth(2)
            end
            love.graphics.rectangle('line', containerX, containerY, containerSize, containerSize)

            local img = self.characterImages[i]
            if img then
                local scale = math.min((containerSize - 20) / img:getWidth(), (containerSize - 20) / img:getHeight())
                love.graphics.setColor(1, 1, 1)
                love.graphics.draw(img, containerX + containerSize/2, containerY + containerSize/2, 0, scale, scale, img:getWidth()/2, img:getHeight()/2)
            end
        end
        love.graphics.setLineWidth(1)

        if choiceFont then love.graphics.setFont(choiceFont) end
        love.graphics.setColor(1,1,1)
        love.graphics.printf("Use LEFT/RIGHT arrows to select", 0, self.WINDOW_HEIGHT - 120, self.WINDOW_WIDTH, 'center')
        love.graphics.printf("Press ENTER to confirm", 0, self.WINDOW_HEIGHT - 90, self.WINDOW_WIDTH, 'center')
        love.graphics.printf("Press ESC for Flappy Menu", 0, self.WINDOW_HEIGHT - 60, self.WINDOW_WIDTH, 'center')
    end,

    drawGameOverlayScreen = function(self)
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle('fill', 0, 0, self.WINDOW_WIDTH, self.WINDOW_HEIGHT)
        love.graphics.setColor(1, 1, 1)
        if self.titleFont then love.graphics.setFont(self.titleFont) end
        love.graphics.printf("GAME OVER", 0, self.WINDOW_HEIGHT/2 - 80, self.WINDOW_WIDTH, 'center')
        if self.font then love.graphics.setFont(self.font) end
        love.graphics.printf("Score: " .. self.score, 0, self.WINDOW_HEIGHT/2 - 30, self.WINDOW_WIDTH, 'center')

        local instructionFont = self.menuFont
        if instructionFont then love.graphics.setFont(instructionFont) end
        love.graphics.printf("Press ENTER to restart", 0, self.WINDOW_HEIGHT/2 + 30, self.WINDOW_WIDTH, 'center')
        love.graphics.printf("Press ESC for Flappy Menu", 0, self.WINDOW_HEIGHT/2 + 60, self.WINDOW_WIDTH, 'center')
    end,

    drawGamePlayScreen = function(self)
        if self.pipe1 then self.pipe1:render() end; if self.pipe2 then self.pipe2:render() end
        if self.pipe3 then self.pipe3:render() end; if self.pipe4 then self.pipe4:render() end
        if self.player then self.player:render() end
        if self.grass then self.grass:render() end; if self.dirt then self.dirt:render() end

        love.graphics.setColor(0,0,0)
        if self.font then love.graphics.setFont(self.font) end
        love.graphics.print("Score: " .. self.score, self.WINDOW_WIDTH - 150, 20)
        love.graphics.setColor(1, 1, 1)

        if self.gamePaused then
            love.graphics.setColor(self.menuOverlayColor)
            love.graphics.rectangle('fill', 0, 0, self.WINDOW_WIDTH, self.WINDOW_HEIGHT)
            love.graphics.setColor(1, 1, 1)
            if self.titleFont then love.graphics.setFont(self.titleFont) end
            love.graphics.printf("PAUSED", 0, self.WINDOW_HEIGHT/2 - 80, self.WINDOW_WIDTH, 'center')
            if self.menuFont then love.graphics.setFont(self.menuFont) end
            for i, optionText in ipairs(self.pauseMenuOptions) do
                if i == self.selectedMenuOption then love.graphics.setColor(1, 0.84, 0)
                else love.graphics.setColor(1, 1, 1) end
                love.graphics.printf(optionText, 0, self.WINDOW_HEIGHT/2 - 30 + (i * 40), self.WINDOW_WIDTH, 'center')
            end
            love.graphics.setColor(1,1,1)
            local instructionFont = self.menuFont
            if instructionFont then love.graphics.setFont(instructionFont) end
            love.graphics.printf("Use UP/DOWN arrows, ENTER to confirm", 0, self.WINDOW_HEIGHT - 70, self.WINDOW_WIDTH, 'center')
        end
    end
}
-- --- End FlappyBirdGame Object Definition ---


-- --- SpaceWarGame Object Definition ---
SpaceWarGame = {
    score = 0,
    t = 0,
    enemies_controller = { enemies = {} },
    backgroundImage = nil,
    game_icon = nil,
    game_music = nil,
    explosion = nil,
    player = nil, -- Player object will be defined within init
    dragging = { active = false, x = 0, y = 0 },
    SCREEN_WIDTH = 800, -- Will be updated in init
    ENEMY_SPAWN_PADDING = 75,
    gameState = "startScreen", -- Can be "startScreen", "enteringName", "playing", "gameOver", "gameWin", "leaderboardScreen"
    playerName = "",
    inputActive = false,
    leaderboard = {},
    LEADERBOARD_FILE = "leaderboard.json",
    isInitialized = false,
    errorMessage = nil, -- New: To store asset loading errors

    -- Load assets safely
    safeImage = function(self, path)
        local status, img = pcall(love.graphics.newImage, path)
        if not status then
            self.errorMessage = "Error loading image: " .. path .. " - " .. tostring(img)
            print(self.errorMessage) -- Also print to console for easier debugging
            return nil
        end
        return img
    end,

    -- Function to load ImageData safely for icons
    safeImageData = function(self, path)
        local status, imgData = pcall(love.image.newImageData, path)
        if not status then
            self.errorMessage = "Error loading image data: " .. path .. " - " .. tostring(imgData)
            print(self.errorMessage)
            return nil
        end
        return imgData
    end,

    safeSound = function(self, path)
        local status, snd = pcall(love.audio.newSource, path, "static")
        if not status then
            self.errorMessage = "Error loading sound: " .. path .. " - " .. tostring(snd)
            print(self.errorMessage)
            return nil
        end
        return snd
    end,

    init = function(self)
        if self.isInitialized then return end

        self.errorMessage = nil -- Reset error message on init

        love.window.setTitle("Space War") -- Set Space War specific title
        love.mouse.setVisible(true) -- Ensure mouse is visible for Space War

        -- Load assets using self:safeAsset()
        self.enemies_controller.image = self:safeImage('graphics/enemy.png')
        self.backgroundImage = self:safeImage('graphics/starfield.png')
        self.game_icon = self:safeImageData('graphics/game_icon.png')

        if self.game_icon then
            love.window.setIcon(self.game_icon)
        end

        self.game_music = self:safeSound('sound/game_music.mp3')
        self.explosion = self:safeSound('sound/explosion.mp3')

        -- Player setup
        self.player = {
            x = 300,
            y = 550,
            width = 110,
            height = 110,
            bullets = {},
            cooldown = 20,
            speed = 10,
            image = self:safeImage('graphics/player.png'),
            fire_sound = self:safeSound('sound/laser_gun.wav')
        }

        -- Player fire method (now part of self.player)
        self.player.fire = function(player_obj) -- 'player_obj' refers to self.player
            if player_obj.cooldown <= 0 then
                if player_obj.fire_sound then love.audio.play(player_obj.fire_sound) end
                player_obj.cooldown = 10
                local bullet = { x = player_obj.x + player_obj.width / 2 - 5, y = player_obj.y }
                table.insert(player_obj.bullets, bullet)
            end
        end

        self.SCREEN_WIDTH = love.graphics.getWidth()

        self:loadLeaderboard()

        -- Only play music if we are entering Space War, not just initializing it for the first time on global love.load
        -- The love.load() function will call init for all games, so we should control music playback in the global love.keypressed
        -- when a specific game is selected.
        -- self.game_music:setLooping(true)
        -- love.audio.play(self.game_music)

        local initialEnemyWidth = 40
        for i = 0, 10 do
            local spawnX = i * 75
            if spawnX >= self.ENEMY_SPAWN_PADDING and spawnX <= self.SCREEN_WIDTH - self.ENEMY_SPAWN_PADDING - initialEnemyWidth then
                self:spawnEnemy(spawnX, 0)
            end
        end
        self.isInitialized = true
    end,

    spawnEnemy = function(self, x, y)
        local e = {
            x = x,
            y = y,
            width = 40,
            height = 20,
            speed = 0.5,
            cooldown = 20
        }
        table.insert(self.enemies_controller.enemies, e)
    end,

    checkCollisions = function(self, enemies, bullets)
        for i = #enemies, 1, -1 do
            local e = enemies[i]
            for j = #bullets, 1, -1 do
                local b = bullets[j]
                if b.y <= e.y + e.height and b.y >= e.y and b.x >= e.x and b.x <= e.x + e.width then
                    if self.explosion then love.audio.play(self.explosion) end -- Corrected reference
                    table.remove(enemies, i)
                    table.remove(bullets, j)
                    self.score = self.score + 1

                    if self.score < 490 then
                        local minX = self.ENEMY_SPAWN_PADDING
                        local maxX = self.SCREEN_WIDTH - self.ENEMY_SPAWN_PADDING - e.width
                        local w = math.random(minX, maxX)
                        self:spawnEnemy(w, 0)
                    end

                    if self.score == 500 then
                        self.enemies_controller.image = self:safeImage('graphics/enemy_particle.png') -- Corrected reference
                        local enemyParticleWidth = self.enemies_controller.image and self.enemies_controller.image:getWidth() or 40 -- Corrected reference
                        for i = 1, 10 do
                            for j = 0, 4 do
                                local spawnX = i * 75
                                if spawnX >= self.ENEMY_SPAWN_PADDING and spawnX <= self.SCREEN_WIDTH - self.ENEMY_SPAWN_PADDING - enemyParticleWidth then
                                    self:spawnEnemy(spawnX, j * 35)
                                end
                            end
                        end
                    end
                    break
                end
            end
        end
    end,

    loadLeaderboard = function(self)
        if love.filesystem.isFile(self.LEADERBOARD_FILE) then
            local content = love.filesystem.read(self.LEADERBOARD_FILE)
            local status, data = pcall(json.decode, content)
            if status and type(data) == "table" then
                self.leaderboard = data
                table.sort(self.leaderboard, function(a, b) return a.score > b.score end)
            else
                self.leaderboard = {}
            end
        else
            self.leaderboard = {}
        end
    end,

    saveLeaderboard = function(self)
        local encoded = json.encode(self.leaderboard)
        love.filesystem.write(self.LEADERBOARD_FILE, encoded)
    end,

    addScoreToLeaderboard = function(self, name, finalScore)
        table.insert(self.leaderboard, {name = name, score = finalScore})
        table.sort(self.leaderboard, function(a, b) return a.score > b.score end)
        while #self.leaderboard > 10 do
            table.remove(self.leaderboard, #self.leaderboard)
        end
        self:saveLeaderboard()
    end,

    resetGame = function(self)
        self.score = 0
        self.player.x = 300
        self.player.y = 550
        self.player.bullets = {}
        self.enemies_controller.enemies = {}
        self.enemies_controller.image = self:safeImage('graphics/enemy.png')

        local initialEnemyWidth = 40
        for i = 0, 10 do
            local spawnX = i * 75
            if spawnX >= self.ENEMY_SPAWN_PADDING and spawnX <= self.SCREEN_WIDTH - self.ENEMY_SPAWN_PADDING - initialEnemyWidth then
                self:spawnEnemy(spawnX, 0)
            end
        end
        self.gameState = "playing"
        self.errorMessage = nil -- Clear error message on reset
    end,

    update = function(self, dt)
        if self.gameState == "playing" then
            self.player.cooldown = self.player.cooldown - 1

            if love.keyboard.isDown("right") and self.player.x < self.SCREEN_WIDTH - self.player.width then
                self.player.x = self.player.x + self.player.speed
            elseif love.keyboard.isDown("left") and self.player.x > 0 then
                self.player.x = self.player.x - self.player.speed
            end

            if self.dragging.active then
                local mx, my = love.mouse.getPosition()
                self.player.x = mx - self.dragging.x
                self.player.y = my - self.dragging.y
            end

            -- Player fire logic
            self.player:fire(self.player) -- Call the player's fire method

            for _, e in ipairs(self.enemies_controller.enemies) do
                e.y = e.y + e.speed
                if e.y >= love.graphics.getHeight() - self.player.height then
                    self.gameState = "gameOver"
                    self:addScoreToLeaderboard(self.playerName, self.score)
                end
            end

            for i = #self.player.bullets, 1, -1 do
                local b = self.player.bullets[i]
                b.y = b.y - 10
                if b.y < 0 then
                    table.remove(self.player.bullets, i)
                end
            end

            self:checkCollisions(self.enemies_controller.enemies, self.player.bullets)

            if #self.enemies_controller.enemies == 0 and self.gameState == "playing" then
                self.gameState = "gameWin"
                self:addScoreToLeaderboard(self.playerName, self.score)
            end
        end
    end,

    draw = function(self)
        if self.backgroundImage then
            love.graphics.draw(self.backgroundImage, 0, 0, 0, self.SCREEN_WIDTH / self.backgroundImage:getWidth(), love.graphics.getHeight() / self.backgroundImage:getHeight())
        else
            love.graphics.clear(0, 0, 0)
        end

        love.graphics.setColor(1, 1, 1)
        local titleFont = love.graphics.newFont(30)
        local buttonFont = love.graphics.newFont(22) -- Slightly smaller button font for more room
        local textFont = love.graphics.newFont(20)
        local scoreFont = love.graphics.newFont(14)

        -- Define common button properties
        local commonButtonWidth = 180 -- Increased button width significantly
        local commonButtonHeight = 50
        local commonButtonX = self.SCREEN_WIDTH / 2 - commonButtonWidth / 2

        if self.gameState == "startScreen" then
            love.graphics.setFont(titleFont)
            love.graphics.printf("Space War 1.0", 0, 50, self.SCREEN_WIDTH, "center")

            -- Play button
            local playButtonY = 200
            love.graphics.setFont(buttonFont)
            love.graphics.rectangle("fill", commonButtonX, playButtonY, commonButtonWidth, commonButtonHeight)
            love.graphics.setColor(0, 0, 0)
            local playText = "PLAY"
            local playTextWidth = buttonFont:getWidth(playText)
            love.graphics.print(playText, commonButtonX + (commonButtonWidth - playTextWidth) / 2, playButtonY + (commonButtonHeight - buttonFont:getHeight()) / 2)
            love.graphics.setColor(1, 1, 1)

            -- Leaderboard button
            local leaderboardButtonY = 280
            love.graphics.setFont(buttonFont)
            love.graphics.rectangle("fill", commonButtonX, leaderboardButtonY, commonButtonWidth, commonButtonHeight)
            love.graphics.setColor(0, 0, 0)
            local lbText = "LEADERBOARD"
            local lbTextWidth = buttonFont:getWidth(lbText)
            love.graphics.print(lbText, commonButtonX + (commonButtonWidth - lbTextWidth) / 2, leaderboardButtonY + (commonButtonHeight - buttonFont:getHeight()) / 2)
            love.graphics.setColor(1, 1, 1)

        elseif self.gameState == "leaderboardScreen" then
            love.graphics.setFont(titleFont)
            love.graphics.printf("Leaderboard", 0, 50, self.SCREEN_WIDTH, "center")

            love.graphics.setFont(textFont)
            local leaderboardY = 120
            if #self.leaderboard == 0 then
                love.graphics.printf("No scores yet!", 0, leaderboardY, self.SCREEN_WIDTH, "center")
            else
                for i, entry in ipairs(self.leaderboard) do
                    local entryText = string.format("%d. %s: %d", i, entry.name, entry.score)
                    love.graphics.printf(entryText, 0, leaderboardY + (i-1) * 30, self.SCREEN_WIDTH, "center")
                end
            end

            -- Back button
            local backButtonY = love.graphics.getHeight() - 80
            love.graphics.setFont(buttonFont)
            love.graphics.rectangle("fill", commonButtonX, backButtonY, commonButtonWidth, commonButtonHeight)
            love.graphics.setColor(0, 0, 0)
            local backText = "BACK"
            local backTextWidth = buttonFont:getWidth(backText)
            love.graphics.print(backText, commonButtonX + (commonButtonWidth - backTextWidth) / 2, backButtonY + (commonButtonHeight - buttonFont:getHeight()) / 2)
            love.graphics.setColor(1, 1, 1)

        elseif self.gameState == "enteringName" then
            love.graphics.setFont(titleFont)
            love.graphics.printf("Enter Your Name:", 0, 200, self.SCREEN_WIDTH, "center")
            love.graphics.setFont(textFont)

            local inputX = self.SCREEN_WIDTH / 2 - 150
            local inputY = 250
            local inputWidth = 300
            local inputHeight = 40
            love.graphics.rectangle("line", inputX, inputY, inputWidth, inputHeight)
            love.graphics.print(self.playerName .. (self.inputActive and "_" or ""), inputX + 10, inputY + 10)

            love.graphics.setFont(textFont)
            love.graphics.printf("Press ENTER to continue", 0, 320, self.SCREEN_WIDTH, "center")

        elseif self.gameState == "playing" then
            love.graphics.setFont(scoreFont)
            love.graphics.print("Score: " .. self.score, 360, 580)
            love.graphics.print("Player: " .. self.playerName, 10, 580)

            if self.player.image then -- Corrected reference
                love.graphics.draw(self.player.image, self.player.x, self.player.y)
            else
                love.graphics.rectangle("fill", self.player.x, self.player.y, self.player.width, self.player.height)
            end

            for _, b in ipairs(self.player.bullets) do -- Corrected reference
                love.graphics.rectangle("fill", b.x, b.y, 10, 10)
            end

            for _, e in ipairs(self.enemies_controller.enemies) do -- Corrected reference
                if self.enemies_controller.image then -- Corrected reference
                    love.graphics.draw(self.enemies_controller.image, e.x, e.y)
                else
                    love.graphics.rectangle("line", e.x, e.y, e.width, e.height)
                end
            end
        elseif self.gameState == "gameOver" or self.gameState == "gameWin" then
            love.graphics.setFont(titleFont)
            if self.gameState == "gameOver" then
                love.graphics.printf("Game Over!", 0, 200, self.SCREEN_WIDTH, "center")
            else
                love.graphics.printf("You Won!", 0, 200, self.SCREEN_WIDTH, "center")
            end
            love.graphics.setFont(textFont)
            love.graphics.printf("Your Score: " .. self.score, 0, 240, self.SCREEN_WIDTH, "center")
            love.graphics.printf("Player: " .. self.playerName, 0, 270, self.SCREEN_WIDTH, "center")

            -- Restart button
            local restartButtonY = 320
            love.graphics.setFont(buttonFont)
            love.graphics.rectangle("fill", commonButtonX, restartButtonY, commonButtonWidth, commonButtonHeight)
            love.graphics.setColor(0, 0, 0)
            local restartText = "RESTART"
            local restartTextWidth = buttonFont:getWidth(restartText)
            love.graphics.print(restartText, commonButtonX + (commonButtonWidth - restartTextWidth) / 2, restartButtonY + (commonButtonHeight - buttonFont:getHeight()) / 2)
            love.graphics.setColor(1, 1, 1)

            -- Home button (New)
            local homeButtonY = 390 -- Position below Restart button
            love.graphics.setFont(buttonFont)
            love.graphics.rectangle("fill", commonButtonX, homeButtonY, commonButtonWidth, commonButtonHeight)
            love.graphics.setColor(0, 0, 0)
            local homeText = "MAIN MENU"
            local homeTextWidth = buttonFont:getWidth(homeText)
            love.graphics.print(homeText, commonButtonX + (commonButtonWidth - homeTextWidth) / 2, homeButtonY + (commonButtonHeight - buttonFont:getHeight()) / 2)
            love.graphics.setColor(1, 1, 1)
        end

        -- Display error message if any asset failed to load
        if self.errorMessage then
            love.graphics.setColor(1, 0, 0) -- Red color for error
            love.graphics.setFont(textFont)
            love.graphics.printf("Asset Load Error: " .. self.errorMessage, 0, love.graphics.getHeight() - 50, love.graphics.getWidth(), "center")
            love.graphics.setColor(1, 1, 1) -- Reset color
        end
    end,

    mousepressed = function(self, x, y, button)
        if button == 1 then
            local commonButtonWidth = 180
            local commonButtonHeight = 50
            local commonButtonX = self.SCREEN_WIDTH / 2 - commonButtonWidth / 2

            if self.gameState == "startScreen" then
                -- Play button click
                local playButtonY = 200
                if x >= commonButtonX and x <= commonButtonX + commonButtonWidth and y >= playButtonY and y <= playButtonY + commonButtonHeight then
                    self.gameState = "enteringName"
                    self.playerName = ""
                    self.inputActive = true
                end

                -- Leaderboard button click
                local leaderboardButtonY = 280
                if x >= commonButtonX and x <= commonButtonX + commonButtonWidth and y >= leaderboardButtonY and y <= leaderboardButtonY + commonButtonHeight then
                    self.gameState = "leaderboardScreen"
                    self:loadLeaderboard()
                end

            elseif self.gameState == "leaderboardScreen" then
                -- Back button click
                local backButtonY = love.graphics.getHeight() - 80
                if x >= commonButtonX and x <= commonButtonX + commonButtonWidth and y >= backButtonY and y <= backButtonY + commonButtonHeight then
                    self.gameState = "startScreen"
                end

            elseif self.gameState == "gameOver" or self.gameState == "gameWin" then
                -- Restart button click
                local restartButtonY = 320
                if x >= commonButtonX and x <= commonButtonX + commonButtonWidth and y >= restartButtonY and y <= restartButtonY + commonButtonHeight then
                    self.gameState = "startScreen"
                    self:loadLeaderboard()
                end
                -- Home button click
                local homeButtonY = 390
                if x >= commonButtonX and x <= commonButtonX + commonButtonWidth and y >= homeButtonY and y <= homeButtonY + commonButtonHeight then
                    globalGameMode = "mainMenu" -- Return to the main game selection menu
                    if self.game_music and self.game_music:isPlaying() then self.game_music:stop() end -- Stop Space War music
                    love.window.setTitle("Game Box") -- Reset title when returning to main menu
                    self:loadLeaderboard() -- Reload leaderboard in case new scores were added
                end
            elseif self.gameState == "playing" then
                if x > self.player.x and x < self.player.x + self.player.width and y > self.player.y and y < self.player.y + self.player.height then
                    self.dragging.active = true
                    self.dragging.x = x - self.player.x
                    self.dragging.y = y - self.player.y
                end
            end
        end
    end,

    mousereleased = function(self, x, y, button)
        if button == 1 then
            self.dragging.active = false
        end
    end,

    textinput = function(self, text)
        if self.gameState == "enteringName" and self.inputActive then
            self.playerName = self.playerName .. text
        end
    end,

    keypressed = function(self, key)
        if self.gameState == "enteringName" and self.inputActive then
            if key == "backspace" then
                self.playerName = string.sub(self.playerName, 1, #self.playerName - 1)
            elseif key == "return" then
                if #self.playerName > 0 then
                    self.inputActive = false
                    self:resetGame()
                end
            end
        end
    end
}
-- --- End SpaceWarGame Object Definition ---


-- --- Global Game State Variable ---
globalGameMode = "mainMenu" -- Can be "mainMenu", "tetris", "flappyBird", "spaceWar"
local defaultFont = nil -- For global default font

-- --- Main Menu Variables ---
local mainMenu_menuFont
local mainMenu_optionFont
local mainMenu_games -- List of games for the menu
local mainMenu_selectedOption = 1
local mainMenu_errorMessage = nil

-- --- Tetris Game Variables ---
local tetris_GRID_WIDTH, tetris_GRID_HEIGHT, tetris_CELL_SIZE, tetris_GRID_OFFSET_X, tetris_GRID_OFFSET_Y
local tetris_COLORS, tetris_SHAPES
local tetris_grid
local tetris_current_piece
local tetris_score
local tetris_level
local tetris_lines_cleared
local tetris_game_over
local tetris_pause
local tetris_drop_time
local tetris_drop_speed

-- --- Sound Variables ---
local tetris_gameMusic
local tetris_bricktouchSource
local tetris_gameOverSound

-- --- LÖVE2D Callback Functions ---

function love.load()
    love.window.setMode(800, 600, {resizable = false, vsync = true})
    love.window.setTitle("Game Box") -- Global title for the game box
    love.mouse.setGrabbed(false)

    math.randomseed(os.time())

    defaultFont = love.graphics.newFont(12) -- Create a very basic default font

    mainMenu_menuFont = love.graphics.newFont(32)
    mainMenu_optionFont = love.graphics.newFont(24)
    mainMenu_games = {
        {name = "Tetris", type = "tetris"},
        {name = "Flappy Bird", type = "flappyBird"},
        {name = "Space War", type = "spaceWar"}, -- Added Space War to the menu
    }
    mainMenu_selectedOption = 1

    local musicSuccess, musicError = pcall(function() tetris_gameMusic = love.audio.newSource("tetris_sounds/gamemusic.mp3", "stream") end)
    if musicSuccess and tetris_gameMusic then tetris_gameMusic:setLooping(true) else print("Error loading Tetris music: " .. tostring(musicError)) end

    local brickSuccess, brickError = pcall(function() tetris_bricktouchSource = love.audio.newSource("tetris_sounds/bricktouch.mp3", "static") end)
    if not brickSuccess then print("Error loading Tetris bricktouch: " .. tostring(brickError)) end

    local goSuccess, goError = pcall(function() tetris_gameOverSound = love.audio.newSource("tetris_sounds/gameover.mp3", "static") end)
    if not goSuccess then print("Error loading Tetris gameover: " .. tostring(goError)) end

    resetTetrisGame()
    FlappyBirdGame:init()
    SpaceWarGame:init() -- Initialize Space War

    -- No music should be playing by default on load, the individual game selection will start it.
    if tetris_gameMusic and tetris_gameMusic:isPlaying() then tetris_gameMusic:stop() end
    if SpaceWarGame.game_music and SpaceWarGame.game_music:isPlaying() then SpaceWarGame.game_music:stop() end
end

function love.update(dt)
    if globalGameMode == "tetris" then
        if tetris_game_over or tetris_pause then return end
        tetris_drop_time = tetris_drop_time + dt
        if tetris_drop_time > tetris_drop_speed then
            tetris_drop_time = 0
            tetris_movePiece(0, 1)
        end
    elseif globalGameMode == "flappyBird" then
        FlappyBirdGame:update(dt)
    elseif globalGameMode == "spaceWar" then
        SpaceWarGame:update(dt)
    elseif globalGameMode == "mainMenu" then
        -- No update logic needed
    end
end

function love.draw()
    love.graphics.push("all") -- Save all graphics states at the beginning of the frame

    -- Establish a clean baseline state for the entire frame
    love.graphics.origin() -- Reset coordinate origin
    love.graphics.setColor(1, 1, 1, 1) -- Default to white, fully opaque
    love.graphics.setBackgroundColor(0, 0, 0, 1) -- Default background to transparent black
    love.graphics.setFont(defaultFont or love.graphics.getFont()) -- Set a global default font
    love.graphics.setLineWidth(1) -- Default line width
    love.graphics.setBlendMode("alpha", "alphamultiply") -- Default blend mode
    love.graphics.setScissor() -- Clear any scissor rectangle

    if globalGameMode == "tetris" then
        drawTetrisGame()
    elseif globalGameMode == "flappyBird" then
        FlappyBirdGame:draw()
    elseif globalGameMode == "spaceWar" then
        SpaceWarGame:draw()
    elseif globalGameMode == "mainMenu" then
        drawMainMenu()
    end

    love.graphics.pop() -- Restore all graphics states at the end of the frame
end

function love.keypressed(key)
    if globalGameMode == "mainMenu" then
        if key == "up" then
            mainMenu_selectedOption = math.max(1, mainMenu_selectedOption - 1)
            mainMenu_errorMessage = nil
        elseif key == "down" then
            mainMenu_selectedOption = math.min(#mainMenu_games, mainMenu_selectedOption + 1)
            mainMenu_errorMessage = nil
        elseif key == "return" then
            local selectedGameType = mainMenu_games[mainMenu_selectedOption].type

            -- Stop any currently playing game music before switching
            if tetris_gameMusic and tetris_gameMusic:isPlaying() then tetris_gameMusic:stop() end
            if SpaceWarGame.game_music and SpaceWarGame.game_music:isPlaying() then SpaceWarGame.game_music:stop() end

            if selectedGameType == "tetris" then
                globalGameMode = "tetris"
                resetTetrisGame()
                if tetris_gameMusic and not tetris_gameMusic:isPlaying() then tetris_gameMusic:play() end
                love.window.setTitle("Tetris") -- Set Tetris specific title
            elseif selectedGameType == "flappyBird" then
                globalGameMode = "flappyBird"
                FlappyBirdGame.currentGameState = "menu"
                love.window.setTitle("Flappy Bird") -- Set Flappy Bird specific title
            elseif selectedGameType == "spaceWar" then -- Handle Space War selection
                globalGameMode = "spaceWar"
                SpaceWarGame.gameState = "startScreen" -- Ensure Space War starts at its main screen
                SpaceWarGame:init() -- Re-initialize Space War to ensure fresh start and title/icon
                if SpaceWarGame.game_music and not SpaceWarGame.game_music:isPlaying() then SpaceWarGame.game_music:play() end -- Play Space War music
            end
        elseif key == "escape" then
            -- Stop any currently playing game music before quitting
            if tetris_gameMusic and tetris_gameMusic:isPlaying() then tetris_gameMusic:stop() end
            if SpaceWarGame.game_music and SpaceWarGame.game_music:isPlaying() then SpaceWarGame.game_music:stop() end
            love.event.quit()
        end
    elseif globalGameMode == "tetris" then
        if key == "escape" then
            globalGameMode = "mainMenu"
            if tetris_gameMusic then tetris_gameMusic:stop() end -- Stop Tetris music
            love.window.setTitle("Game Box") -- Reset title when returning to main menu
            return
        end

        if tetris_game_over then
            if key == "r" then
                resetTetrisGame()
                if tetris_gameMusic and not tetris_gameMusic:isPlaying() then tetris_gameMusic:play() end
            end
            return
        end

        if key == "p" then
            tetris_pause = not tetris_pause
            if tetris_gameMusic then
                if tetris_pause then tetris_gameMusic:pause() else tetris_gameMusic:play() end
            end
            return
        end

        if tetris_pause then return end

        if key == "left" then tetris_movePiece(-1, 0)
        elseif key == "right" then tetris_movePiece(1, 0)
        elseif key == "down" then tetris_movePiece(0, 1)
        elseif key == "up" then tetris_rotatePiece()
        elseif key == "space" then
            while tetris_movePiece(0, 1) do end
        end

    elseif globalGameMode == "flappyBird" then
        FlappyBirdGame:keypressed(key)
    elseif globalGameMode == "spaceWar" then
        SpaceWarGame:keypressed(key)
    end
end

function love.mousepressed(x, y, button)
    if globalGameMode == "flappyBird" then
        -- FlappyBirdGame doesn't have a specific mousepressed handler, its logic is in keypressed for jump.
        -- If you need mouse interaction for Flappy Bird, add it to FlappyBirdGame.
    elseif globalGameMode == "spaceWar" then
        SpaceWarGame:mousepressed(x, y, button)
    end
end

function love.mousereleased(x, y, button)
    if globalGameMode == "spaceWar" then
        SpaceWarGame:mousereleased(x, y, button)
    end
end

function love.textinput(text)
    if globalGameMode == "spaceWar" then
        SpaceWarGame:textinput(text)
    end
end


-- --- Main Menu Draw Function ---
function drawMainMenu()
    love.graphics.push()
    love.graphics.setColor(1,1,1,1)
    love.graphics.setFont(mainMenu_menuFont or love.graphics.getFont())

    love.graphics.setColor(0.1, 0.1, 0.2)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())

    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Game Box", 0, 100, love.graphics.getWidth(), "center")

    if mainMenu_optionFont then love.graphics.setFont(mainMenu_optionFont) end
    for i, game in ipairs(mainMenu_games) do
        if i == mainMenu_selectedOption then love.graphics.setColor(1, 0.5, 0)
        else love.graphics.setColor(1, 1, 1) end
        love.graphics.printf(game.name, 0, 200 + i * 50, love.graphics.getWidth(), "center")
    end

    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.printf("Use arrow keys to select, Enter to play", 0, love.graphics.getHeight() - 100, love.graphics.getWidth(), "center")
    love.graphics.printf("Press Escape to exit", 0, love.graphics.getHeight() - 60, love.graphics.getWidth(), "center")

    if mainMenu_errorMessage then
        love.graphics.setColor(1, 0, 0)
        love.graphics.printf(mainMenu_errorMessage, 0, love.graphics.getHeight() - 150, love.graphics.getWidth(), "center")
    end
    love.graphics.pop()
end


-- --- Tetris Game Logic Functions (prefixed with tetris_) ---


-- --- Tetris Game Logic Functions (prefixed with tetris_) ---
function resetTetrisGame()
    tetris_GRID_WIDTH = 10; tetris_GRID_HEIGHT = 17; tetris_CELL_SIZE = 30
    tetris_GRID_OFFSET_X = (love.graphics.getWidth() - (tetris_GRID_WIDTH * tetris_CELL_SIZE)) / 3
    tetris_GRID_OFFSET_Y = 50

    tetris_COLORS = {
        {0,0,0}, {0.8,0.1,0.1}, {0.1,0.8,0.1}, {0.1,0.1,0.8}, {0.8,0.8,0.1},
        {0.8,0.1,0.8}, {0.1,0.8,0.8}, {0.5,0.5,0.5}
    }
    tetris_SHAPES = {
        {{0,0,0,0},{1,1,1,1},{0,0,0,0},{0,0,0,0}}, {{2,0,0},{2,2,2},{0,0,0}},
        {{0,0,3},{3,3,3},{0,0,0}}, {{4,4},{4,4}}, {{0,5,5},{5,5,0},{0,0,0}},
        {{0,6,0},{6,6,6},{0,0,0}}, {{7,7,0},{0,7,7},{0,0,0}}
    }

    tetris_grid = {}
    for y = 1, tetris_GRID_HEIGHT do
        tetris_grid[y] = {}
        for x = 1, tetris_GRID_WIDTH do tetris_grid[y][x] = 0 end
    end

    tetris_score = 0; tetris_level = 1; tetris_lines_cleared = 0
    tetris_game_over = false; tetris_pause = false
    tetris_newPiece()
    tetris_drop_time = 0; tetris_drop_speed = 0.5
    love.keyboard.setKeyRepeat(true)
end

function tetris_newPiece()
    local shape_index = math.random(1, #tetris_SHAPES)
    local shape = tetris_SHAPES[shape_index]
    local shape_height = #shape; local lowest_block = 1
    for y = 1, shape_height do
        for x = 1, #shape[y] do
            if shape[y][x] ~= 0 and y > lowest_block then lowest_block = y end
        end
    end
    local spawn_y = 1 - lowest_block +1

    tetris_current_piece = {
        shape = shape,
        x = math.floor(tetris_GRID_WIDTH / 2) - math.floor(#shape[1] / 2),
        y = spawn_y, color = shape_index
    }
    if tetris_checkCollision(tetris_current_piece.x, tetris_current_piece.y, tetris_current_piece.shape) then
        tetris_game_over = true
        if tetris_gameOverSound then tetris_gameOverSound:play() end
        if tetris_gameMusic then tetris_gameMusic:stop() end
    end
end

function tetris_rotatePiece()
    if not tetris_current_piece then return end
    local rotated = {}; local size = #tetris_current_piece.shape
    for y = 1, size do
        rotated[y] = {}
        for x = 1, size do rotated[y][x] = tetris_current_piece.shape[size - x + 1][y] end
    end
    if not tetris_checkCollision(tetris_current_piece.x, tetris_current_piece.y, rotated) then
        tetris_current_piece.shape = rotated
    end
end

function tetris_checkCollision(x, y, shape)
    local size = #shape
    for py = 1, size do
        for px = 1, size do
            if shape[py][px] ~= 0 then
                local nx = x + px - 1; local ny = y + py - 1
                if nx < 1 or nx > tetris_GRID_WIDTH or ny > tetris_GRID_HEIGHT or (ny >= 1 and tetris_grid[ny] and tetris_grid[ny][nx] ~= 0) then
                    return true
                end
            end
        end
    end
    return false
end

function tetris_mergePiece()
    if not tetris_current_piece then return end
    local size = #tetris_current_piece.shape
    for py = 1, size do
        for px = 1, size do
            if tetris_current_piece.shape[py][px] ~= 0 then
                local nx = tetris_current_piece.x + px - 1
                local ny = tetris_current_piece.y + py - 1
                if ny >= 1 and ny <= tetris_GRID_HEIGHT and nx >=1 and nx <= tetris_GRID_WIDTH then
                    if tetris_grid[ny] then tetris_grid[ny][nx] = tetris_current_piece.color end
                end
            end
        end
    end
end

function tetris_clearLines()
    local lines_to_clear = {}
    for y = 1, tetris_GRID_HEIGHT do
        local complete = true
        for x = 1, tetris_GRID_WIDTH do
            if tetris_grid[y][x] == 0 then complete = false; break end
        end
        if complete then table.insert(lines_to_clear, y) end
    end

    if #lines_to_clear > 0 then
        for _, y_clear in ipairs(lines_to_clear) do
            table.remove(tetris_grid, y_clear)
            local new_line = {}
            for x = 1, tetris_GRID_WIDTH do new_line[x] = 0 end
            table.insert(tetris_grid, 1, new_line)

            tetris_lines_cleared = tetris_lines_cleared + 1
            tetris_score = tetris_score + 100 * tetris_level
            if tetris_lines_cleared % 10 == 0 then
                tetris_level = tetris_level + 1
                tetris_drop_speed = math.max(0.1, tetris_drop_speed * 0.9)
            end
        end
    end
end

function tetris_movePiece(dx, dy)
    if not tetris_current_piece then return false end
    if not tetris_checkCollision(tetris_current_piece.x + dx, tetris_current_piece.y + dy, tetris_current_piece.shape) then
        tetris_current_piece.x = tetris_current_piece.x + dx
        tetris_current_piece.y = tetris_current_piece.y + dy
        return true
    else
        if dy > 0 then
            tetris_mergePiece()
            if tetris_bricktouchSource then local cloned_sound = tetris_bricktouchSource:clone(); cloned_sound:play() end
            tetris_score = tetris_score + 5 * tetris_level
            tetris_clearLines()
            tetris_newPiece()
        end
        return false
    end
end

function drawTetrisGame()
    love.graphics.push()
    love.graphics.setColor(1,1,1,1)
    love.graphics.setFont(mainMenu_optionFont or love.graphics.getFont())

    love.graphics.setColor(0, 0,0,1)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())

    love.graphics.setColor(0.1, 0.1, 0.1)
    love.graphics.rectangle("fill", tetris_GRID_OFFSET_X - 2, tetris_GRID_OFFSET_Y - 2,
                            tetris_GRID_WIDTH * tetris_CELL_SIZE + 4, tetris_GRID_HEIGHT * tetris_CELL_SIZE + 4)

    for y = 1, tetris_GRID_HEIGHT do
        for x = 1, tetris_GRID_WIDTH do
            if tetris_grid[y] and tetris_grid[y][x] ~= 0 then
                local color = tetris_COLORS[tetris_grid[y][x]]
                love.graphics.setColor(color)
                love.graphics.rectangle("fill", tetris_GRID_OFFSET_X + (x-1) * tetris_CELL_SIZE,
                                        tetris_GRID_OFFSET_Y + (y-1) * tetris_CELL_SIZE,
                                        tetris_CELL_SIZE - 1, tetris_CELL_SIZE - 1)
            end
        end
    end

    if tetris_current_piece then
        local size = #tetris_current_piece.shape
        for py = 1, size do
            for px = 1, size do
                if tetris_current_piece.shape[py][px] ~= 0 then
                    local nx = tetris_current_piece.x + px - 1
                    local ny = tetris_current_piece.y + py - 1
                    if ny >= 1 then
                        local color = tetris_COLORS[tetris_current_piece.color]
                        love.graphics.setColor(color)
                        love.graphics.rectangle("fill", tetris_GRID_OFFSET_X + (nx-1) * tetris_CELL_SIZE,
                                                tetris_GRID_OFFSET_Y + (ny-1) * tetris_CELL_SIZE,
                                                tetris_CELL_SIZE - 1, tetris_CELL_SIZE - 1)
                    end
                end
            end
        end
    end

    love.graphics.setColor(1, 1, 1)
    local infoX = tetris_GRID_OFFSET_X + tetris_GRID_WIDTH * tetris_CELL_SIZE + 20
    love.graphics.print("Score: " .. tetris_score, infoX, 50)
    love.graphics.print("Level: " .. tetris_level, infoX, 80)
    love.graphics.print("Lines: " .. tetris_lines_cleared, infoX, 110)

    local controlsYStart = 150; local lineSpacing = 25
    love.graphics.print("Controls:", infoX, controlsYStart)
    love.graphics.print("Left/Right: Move", infoX, controlsYStart + lineSpacing * 1)
    love.graphics.print("Up: Rotate", infoX, controlsYStart + lineSpacing * 2)
    love.graphics.print("Down: Soft Drop", infoX, controlsYStart + lineSpacing * 3)
    love.graphics.print("Space: Hard Drop", infoX, controlsYStart + lineSpacing * 4)
    love.graphics.print("P: Pause", infoX, controlsYStart + lineSpacing * 5)
    love.graphics.print("ESC: Menu", infoX, controlsYStart + lineSpacing * 6)

    if tetris_game_over then
        love.graphics.setColor(1, 0, 0, 0.7)
        love.graphics.rectangle("fill", 0, love.graphics.getHeight()/2 - 50, love.graphics.getWidth(), 100)
        love.graphics.setColor(1, 1, 1)
        if mainMenu_menuFont then love.graphics.setFont(mainMenu_menuFont) end
        love.graphics.printf("GAME OVER", 0, love.graphics.getHeight()/2 - 30, love.graphics.getWidth(), "center")
        if mainMenu_optionFont then love.graphics.setFont(mainMenu_optionFont) end
        love.graphics.printf("Press R to restart or ESC for menu", 0, love.graphics.getHeight()/2 + 10, love.graphics.getWidth(), "center")
    end

    if tetris_pause then
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle("fill", 0, love.graphics.getHeight()/2 - 50, love.graphics.getWidth(), 100)
        love.graphics.setColor(1, 1, 1)
        if mainMenu_menuFont then love.graphics.setFont(mainMenu_menuFont) end
        love.graphics.printf("PAUSED", 0, love.graphics.getHeight()/2 - 30, love.graphics.getWidth(), "center")
        if mainMenu_optionFont then love.graphics.setFont(mainMenu_optionFont) end
        love.graphics.printf("Press P to continue or ESC for menu", 0, love.graphics.getHeight()/2 + 10, love.graphics.getWidth(), "center")
    end
    love.graphics.pop()
end