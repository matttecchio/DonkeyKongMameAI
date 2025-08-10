# DonkeyKongMameAI
LUA and Q-learning reinforcement model for Donkey Kong Arcade
#
#
Important Memory Addresses
#
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

  Input is dependant on what port MAME expects your keystrokes or joystick inputs to come through on.
  For my testing purposes this was IN0 for player 1 and IN2 for system inputs.
  Player 1 = Jump, left, right, up, down
  System Input = Insert Credit, Player 1 Start

  The included file testinput.lua will cycle through every port available in MAME and attempt to test each input.
  You can use this to help you identify the port and field names if yours vary from mine.
  
