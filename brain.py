# Donkey Kong AI Brain - Q-Learning
# ==================================
# This script acts as the "brain" for the MAME Lua script.
# It reads the game state, decides on an action using a Q-learning algorithm,
# and writes the action back for the Lua script to perform.
#
# How to run:
# 1. Make sure you have Python installed.
# 2. Save this file as 'dkong_ai_brain.py' in the SAME directory as MAME
#    and your 'dkong_ai.lua' script.
# 3. Run MAME with the Lua script first.
# 4. In a separate terminal or command prompt, run this Python script:
#    python dkong_ai_brain.py

import os
import time
import json
import random

# --- Configuration ---
STATE_FILE = "state.txt"
ACTION_FILE = "action.txt"
ACTION_FILE_TMP = "action.txt.tmp" # Temporary file for atomic writes
Q_TABLE_FILE = "q_table.json"

# --- Q-Learning Parameters ---
LEARNING_RATE = 0.1  # Alpha: How much we learn from a new experience.
DISCOUNT_FACTOR = 0.95 # Gamma: How much we value future rewards.
EPSILON = 1.0          # Initial exploration rate (100% random actions).
EPSILON_DECAY = 0.9999 # How much epsilon decreases after each action.
MIN_EPSILON = 0.01     # Minimum exploration rate.

POSSIBLE_ACTIONS = ["UP", "DOWN", "LEFT", "RIGHT", "JUMP", "NONE"]

# --- Helper Functions ---

def load_q_table():
    """Loads the Q-table from a JSON file if it exists."""
    if os.path.exists(Q_TABLE_FILE):
        with open(Q_TABLE_FILE, 'r') as f:
            print("Loading existing Q-table...")
            return json.load(f)
    print("No Q-table found, starting a new one.")
    return {}

def save_q_table(q_table):
    """Saves the Q-table to a JSON file."""
    with open(Q_TABLE_FILE, 'w') as f:
        json.dump(q_table, f)

def read_state_from_file():
    """Reads the state and reward from the file created by the Lua script."""
    if not os.path.exists(STATE_FILE):
        return None, None

    # Wait a moment to ensure the file is fully written
    time.sleep(0.01)
    
    state = {}
    reward = 0
    try:
        with open(STATE_FILE, 'r') as f:
            for line in f:
                if ":" in line:
                    key, value = line.strip().split(':', 1)
                    if key == 'reward':
                        reward = float(value)
                    else:
                        state[key] = int(value)
        os.remove(STATE_FILE) # Clean up the file
        return state, reward
    except (IOError, ValueError) as e:
        print(f"Error reading state file: {e}")
        return None, None

def write_action_to_file(action):
    """
    Writes the chosen action to a file atomically.
    It writes to a temporary file first, then renames it to prevent race conditions.
    """
    try:
        # Write to a temporary file
        with open(ACTION_FILE_TMP, 'w') as f:
            f.write(action)
        
        # --- FIX for Windows ---
        # On Windows, os.rename fails if the destination file already exists.
        # To prevent this race condition, we explicitly remove the old action
        # file before renaming the new one.
        if os.path.exists(ACTION_FILE):
            os.remove(ACTION_FILE)
            
        # Atomically rename the file
        os.rename(ACTION_FILE_TMP, ACTION_FILE)
    except (IOError, OSError) as e:
        print(f"Error writing action file: {e}")

def get_simplified_state(state):
    """
    Converts the detailed game state into a simplified, manageable string.
    This is crucial because the number of raw states is too large for a Q-table.
    We "bucket" continuous values like coordinates.
    """
    if not state:
        return "invalid"
        
    # Example simplification: focus on screen, lives, and if Mario is dead.
    # A better simplification might bucket Mario's X/Y coordinates.
    # For now, we'll use a few key indicators.
    return f"screen:{state.get('screen_id', 0)}-dead:{state.get('is_dead', 0)}-hammer:{state.get('has_hammer', 0)}"

# --- Main AI Functions ---

def choose_action(state_key, q_table):
    """
    Chooses an action using an epsilon-greedy policy.
    - With probability epsilon, chooses a random action (exploration).
    - Otherwise, chooses the best known action (exploitation).
    """
    global EPSILON
    
    # Ensure the state exists in the Q-table before choosing an action.
    if state_key not in q_table:
        q_table[state_key] = {act: 0 for act in POSSIBLE_ACTIONS}

    # Exploration vs. Exploitation
    if random.uniform(0, 1) < EPSILON:
        action = random.choice(POSSIBLE_ACTIONS)
    else:
        # Get the Q-values for the current state
        q_values = q_table[state_key]
        # Choose the action with the highest Q-value
        max_q = max(q_values.values())
        best_actions = [act for act, q in q_values.items() if q == max_q]
        action = random.choice(best_actions) # Handle ties randomly

    # Decay epsilon to reduce randomness over time
    if EPSILON > MIN_EPSILON:
        EPSILON *= EPSILON_DECAY
        
    return action

def update_q_table(q_table, last_state_key, action, reward, current_state_key):
    """Updates the Q-table using the Q-learning formula."""
    
    # Ensure the last state key exists and has a dictionary of actions.
    if last_state_key not in q_table:
        q_table[last_state_key] = {act: 0 for act in POSSIBLE_ACTIONS}

    # Ensure the current state key exists and has a dictionary of actions.
    if current_state_key not in q_table:
        q_table[current_state_key] = {act: 0 for act in POSSIBLE_ACTIONS}

    # Get old Q-value for the action taken in the last state
    old_q_value = q_table[last_state_key].get(action, 0)
    
    # Get the max Q-value for the current state (the outcome of our last action)
    next_max_q = max(q_table[current_state_key].values())
    
    # Q-learning formula
    new_q_value = old_q_value + LEARNING_RATE * (reward + DISCOUNT_FACTOR * next_max_q - old_q_value)
    
    # Update the table for the state-action pair that was just experienced
    q_table[last_state_key][action] = new_q_value


# --- Main Loop ---
if __name__ == "__main__":
    q_table = load_q_table()
    last_state_key = None
    last_action = None
    steps = 0
    
    # --- New variables for the initial sequence ---
    initial_sequence_complete = False
    start_time = time.time()
    
    print("AI Brain is running. Starting initial sequence...")
    
    while True:
        # --- Handle the initial hardcoded sequence ---
        if not initial_sequence_complete:
            elapsed_time = time.time() - start_time
            action_to_perform = "NONE"

            if elapsed_time < 2.0:
                action_to_perform = "LEFT"
            elif elapsed_time < 4.0:
                action_to_perform = "RIGHT"
            else:
                initial_sequence_complete = True
                print("Initial sequence complete. AI learning started.")
            
            write_action_to_file(action_to_perform)
            time.sleep(0.05) # Wait a bit before the next action in the sequence
            continue # Skip the learning part of the loop

        # --- Normal Learning Loop ---
        current_state, reward = read_state_from_file()
        
        if current_state:
            current_state_key = get_simplified_state(current_state)
            
            # If we have a previous state, we can learn from the last action
            if last_state_key is not None and last_action is not None:
                update_q_table(q_table, last_state_key, last_action, reward, current_state_key)

            # Choose a new action based on the current state
            action_to_perform = choose_action(current_state_key, q_table)
            
            # Send the action to the game
            write_action_to_file(action_to_perform)
            
            # Remember the current state and action for the next learning step
            last_state_key = current_state_key
            last_action = action_to_perform
            
            steps += 1
            if steps % 100 == 0:
                print(f"Step: {steps}, Epsilon: {EPSILON:.4f}, Last Reward: {reward}")
            if steps % 1000 == 0:
                print("Saving Q-table...")
                save_q_table(q_table)

        # Wait a tiny bit to prevent the loop from running too fast
        time.sleep(0.01)

