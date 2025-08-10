--[[
  Donkey Kong AI Control Script for MAME (FINAL)
  ==============================================

  This is the complete, working script to interface with the Python AI.
  It uses the confirmed correct input ports and fields to automatically
  start the game, control player movement, and restart on game over.
  This version includes a fix for the jump action.

  How it works:
  1. On startup, it runs a sequence to add a credit and start a 1-player game.
  2. On each subsequent frame, it reads the game state from memory.
  3. It calculates a "reward" based on what happened since the last frame.
  4. It writes the current state and reward to 'state.txt'.
  5. It waits for the Python script to create a file named 'action.txt'.
  6. It reads the action, performs it, and the loop repeats.
  7. When a Game Over is detected, it automatically restarts the game.

  How to use:
  1. Save this script as 'dkong_ai.lua'.
  2. Run MAME with this script:
     mame dkong -window -nothrottle -autoboot_script dkong_ai.lua
  3. Run the 'dkong_ai_brain.py' script in a separate terminal.
--]]

-- ============================================================================
-- Configuration
-- ============================================================================

-- Memory Addresses for Donkey Kong (dkong)
local memory_addresses = {
    game_start = 0x622C,
    end_of_level_counter = 0x6388,
    score_100k = 0x7781,
    score_10k = 0x7761,
    score_1k = 0x7741,
    score_100 = 0x7721,
    score_10 = 0x7701,
    bonus = 0x62B1,
    lives = 0x6228,
    level = 0x6229,
    screen_id = 0x6227,
    is_dead = 0x6200,
    is_jumping = 0x6216,
    jumping_direction = 0x6211,
    has_hammer = 0x6217,
    bonus_item_collected = 0x6343,
}

-- References to MAME's core components
local maincpu = manager.machine.devices[':maincpu']
local mem = maincpu.spaces['program']
local ioport = manager.machine.ioport

-- Confirmed correct port names
local p1_port_name = ':IN0' 
local system_port_name = ':IN2'

-- AI Learning Framework Variables
local last_state = {}
local reward = 0
local communication_ready = true

-- Game Start Sequence Variables
local game_started = false
local start_step = 1
local next_start_action_time = manager.machine.time.seconds + 2

-- JUMP FIX: Variables to manage holding the jump button
local jump_frames_remaining = 0
local JUMP_HOLD_DURATION = 5 -- Hold jump for 5 frames

-- ============================================================================
-- Helper Functions
-- ============================================================================

function get_game_state()
    local state = {}
    state.game_start = mem:read_u8(memory_addresses.game_start)
    state.end_of_level_counter = mem:read_u8(memory_addresses.end_of_level_counter)
    local s100k = mem:read_u8(memory_addresses.score_100k)
    local s10k = mem:read_u8(memory_addresses.score_10k)
    local s1k = mem:read_u8(memory_addresses.score_1k)
    local s100 = mem:read_u8(memory_addresses.score_100)
    local s10 = mem:read_u8(memory_addresses.score_10)
    state.score = (s100k * 100000) + (s10k * 10000) + (s1k * 1000) + (s100 * 100) + (s10 * 10)
    state.bonus = mem:read_u8(memory_addresses.bonus) * 100
    state.lives = mem:read_u8(memory_addresses.lives)
    state.level = mem:read_u8(memory_addresses.level)
    state.screen_id = mem:read_u8(memory_addresses.screen_id)
    state.is_dead = mem:read_u8(memory_addresses.is_dead)
    state.is_jumping = mem:read_u8(memory_addresses.is_jumping)
    state.jumping_direction = mem:read_u8(memory_addresses.jumping_direction)
    state.has_hammer = mem:read_u8(memory_addresses.has_hammer)
    state.bonus_item_collected = mem:read_u8(memory_addresses.bonus_item_collected)
    return state
end

function perform_action(action)
    local p1_port = ioport.ports[p1_port_name]
    if not p1_port then return end

    -- Reset directional inputs
    p1_port.fields['P1 Up']:set_value(0)
    p1_port.fields['P1 Down']:set_value(0)
    p1_port.fields['P1 Left']:set_value(0)
    p1_port.fields['P1 Right']:set_value(0)

    -- JUMP FIX: When the AI says "JUMP", we start the multi-frame hold.
    -- The actual button press is handled in the main loop.
    if action == "JUMP" then
        if jump_frames_remaining == 0 then -- Prevent re-triggering a jump while already jumping
            jump_frames_remaining = JUMP_HOLD_DURATION
        end
    elseif action == "UP" then p1_port.fields['P1 Up']:set_value(1)
    elseif action == "DOWN" then p1_port.fields['P1 Down']:set_value(1)
    elseif action == "LEFT" then p1_port.fields['P1 Left']:set_value(1)
    elseif action == "RIGHT" then p1_port.fields['P1 Right']:set_value(1)
    end
end

-- ============================================================================
-- AI Learning Functions
-- ============================================================================

function calculate_reward(current_state, prev_state)
    local calculated_reward = 0
    if current_state.score > prev_state.score then
        calculated_reward = calculated_reward + (current_state.score - prev_state.score)
    end
    if current_state.lives < prev_state.lives then
        calculated_reward = calculated_reward - 1000
    end
    if current_state.level > prev_state.level or (current_state.end_of_level_counter > 0 and prev_state.end_of_level_counter == 0) then
         calculated_reward = calculated_reward + 500
    end
    if current_state.is_dead ~= 0 then
        calculated_reward = calculated_reward + 1
    end
    return calculated_reward
end

function send_state_to_ai(state, current_reward)
    local file, err = io.open("state.txt", "w")
    if not file then return end
    for key, value in pairs(state) do
        file:write(key .. ":" .. tostring(value) .. "\n")
    end
    file:write("reward:" .. tostring(current_reward) .. "\n")
    file:close()
    communication_ready = false
end

function get_action_from_ai()
    local file = io.open("action.txt", "r")
    if file then
        local action = file:read("*a")
        file:close()
        os.remove("action.txt")
        communication_ready = true
        return action:gsub("[\r\n]", "")
    end
    return nil
end

-- ============================================================================
-- Main AI Loop
-- ============================================================================

function run_ai_frame()
    if not game_started then
        -- Game start sequence
        if manager.machine.time.seconds > next_start_action_time then
            local coin_field_name = 'Coin 1'
            local start_field_name = '1 Player Start' 
            local port = ioport.ports[system_port_name]

            if not port then manager.machine:pause() return end

            if start_step == 1 then
                port.fields[coin_field_name]:set_value(1)
                next_start_action_time = manager.machine.time.seconds + 0.2
                start_step = 2
            elseif start_step == 2 then
                port.fields[coin_field_name]:set_value(0)
                next_start_action_time = manager.machine.time.seconds + 3
                start_step = 3
            elseif start_step == 3 then
                port.fields[start_field_name]:set_value(1)
                next_start_action_time = manager.machine.time.seconds + 0.2
                start_step = 4
            elseif start_step == 4 then
                port.fields[start_field_name]:set_value(0)
                game_started = true
            end
        end
    else
        -- Normal AI learning loop
        local current_state = get_game_state()

        if current_state.lives == 0 and last_state.lives > 0 then
            game_started = false
            start_step = 1
            next_start_action_time = manager.machine.time.seconds + 2
            last_state = current_state
            return
        end

        if communication_ready then
            if next(last_state) ~= nil then
                reward = calculate_reward(current_state, last_state)
            end
            send_state_to_ai(current_state, reward)
            last_state = current_state
        else
            local action = get_action_from_ai()
            if action then
                perform_action(action)
            end
        end

        -- JUMP FIX: Handle the multi-frame jump press
        local p1_port = ioport.ports[p1_port_name]
        if p1_port then
            if jump_frames_remaining > 0 then
                p1_port.fields['P1 Button 1']:set_value(1)
                jump_frames_remaining = jump_frames_remaining - 1
            else
                p1_port.fields['P1 Button 1']:set_value(0)
            end
        end
    end
end

-- Register the AI loop to be called on each frame.
emu.register_frame_done(run_ai_frame, "frame")

-- ============================================================================
-- Script Start
-- ============================================================================

last_state = get_game_state()
emu.print_info("Donkey Kong AI Learning Framework Loaded.")
emu.print_info("Player 1 Port: '" .. p1_port_name .. "', System Port: '" .. system_port_name .. "'.")
emu.print_info("Starting game sequence...")

