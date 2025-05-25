-- flappy/game.lua
local FlappyGame = {}

-- Original Flappy Bird variables, now local to this module
local internalFbGameState = "menu" -- Renamed from gameState to avoid confusion with GameBox's overallGameState
local fbGamePaused = false         -- Renamed

-- Fonts (will be loaded in FlappyGame.load)
local fbFont, fbMenuFont, fbTitleFont = nil, nil, nil

-- Score and game progression
local fbScore = 0
local fbUpcomingPipe = 1

-- Images and Sounds (will be loaded in FlappyGame.load)
local fbBirdImage = nil -- This was 'birdImage' in original, seems unused directly, player gets image path
local fbBackgroundImage = nil
local fbPipeDownImage, fbPipeUpImage = nil, nil
local fbScoreSound = nil

-- Character selection
local fbCharacterOptions = {
    {name = "Bird 1", image_path = 'Assets/birddrawing1.png', image_obj = nil}, -- Store path and loaded image
    {name = "Bird 2", image_path = 'Assets/birddrawing.png', image_obj = nil},
}
local fbSelectedCharacterIndex = 1
-- local fbCharacterImages = {} -- Replaced by storing image_obj in fbCharacterOptions

-- Window dimensions (obtained from GameBox)
local FB_WINDOW_WIDTH, FB_WINDOW_HEIGHT

-- Colors
local fbSkyBlue = {.43, .77, .80}
local fbPurple = {0.58, 0.44, 0.86}
local fbDarkPurple = {0.37, 0.31, 0.63}
local fbMenuOverlayColor = {0.2, 0.2, 0.2, 0.8} -- Semi-transparent dark background

-- Pause Menu
local fbPauseMenuOptions = {"Resume", "Quit to Game Box"}
local fbSelectedPauseOption = 1

-- Callback to return to GameBox main menu
local returnToGameBoxMenuCallback = nil

-- Game Entities (player, pipes, ground)
local fbPlayer = nil
local fbPipe1, fbPipe2, fbPipe3, fbPipe4 = nil, nil, nil, nil
local fbDirt, fbGrass = nil, nil

-- Lua Classes (will be required in FlappyGame.load)
local FbClass, FbBird, FbGround, FbDownwardPipes, FbUpwardPipes = nil,nil,nil,nil,nil

-- Forward declaration for functions used before definition
local fbStartGame
local fbDrawMainMenu, fbDrawCharacterSelect, fbDrawGameScreen, fbDrawGameOverScreen
local fbCreateFirstPipes, fbCreateSecondPipes

-- Helper for asset paths relative to "flappy/" directory
local function asset(relativePath)
    return "flappy/" .. relativePath
end

function FlappyGame.load(mainMenuCb)
    print("FlappyGame.load called")
    returnToGameBoxMenuCallback = mainMenuCb

    FB_WINDOW_WIDTH, FB_WINDOW_HEIGHT = love.graphics.getDimensions()

    -- Store original package path and temporarily modify for local requires
    local flappyModuleDir = "flappy/"
    local original_package_path = package.path
    package.path = package.path .. ";" ..
                   flappyModuleDir .. "?.lua;" ..
                   flappyModuleDir .. "?/init.lua;" ..
                   flappyModuleDir .. "Lua Files/?.lua;" ..
                   flappyModuleDir .. "Lua Files/?/init.lua"


    -- Load Lua classes
    FbClass = require('Class') -- Lua Files/Class.lua
    FbBird = require('Bird')
    FbGround = require('Ground')
    FbDownwardPipes = require('downwardPipes')
    FbUpwardPipes = require('upwardPipes')

    -- Restore original package path
    package.path = original_package_path
    print("Flappy Bird classes loaded.")

    -- Load fonts
    fbFont = love.graphics.newFont(asset('Fonts/DIMIS___.TTF'), 30)
    fbMenuFont = love.graphics.newFont(asset('Fonts/DIMIS___.TTF'), 25)
    fbTitleFont = love.graphics.newFont(asset('Fonts/DIMIS___.TTF'), 30)
    print("Flappy Bird fonts loaded.")

    -- Load background image
    fbBackgroundImage = love.graphics.newImage(asset('Assets/gamebackground.jpg'))
    print("Flappy Bird background loaded.")

    -- Load character images for selection screen
    for i, charOption in ipairs(fbCharacterOptions) do
        charOption.image_obj = love.graphics.newImage(asset(charOption.image_path))
    end
    print("Flappy Bird character images loaded.")
    
    -- Load pipe images
    fbPipeDownImage = love.graphics.newImage(asset('Assets/Pipe-down.png'))
    fbPipeUpImage = love.graphics.newImage(asset('Assets/Pipe-up.png'))
    print("Flappy Bird pipe images loaded.")

    -- Load sound effects
    fbScoreSound = love.audio.newSource(asset('Sound effects/score.wav'), 'static')
    print("Flappy Bird sounds loaded.")

    -- Set initial Flappy Bird game state
    internalFbGameState = "menu"
    fbGamePaused = false
    fbSelectedCharacterIndex = 1
    fbScore = 0
    fbUpcomingPipe = 1
    
    -- Do not call fbStartGame here; it's called after character selection.
    print("FlappyGame.load finished successfully.")
end

fbStartGame = function(selectedCharacterImagePath)
    print("fbStartGame called with image: " .. selectedCharacterImagePath)
    fbScore = 0
    fbUpcomingPipe = 1
    internalFbGameState = "game"
    fbGamePaused = false

    -- Create new player instance
    -- The FbBird class constructor expects a LÖVE image object.
    local birdImgObj = love.graphics.newImage(asset(selectedCharacterImagePath))
    fbPlayer = FbBird(birdImgObj, FB_WINDOW_WIDTH, FB_WINDOW_HEIGHT) -- Pass dimensions if Bird class needs them

    -- Reset ground
    -- The Ground class constructor needs to be checked for parameters.
    -- Assuming Ground(x, y, width, height, color)
    fbDirt = FbGround(0, FB_WINDOW_HEIGHT - 120, FB_WINDOW_WIDTH, 60, fbDarkPurple) -- Adjusted Y based on typical Flappy Bird
    fbGrass = FbGround(0, FB_WINDOW_HEIGHT - 120 - 15, FB_WINDOW_WIDTH, 15, fbPurple) -- Adjusted Y

    -- Reset pipes
    -- Pipe classes need access to their images, pass them if necessary or ensure they load them.
    -- Assuming pipe classes handle their own image loading using fbPipeDownImage, fbPipeUpImage
    -- Or, if they expect image objects: DownwardPipes(image, x, y), UpwardPipes(image, x, y)
    -- For now, assuming original structure where pipe classes might use global image vars (now module-local fbPipeDownImage)
    
    fbCreateFirstPipes()
    fbCreateSecondPipes()
    print("Flappy Bird game started.")
end

fbCreateFirstPipes = function()
    local pipeGapYMin = -120 -- Top of the gap for the downward pipe
    local pipeGapYMax = -5   -- Top of the gap
    local pipeGapY = love.math.random(pipeGapYMin, pipeGapYMax)
    local pipeOpeningHeight = 100 -- Example, adjust as needed

    -- Assuming DownwardPipes(x, y_top_of_pipe) and UpwardPipes(x, y_bottom_of_pipe_opening)
    -- And that pipe classes use fbPipeDownImage, fbPipeUpImage internally.
    fbPipe1 = FbDownwardPipes(FB_WINDOW_WIDTH, pipeGapY)
    fbPipe2 = FbUpwardPipes(FB_WINDOW_WIDTH, pipeGapY + fbPipeDownImage:getHeight() + pipeOpeningHeight)
end

fbCreateSecondPipes = function()
    local pipeGapYMin = -120
    local pipeGapYMax = -5
    local pipeGapY = love.math.random(pipeGapYMin, pipeGapYMax)
    local pipeOpeningHeight = 100

    -- Start second set of pipes further off screen
    fbPipe3 = FbDownwardPipes(FB_WINDOW_WIDTH + FB_WINDOW_WIDTH/2 + 50, pipeGapY) -- Adjust starting X
    fbPipe4 = FbUpwardPipes(FB_WINDOW_WIDTH + FB_WINDOW_WIDTH/2 + 50, pipeGapY + fbPipeDownImage:getHeight() + pipeOpeningHeight)
end


function FlappyGame.keypressed(key)
    if internalFbGameState == "gameOver" then
        if key == 'return' then
            fbStartGame(fbCharacterOptions[fbSelectedCharacterIndex].image_path)
        elseif key == 'escape' then
            if returnToGameBoxMenuCallback then returnToGameBoxMenuCallback() end
        end
    elseif internalFbGameState == "characterSelect" then
        if key == 'left' then
            fbSelectedCharacterIndex = fbSelectedCharacterIndex - 1
            if fbSelectedCharacterIndex < 1 then fbSelectedCharacterIndex = #fbCharacterOptions end
        elseif key == 'right' then
            fbSelectedCharacterIndex = fbSelectedCharacterIndex + 1
            if fbSelectedCharacterIndex > #fbCharacterOptions then fbSelectedCharacterIndex = 1 end
        elseif key == 'return' then
            fbStartGame(fbCharacterOptions[fbSelectedCharacterIndex].image_path)
        elseif key == 'escape' then
            internalFbGameState = "menu" -- Go back to Flappy Bird's internal menu
        end
    elseif internalFbGameState == "menu" then
        if key == 'return' then
            internalFbGameState = "characterSelect"
        elseif key == 'escape' then
            if returnToGameBoxMenuCallback then returnToGameBoxMenuCallback() end
        end
    elseif internalFbGameState == "game" then
        if key == 'escape' then -- Toggle pause menu
            fbGamePaused = not fbGamePaused
            if fbGamePaused then
                fbSelectedPauseOption = 1 -- Reset selection when opening pause menu
            end
        end

        if fbGamePaused then
            -- Pause menu controls
            if key == 'up' then
                fbSelectedPauseOption = fbSelectedPauseOption - 1
                if fbSelectedPauseOption < 1 then fbSelectedPauseOption = #fbPauseMenuOptions end
            elseif key == 'down' then
                fbSelectedPauseOption = fbSelectedPauseOption + 1
                if fbSelectedPauseOption > #fbPauseMenuOptions then fbSelectedPauseOption = 1 end
            elseif key == 'return' then
                if fbPauseMenuOptions[fbSelectedPauseOption] == "Resume" then
                    fbGamePaused = false
                elseif fbPauseMenuOptions[fbSelectedPauseOption] == "Quit to Game Box" then
                    if returnToGameBoxMenuCallback then returnToGameBoxMenuCallback() end
                end
            end
        else -- Game is active (not paused)
            if key == 'space' then
                if fbPlayer then fbPlayer:jump() end
            end
        end
    end
end

function FlappyGame.update(dt)
    if internalFbGameState ~= "game" or fbGamePaused then return end
    
    if not fbPlayer then return end -- Safety check

    -- Pipe updates (recycling)
    if fbPipe1 and fbPipe1.x + fbPipe1.width < 0 then -- fbPipe1.width needs to be a property of the pipe object
        -- Recycle pipe1 and pipe2
        local pipeGapYMin = -120; local pipeGapYMax = -5
        local pipeGapY = love.math.random(pipeGapYMin, pipeGapYMax)
        local pipeOpeningHeight = 100
        fbPipe1:reset(FB_WINDOW_WIDTH, pipeGapY) -- Assuming pipe objects have a reset method
        fbPipe2:reset(FB_WINDOW_WIDTH, pipeGapY + fbPipeDownImage:getHeight() + pipeOpeningHeight)
    end

    if fbPipe3 and fbPipe3.x + fbPipe3.width < 0 then
        -- Recycle pipe3 and pipe4
        local pipeGapYMin = -120; local pipeGapYMax = -5
        local pipeGapY = love.math.random(pipeGapYMin, pipeGapYMax)
        local pipeOpeningHeight = 100
        fbPipe3:reset(FB_WINDOW_WIDTH, pipeGapY)
        fbPipe4:reset(FB_WINDOW_WIDTH, pipeGapY + fbPipeDownImage:getHeight() + pipeOpeningHeight)
    end

    -- Game entities update
    fbPlayer:update(dt)
    if fbPipe1 then fbPipe1:update(dt) end
    if fbPipe2 then fbPipe2:update(dt) end
    if fbPipe3 then fbPipe3:update(dt) end
    if fbPipe4 then fbPipe4:update(dt) end

    -- Collision detection
    local collided = false
    if fbPipe1 and fbPlayer:collision(fbPipe1) then collided = true end
    if not collided and fbPipe2 and fbPlayer:collision(fbPipe2) then collided = true end
    if not collided and fbPipe3 and fbPlayer:collision(fbPipe3) then collided = true end
    if not collided and fbPipe4 and fbPlayer:collision(fbPipe4) then collided = true end
    if not collided and fbGrass and fbPlayer:collision(fbGrass) then collided = true end
    if not collided and fbPlayer.y + fbPlayer.height > FB_WINDOW_HEIGHT then collided = true end -- Fell off bottom
    if not collided and fbPlayer.y < 0 then collided = true end -- Hit top

    if collided then
        internalFbGameState = "gameOver"
        return -- Stop further updates in this frame if game over
    end

    -- Score updates
    if fbPipe1 and fbUpcomingPipe == 1 and fbPlayer.x > (fbPipe1.x + fbPipe1.width) then
        fbScore = fbScore + 1
        fbUpcomingPipe = 2 -- Next scoring pipe is pipe3 (the second set)
        if fbScoreSound then fbScoreSound:play() end
    end
    if fbPipe3 and fbUpcomingPipe == 2 and fbPlayer.x > (fbPipe3.x + fbPipe3.width) then
        fbScore = fbScore + 1
        fbUpcomingPipe = 1 -- Next scoring pipe is pipe1 (the first set, after recycling)
        if fbScoreSound then fbScoreSound:play() end
    end
end

fbDrawMainMenu = function()
    love.graphics.setColor(fbMenuOverlayColor)
    love.graphics.rectangle('fill', 0, 0, FB_WINDOW_WIDTH, FB_WINDOW_HEIGHT)
    
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(fbTitleFont)
    love.graphics.printf("Flappy Bird!", 0, 100, FB_WINDOW_WIDTH, 'center')
    
    love.graphics.setFont(fbMenuFont)
    love.graphics.printf("Press ENTER to start", 0, 200, FB_WINDOW_WIDTH, 'center')
    love.graphics.printf("Press ESC to return to Game Box", 0, 250, FB_WINDOW_WIDTH, 'center')
end

fbDrawCharacterSelect = function()
    love.graphics.setColor(fbPurple)
    love.graphics.rectangle('fill', 0, 0, FB_WINDOW_WIDTH, FB_WINDOW_HEIGHT)
    
    love.graphics.setColor(0, 0, 0)
    love.graphics.setFont(fbTitleFont)
    love.graphics.printf("Flappy Bird", 0, 50, FB_WINDOW_WIDTH, 'center')

    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(love.graphics.newFont(asset('Fonts/DIMIS___.TTF'), 20)) -- Or use a preloaded smaller font
    love.graphics.printf("CHOOSE YOUR CHARACTER", 0, 100, FB_WINDOW_WIDTH, 'center')
    
    local containerSize = 120
    local padding = 20
    local totalWidth = (#fbCharacterOptions * containerSize) + ((#fbCharacterOptions - 1) * padding)
    local startX = (FB_WINDOW_WIDTH - totalWidth) / 2
    
    for i, charOption in ipairs(fbCharacterOptions) do
        local containerX = startX + (i-1) * (containerSize + padding)
        local containerY = 170
        
        if i == fbSelectedCharacterIndex then
            love.graphics.setColor(1, 0.84, 0) -- Gold for selected
            love.graphics.setLineWidth(4)
        else
            love.graphics.setColor(0.3, 0.3, 0.3) -- Dark gray
            love.graphics.setLineWidth(2)
        end
        love.graphics.rectangle('line', containerX, containerY, containerSize, containerSize)
        
        local imgObj = charOption.image_obj
        if imgObj then
            local scale = math.min(
                (containerSize - 10) / imgObj:getWidth(),
                (containerSize - 10) / imgObj:getHeight()
            )
            love.graphics.setColor(1, 1, 1)
            love.graphics.draw(imgObj, containerX + containerSize/2, containerY + containerSize/2,
                               0, scale, scale, imgObj:getWidth()/2, imgObj:getHeight()/2)
        end
    end
    love.graphics.setLineWidth(1) -- Reset line width
    
    love.graphics.setColor(1,1,1)
    love.graphics.setFont(love.graphics.newFont(asset('Fonts/DIMIS___.TTF'), 20))
    love.graphics.printf("Use LEFT/RIGHT arrows to select", 0, 330, FB_WINDOW_WIDTH, 'center')
    love.graphics.printf("Press ENTER to confirm", 0, 380, FB_WINDOW_WIDTH, 'center')
    love.graphics.printf("Press ESC to go back to Flappy Menu", 0, 410, FB_WINDOW_WIDTH, 'center')
end

fbDrawGameScreen = function()
    -- Game elements are drawn on top of the background (drawn in FlappyGame.draw)
    if fbPipe1 then fbPipe1:render() end
    if fbPipe2 then fbPipe2:render() end
    if fbPipe3 then fbPipe3:render() end
    if fbPipe4 then fbPipe4:render() end
    if fbPlayer then fbPlayer:render() end
    if fbGrass then fbGrass:render() end
    if fbDirt then fbDirt:render() end

    -- Draw score
    love.graphics.setColor(0, 0, 0)
    love.graphics.setFont(fbFont)
    love.graphics.print("Score: " .. fbScore, 20, 20) -- Adjusted position
    love.graphics.setColor(1, 1, 1) -- Reset color

    -- Draw pause menu if game is paused
    if fbGamePaused then
        love.graphics.setColor(fbMenuOverlayColor)
        love.graphics.rectangle('fill', 0, 0, FB_WINDOW_WIDTH, FB_WINDOW_HEIGHT)
        
        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(fbTitleFont) -- Use title font for "PAUSED"
        love.graphics.printf("PAUSED", 0, 150, FB_WINDOW_WIDTH, 'center')
        
        love.graphics.setFont(fbMenuFont)
        for i, optionText in ipairs(fbPauseMenuOptions) do
            if i == fbSelectedPauseOption then
                love.graphics.setColor(1, 0.84, 0) -- Gold
            else
                love.graphics.setColor(1, 1, 1) -- White
            end
            love.graphics.printf(optionText, 0, 250 + (i * 50), FB_WINDOW_WIDTH, 'center')
        end
        
        love.graphics.setColor(0.7, 0.7, 0.7)
        love.graphics.setFont(love.graphics.newFont(asset('Fonts/DIMIS___.TTF'), 18)) -- Smaller font for instructions
        love.graphics.printf("Use UP/DOWN arrows, ENTER to confirm", 0, FB_WINDOW_HEIGHT - 70, FB_WINDOW_WIDTH, 'center')
    end
end

fbDrawGameOverScreen = function()
    -- Draw the game screen in the background
    fbDrawGameScreen()

    -- Semi-transparent dark overlay
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle('fill', 0, 0, FB_WINDOW_WIDTH, FB_WINDOW_HEIGHT)
    
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(fbTitleFont)
    love.graphics.printf("GAME OVER", 0, 120, FB_WINDOW_WIDTH, 'center')
    
    love.graphics.setFont(fbFont)
    love.graphics.printf("Score: " .. fbScore, 0, 180, FB_WINDOW_WIDTH, 'center')
    
    love.graphics.setFont(love.graphics.newFont(asset('Fonts/DIMIS___.TTF'), 20))
    love.graphics.printf("Press ENTER to restart", 0, 300, FB_WINDOW_WIDTH, 'center')
    love.graphics.printf("Press ESC for Game Box Menu", 0, 350, FB_WINDOW_WIDTH, 'center')
end

function FlappyGame.draw()
    if not fbFont then print("FlappyGame.draw: Fonts not loaded yet!"); return end -- Safety check

    -- Always draw the background first
    if fbBackgroundImage then
        love.graphics.draw(fbBackgroundImage, 0, 0, 0, 
                           FB_WINDOW_WIDTH / fbBackgroundImage:getWidth(), 
                           FB_WINDOW_HEIGHT / fbBackgroundImage:getHeight())
    else
        -- Fallback background color if image fails to load
        love.graphics.setColor(fbSkyBlue)
        love.graphics.rectangle('fill', 0,0, FB_WINDOW_WIDTH, FB_WINDOW_HEIGHT)
        love.graphics.setColor(1,1,1) -- Reset color
    end
    
    if internalFbGameState == "menu" then
        fbDrawMainMenu()
    elseif internalFbGameState == "characterSelect" then
        fbDrawCharacterSelect()
    elseif internalFbGameState == "game" then
        if fbPlayer then -- Ensure game elements are ready
            fbDrawGameScreen()
        else -- If player not ready (e.g. error in startGame), show menu
            fbDrawMainMenu()
        end
    elseif internalFbGameState == "gameOver" then
        fbDrawGameOverScreen() -- This already includes drawing the game screen behind it
    end
end

function FlappyGame.unload()
    print("FlappyGame.unload called")
    -- Stop any sounds specific to Flappy Bird
    if fbScoreSound and fbScoreSound:isPlaying() then fbScoreSound:stop() end
    fbScoreSound = nil -- Release the source

    -- Release other LÖVE objects to free memory
    fbFont, fbMenuFont, fbTitleFont = nil, nil, nil
    fbBackgroundImage = nil
    fbPipeDownImage, fbPipeUpImage = nil, nil
    
    for i, charOption in ipairs(fbCharacterOptions) do
        charOption.image_obj = nil -- Release image object
    end

    -- Release game entities
    fbPlayer = nil
    fbPipe1, fbPipe2, fbPipe3, fbPipe4 = nil, nil, nil, nil
    fbDirt, fbGrass = nil, nil

    -- Reset states
    internalFbGameState = "menu"
    fbGamePaused = false
    fbScore = 0

    print("Flappy Bird resources unloaded.")
end

return FlappyGame
