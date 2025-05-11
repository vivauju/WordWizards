# 🧙‍♂️ Word Wizards Smart Contract

**Word Wizards** is a Clarity smart contract built on the Stacks blockchain. It powers a decentralized word puzzle game with daily challenges, player submissions, performance tracking, and prize rewards.

## 🧩 Features

* **Daily Word Puzzles** with varying difficulty levels (`Easy`, `Medium`, `Hard`)
* **Player Submissions** with scoring based on time, difficulty, and correctness
* **Leaderboard Logic** (simplified in this version)
* **STX-based Entry Fees and Prize Pools**
* **Player Stats Tracking**
* **Admin Controls** to pause the game or update puzzle settings
* **Prize Claiming** with fair reward distribution and platform fee handling

---

## 📦 Contract Structure

### 🔐 Admin & Control

* `set-admin(new-admin)` — Transfer contract admin rights
* `set-pause(pause-state)` — Pause/unpause the game

### 🧠 Game Mechanics

* `create-puzzle(word, hint, difficulty, entry-fee)` — Admin adds a new daily puzzle
* `submit-solution(day-id, solution)` — Players submit answers and are scored
* `end-puzzle(day-id)` — Admin closes puzzle submissions

### 💰 Rewards & Claims

* `calculate-prize(day-id, player)` — Estimate prize for a player
* `claim-prize(day-id)` — Players claim STX prize if eligible

### 📊 Read-Only Functions

* `get-player-score(day-id, player)` — Get player’s score for a puzzle
* `get-top-score(day-id)` — (Stub) Top score logic placeholder
* `get-winning-player(day-id)` — (Stub) Fixed winner placeholder
* `get-player-stats(player)` — Stats for a given player
* `get-puzzle(day-id)` — Retrieve puzzle details
* `get-current-day()` — Track the current puzzle day

---

## 📁 Data Structures

### 🗺 Maps

* `daily-puzzles` — Puzzle metadata (word, hint, difficulty, etc.)
* `player-solutions` — Each player’s submitted solution, correctness, and time
* `player-stats` — Aggregated stats per player
* `prize-claims` — Record of claimed prizes per puzzle per player

### 🧮 Constants

* Difficulty: `DIFFICULTY-EASY`, `MEDIUM`, `HARD`
* Errors: Range from `ERR-UNAUTHORIZED` to `ERR-SYSTEM-PAUSED`
* Platform fee: `10%` deducted from the prize pool

---

## ⚙️ Score Calculation

Score is computed only if the solution is correct:

```
Score = 100 + (1000 / (timeTaken + 1)) + (50 × difficultyMultiplier)
```

---

## 🚫 Limitations (To Be Improved)

* `get-top-score` and `get-winning-player` are stubbed and not dynamic
* `to-lowercase` is a placeholder and doesn’t implement actual case conversion
* No support for off-chain puzzle generation or zero-knowledge validation (yet!)

---

## 🔐 Deployment & Admin Notes

* Only the contract deployer becomes the initial admin.
* Ensure admin actions (e.g., puzzle creation or ending) are protected using `(is-admin)` checks.
* The contract must not be paused (`paused = false`) for normal gameplay.
