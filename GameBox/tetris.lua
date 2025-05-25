-- Tetris game in LÖVE2D - Final Complete Version

function love.load()
    -- Game constants
    love.window.setTitle("Tetris")
    math.randomseed(os.time())
    
    -- Game settings
    GRID_WIDTH = 10
    GRID_HEIGHT = 17
    CELL_SIZE = 30
    GRID_OFFSET_X = 50
    GRID_OFFSET_Y = 50
    
    -- Colors
    COLORS = {
        {0, 0, 0},       -- 0: black (empty)
        {0.8, 0.1, 0.1}, -- 1: red (I)
        {0.1, 0.8, 0.1}, -- 2: green (J)
        {0.1, 0.1, 0.8}, -- 3: blue (L)
        {0.8, 0.8, 0.1}, -- 4: yellow (O)
        {0.8, 0.1, 0.8}, -- 5: purple (S)
        {0.1, 0.8, 0.8}, -- 6: cyan (T)
        {0.5, 0.5, 0.5}  -- 7: gray (Z)
    }
    
    -- Tetromino shapes
    SHAPES = {
        -- I
        {
            {0,0,0,0},
            {1,1,1,1},
            {0,0,0,0},
            {0,0,0,0}
        },
        -- J
        {
            {2,0,0},
            {2,2,2},
            {0,0,0}
        },
        -- L
        {
            {0,0,3},
            {3,3,3},
            {0,0,0}
        },
        -- O
        {
            {4,4},
            {4,4}
        },
        -- S
        {
            {0,5,5},
            {5,5,0},
            {0,0,0}
        },
        -- T
        {
            {0,6,0},
            {6,6,6},
            {0,0,0}
        },
        -- Z
        {
            {7,7,0},
            {0,7,7},
            {0,0,0}
        }
    }
    
    -- Initialize game state
    grid = {}
    for y = 1, GRID_HEIGHT do
        grid[y] = {}
        for x = 1, GRID_WIDTH do
            grid[y][x] = 0
        end
    end
    
    score = 0
    level = 1
    lines_cleared = 0
    game_over = false
    pause = false
    
    -- Create first piece
    newPiece()
    
    -- Game timing
    drop_time = 0
    drop_speed = 0.5 -- seconds
    love.keyboard.setKeyRepeat(true)
end

function newPiece()
    -- Select random shape
    local shape_index = math.random(1, #SHAPES)
    local shape = SHAPES[shape_index]
    local shape_height = #shape
    
    -- Find the lowest block in the shape
    local lowest_block = 1
    for y = 1, shape_height do
        for x = 1, #shape[y] do
            if shape[y][x] ~= 0 and y > lowest_block then
                lowest_block = y
            end
        end
    end
    
    -- Calculate spawn position to ensure piece is fully visible
    local spawn_y = 2 - lowest_block  -- Ensures the lowest block starts at y=1
    
    current_piece = {
        shape = shape,
        x = math.floor(GRID_WIDTH / 2) - math.floor(#shape[1] / 2),
        y = spawn_y,
        color = shape_index
    }
    
    -- Check if game over (new piece can't be placed)
    if checkCollision(current_piece.x, current_piece.y, current_piece.shape) then
        game_over = true
    end
end

function rotatePiece()
    local rotated = {}
    local size = #current_piece.shape
    
    for y = 1, size do
        rotated[y] = {}
        for x = 1, size do
            rotated[y][x] = current_piece.shape[size - x + 1][y]
        end
    end
    
    -- Check if rotation is possible
    if not checkCollision(current_piece.x, current_piece.y, rotated) then
        current_piece.shape = rotated
    end
end

function checkCollision(x, y, shape)
    local size = #shape
    
    for py = 1, size do
        for px = 1, size do
            if shape[py][px] ~= 0 then
                local nx = x + px - 1
                local ny = y + py - 1
                
                -- Check left/right boundaries
                if nx < 1 or nx > GRID_WIDTH then
                    return true
                end
                
                -- Check bottom boundary
                if ny > GRID_HEIGHT then
                    return true
                end
                
                -- Check if already occupied (only if within grid bounds)
                if ny >= 1 and grid[ny][nx] ~= 0 then
                    return true
                end
            end
        end
    end
    
    return false
end

function mergePiece()
    local size = #current_piece.shape
    
    for py = 1, size do
        for px = 1, size do
            if current_piece.shape[py][px] ~= 0 then
                local nx = current_piece.x + px - 1
                local ny = current_piece.y + py - 1
                
                -- Only merge if within grid bounds
                if ny >= 1 and ny <= GRID_HEIGHT then
                    grid[ny][nx] = current_piece.color
                end
            end
        end
    end
end

function clearLines()
    local lines_to_clear = {}
    
    -- Check which lines are complete
    for y = 1, GRID_HEIGHT do
        local complete = true
        for x = 1, GRID_WIDTH do
            if grid[y][x] == 0 then
                complete = false
                break
            end
        end
        
        if complete then
            table.insert(lines_to_clear, y)
        end
    end
    
    -- Clear lines and add score
    if #lines_to_clear > 0 then
        for _, y in ipairs(lines_to_clear) do
            -- Remove the line
            table.remove(grid, y)
            -- Add new empty line at the top
            table.insert(grid, 1, {})
            for x = 1, GRID_WIDTH do
                grid[1][x] = 0
            end
            
            -- Update score
            lines_cleared = lines_cleared + 1
            score = score + 100 * level
            
            -- Level up every 10 lines
            if lines_cleared % 10 == 0 then
                level = level + 1
                drop_speed = drop_speed * 0.9 -- Increase speed
            end
        end
    end
end

function love.update(dt)
    if game_over or pause then return end
    
    drop_time = drop_time + dt
    
    -- Auto drop
    if drop_time > drop_speed then
        drop_time = 0
        movePiece(0, 1)
    end
end

function movePiece(dx, dy)
    if not checkCollision(current_piece.x + dx, current_piece.y + dy, current_piece.shape) then
        current_piece.x = current_piece.x + dx
        current_piece.y = current_piece.y + dy
        return true
    end
    
    -- If we couldn't move down, place the piece
    if dy > 0 then
        mergePiece()
        -- Add small score for placing a piece
        score = score + 5 * level
        clearLines()
        newPiece()
    end
    
    return false
end

function love.keypressed(key)
    if game_over then
        if key == "r" then
            love.load()
        end
        return
    end
    
    if key == "p" then
        pause = not pause
        return
    end
    
    if pause then return end
    
    if key == "left" then
        movePiece(-1, 0)
    elseif key == "right" then
        movePiece(1, 0)
    elseif key == "down" then
        movePiece(0, 1)
    elseif key == "up" then
        rotatePiece()
    elseif key == "space" then
        -- Hard drop
        while movePiece(0, 1) do end
    end
end

function love.draw()
    -- Draw grid background
    love.graphics.setColor(0.2, 0.2, 0.2)
    love.graphics.rectangle("fill", GRID_OFFSET_X - 2, GRID_OFFSET_Y - 2, 
                           GRID_WIDTH * CELL_SIZE + 4, GRID_HEIGHT * CELL_SIZE + 4)
    
    -- Draw grid cells
    for y = 1, GRID_HEIGHT do
        for x = 1, GRID_WIDTH do
            if grid[y][x] ~= 0 then
                local color = COLORS[grid[y][x]]
                love.graphics.setColor(color)
                love.graphics.rectangle("fill", 
                    GRID_OFFSET_X + (x-1) * CELL_SIZE, 
                    GRID_OFFSET_Y + (y-1) * CELL_SIZE, 
                    CELL_SIZE - 1, CELL_SIZE - 1)
            end
        end
    end
    
    -- Draw current piece
    if current_piece then
        local size = #current_piece.shape
        for py = 1, size do
            for px = 1, size do
                if current_piece.shape[py][px] ~= 0 then
                    local nx = current_piece.x + px - 1
                    local ny = current_piece.y + py - 1
                    
                    -- Only draw if within visible grid
                    if ny >= 1 and ny <= GRID_HEIGHT then
                        local color = COLORS[current_piece.color]
                        love.graphics.setColor(color)
                        love.graphics.rectangle("fill", 
                            GRID_OFFSET_X + (nx-1) * CELL_SIZE, 
                            GRID_OFFSET_Y + (ny-1) * CELL_SIZE, 
                            CELL_SIZE - 1, CELL_SIZE - 1)
                    end
                end
            end
        end
    end
    
    -- Draw game info
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Score: " .. score, GRID_OFFSET_X + GRID_WIDTH * CELL_SIZE + 20, 50)
    love.graphics.print("Level: " .. level, GRID_OFFSET_X + GRID_WIDTH * CELL_SIZE + 20, 80)
    love.graphics.print("Lines: " .. lines_cleared, GRID_OFFSET_X + GRID_WIDTH * CELL_SIZE + 20, 110)
    
    -- Draw controls
    love.graphics.print("Controls:", GRID_OFFSET_X + GRID_WIDTH * CELL_SIZE + 20, 150)
    love.graphics.print("Left/Right: Move", GRID_OFFSET_X + GRID_WIDTH * CELL_SIZE + 20, 170)
    love.graphics.print("Up: Rotate", GRID_OFFSET_X + GRID_WIDTH * CELL_SIZE + 20, 190)
    love.graphics.print("Down: Soft Drop", GRID_OFFSET_X + GRID_WIDTH * CELL_SIZE + 20, 210)
    love.graphics.print("Space: Hard Drop", GRID_OFFSET_X + GRID_WIDTH * CELL_SIZE + 20, 230)
    love.graphics.print("P: Pause", GRID_OFFSET_X + GRID_WIDTH * CELL_SIZE + 20, 250)
    love.graphics.print("R: Restart", GRID_OFFSET_X + GRID_WIDTH * CELL_SIZE + 20, 270)
    
    -- Draw game over message
    if game_over then
        love.graphics.setColor(1, 0, 0, 0.7)
        love.graphics.rectangle("fill", 0, love.graphics.getHeight()/2 - 50, 
                              love.graphics.getWidth(), 100)
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf("GAME OVER", 0, love.graphics.getHeight()/2 - 30, 
                           love.graphics.getWidth(), "center")
        love.graphics.printf("Press R to restart", 0, love.graphics.getHeight()/2 + 10, 
                           love.graphics.getWidth(), "center")
    end
    
    -- Draw pause message
    if pause then
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle("fill", 0, love.graphics.getHeight()/2 - 50, 
                              love.graphics.getWidth(), 100)
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf("PAUSED", 0, love.graphics.getHeight()/2 - 30, 
                           love.graphics.getWidth(), "center")
        love.graphics.printf("Press P to continue", 0, love.graphics.getHeight()/2 + 10, 
                           love.graphics.getWidth(), "center")
    end
end