--[[
  Exhaustive Donkey Kong Input Finder
  ====================================
  
  This script will find the exact input port and field that controls Mario,
  adds credits, and starts the game. It is the most reliable way to solve
  any input problem.

  How it works:
  1. It gets a list of ALL input ports and ALL of their fields.
  2. It tests every single field one-by-one, activating it for half a second.
  3. It prints the Port and Field it is currently testing to the MAME console.
  4. The test will repeat.

  How to use:
  1. Run MAME with this script.
  2. Watch the game. When Mario moves, jumps, a credit is added, or the
     game starts, immediately write down the Port and Field name shown
     in the MAME console.
--]]

-- References to MAME's core components
local ioport = manager.machine.ioport

-- This table will hold all possible fields we can test
local all_testable_fields = {}
local current_field_index = 1
local switch_time = manager.machine.time.seconds + 7 -- 7-second initial wait

-- ============================================================================
-- Initialization
-- ============================================================================

-- This function runs once at the start to build our list of things to test.
function build_field_list()
    emu.print_info("Building list of all available input fields...")
    for port_tag, port in pairs(ioport.ports) do
        for field_name, _ in pairs(port.fields) do
            -- Add a table containing the port and field name to our list
            table.insert(all_testable_fields, {port = port_tag, field = field_name})
        end
    end
    emu.print_info("Found " .. #all_testable_fields .. " fields to test. Starting test...")
end

-- ============================================================================
-- Main Test Loop
-- ============================================================================

function run_test_frame()
    -- Don't start until the initial wait is over
    if manager.machine.time.seconds < 7 then return end

    -- Check if it's time to switch to the next field
    if manager.machine.time.seconds > switch_time then
        -- Deactivate the last field we tested
        if #all_testable_fields > 0 then
            local last_test = all_testable_fields[current_field_index]
            local last_port = ioport.ports[last_test.port]
            if last_port and last_port.fields[last_test.field] then
                last_port.fields[last_test.field]:set_value(0)
            end
        end

        current_field_index = current_field_index + 1
        -- If we've gone past the end of the list, loop back to the beginning.
        if current_field_index > #all_testable_fields then
            current_field_index = 1
            emu.print_info("=========================================")
            emu.print_info("RESTARTING TEST CYCLE")
            emu.print_info("=========================================")
        end
        
        switch_time = manager.machine.time.seconds + 0.5 -- Test each field for half a second
    end

    -- Activate the current field we are testing
    if #all_testable_fields > 0 then
        local current_test = all_testable_fields[current_field_index]
        local current_port = ioport.ports[current_test.port]
        if current_port and current_port.fields[current_test.field] then
            current_port.fields[current_test.field]:set_value(1)
            
            -- Print the current test case to the MAME console
            local text = string.format("Testing Port: %s  --  Field: %s", current_test.port, current_test.field)
            emu.print_info(text)
        end
    end
end

-- Register the test loop to be called on each frame.
emu.register_frame_done(run_test_frame, "frame")

-- ============================================================================
-- Script Start
-- ============================================================================

build_field_list()
emu.print_info("Donkey Kong Exhaustive Input Finder Loaded.")
emu.print_info("Waiting for 7 seconds before starting test...")

