;; Word Wizards Smart Contract
;; This contract manages a word puzzle game with daily challenges and leaderboards

;; Error codes
(define-constant ERR-UNAUTHORIZED (err u100))
(define-constant ERR-PUZZLE-NOT-FOUND (err u101))
(define-constant ERR-ALREADY-SOLVED (err u102))
(define-constant ERR-CHALLENGE-EXPIRED (err u103))
(define-constant ERR-SOLUTION-NOT-FOUND (err u104))
(define-constant ERR-ALREADY-SUBMITTED (err u105))
(define-constant ERR-INVALID-SOLUTION (err u106))
(define-constant ERR-NOT-ACTIVE (err u107))
(define-constant ERR-INVALID-PLAYER (err u108))
(define-constant ERR-INSUFFICIENT-BALANCE (err u109))
(define-constant ERR-PRIZE-CLAIMED (err u110))
(define-constant ERR-NOT-WINNER (err u111))
(define-constant ERR-NOT-AVAILABLE (err u112))
(define-constant ERR-SYSTEM-PAUSED (err u113))

;; Puzzle difficulty levels
(define-constant DIFFICULTY-EASY u1)
(define-constant DIFFICULTY-MEDIUM u2)
(define-constant DIFFICULTY-HARD u3)

;; Data maps
(define-map daily-puzzles
  { day-id: uint }
  {
    word: (string-ascii 20),
    hint: (string-ascii 100),
    difficulty: uint,
    creator: principal,
    entry-fee: uint,
    prize-pool: uint,
    solved-count: uint,
    active: bool
  }
)

(define-map player-solutions
  { day-id: uint, player: principal }
  {
    solution: (string-ascii 20),
    time-taken: uint,
    correct: bool,
    score: uint,
    submitted-at: uint
  }
)

(define-map player-stats
  { player: principal }
  {
    puzzles-attempted: uint,
    puzzles-solved: uint,
    total-score: uint,
    easy-solved: uint,
    medium-solved: uint,
    hard-solved: uint
  }
)

(define-map prize-claims
  { day-id: uint, player: principal }
  { claimed: bool, amount: uint }
)

;; Variables
(define-data-var day-counter uint u0)
(define-data-var game-admin principal tx-sender)
(define-data-var paused bool false)
(define-data-var platform-fee-percent uint u10) ;; 10% platform fee

;; Access control
(define-private (is-admin)
  (is-eq tx-sender (var-get game-admin))
)

;; Check if system is active
(define-private (is-active)
  (not (var-get paused))
)

;; Set admin
(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-admin) ERR-UNAUTHORIZED)
    (ok (var-set game-admin new-admin))
  )
)

;; Set pause state
(define-public (set-pause (pause-state bool))
  (begin
    (asserts! (is-admin) ERR-UNAUTHORIZED)
    (ok (var-set paused pause-state))
  )
)

;; Create a new daily puzzle
(define-public (create-puzzle (word (string-ascii 20)) (hint (string-ascii 100)) (difficulty uint) (entry-fee uint))
  (let (
    (day-id (+ (var-get day-counter) u1))
  )
    (asserts! (is-admin) ERR-UNAUTHORIZED)
    (asserts! (is-active) ERR-SYSTEM-PAUSED)
    (asserts! (> (len word) u0) ERR-INVALID-SOLUTION)
    (asserts! (> (len hint) u0) ERR-INVALID-SOLUTION)
    (asserts! (and (>= difficulty DIFFICULTY-EASY) (<= difficulty DIFFICULTY-HARD)) ERR-INVALID-SOLUTION)
    
    (map-set daily-puzzles
      { day-id: day-id }
      {
        word: word,
        hint: hint,
        difficulty: difficulty,
        creator: tx-sender,
        entry-fee: entry-fee,
        prize-pool: u0,
        solved-count: u0,
        active: true
      }
    )
    
    (var-set day-counter day-id)
    (ok day-id)
  )
)

;; Submit a solution to a puzzle
(define-public (submit-solution (day-id uint) (solution (string-ascii 20)))
  (let (
    (puzzle (unwrap! (map-get? daily-puzzles { day-id: day-id }) ERR-PUZZLE-NOT-FOUND))
    (player-data (default-to { puzzles-attempted: u0, puzzles-solved: u0, total-score: u0, easy-solved: u0, medium-solved: u0, hard-solved: u0 } 
                           (map-get? player-stats { player: tx-sender })))
    (start-time (default-to block-height (get submitted-at (map-get? player-solutions { day-id: day-id, player: tx-sender }))))
  )
    (asserts! (is-active) ERR-SYSTEM-PAUSED)
    (asserts! (get active puzzle) ERR-CHALLENGE-EXPIRED)
    (asserts! (is-none (map-get? player-solutions { day-id: day-id, player: tx-sender })) ERR-ALREADY-SUBMITTED)
    
    ;; Handle entry fee if required
    (if (> (get entry-fee puzzle) u0)
      (begin
        ;; Transfer fee to contract - requires STX
        (unwrap! (stx-transfer? (get entry-fee puzzle) tx-sender (as-contract tx-sender)) ERR-INSUFFICIENT-BALANCE)
        
        ;; Update prize pool
        (map-set daily-puzzles
          { day-id: day-id }
          (merge puzzle {
            prize-pool: (+ (get prize-pool puzzle) (get entry-fee puzzle))
          })
        )
      )
      true
    )
    
    ;; Check if solution is correct
    (let (
      (is-correct (is-eq (to-lowercase solution) (to-lowercase (get word puzzle))))
      (time-taken (- block-height start-time))
      (difficulty-multiplier (get difficulty puzzle))
      ;; Calculate score - correct answer + time bonus + difficulty bonus
      (score (if is-correct
               (+ u100 (/ u1000 (+ time-taken u1)) (* u50 difficulty-multiplier))
               u0))
    )
      ;; Record solution
      (map-set player-solutions
        { day-id: day-id, player: tx-sender }
        {
          solution: solution,
          time-taken: time-taken,
          correct: is-correct,
          score: score,
          submitted-at: block-height
        }
      )
      
      ;; Update player stats
      (map-set player-stats
        { player: tx-sender }
        {
          puzzles-attempted: (+ (get puzzles-attempted player-data) u1),
          puzzles-solved: (+ (get puzzles-solved player-data) (if is-correct u1 u0)),
          total-score: (+ (get total-score player-data) score),
          easy-solved: (+ (get easy-solved player-data) 
                        (if (and is-correct (is-eq (get difficulty puzzle) DIFFICULTY-EASY)) u1 u0)),
          medium-solved: (+ (get medium-solved player-data) 
                          (if (and is-correct (is-eq (get difficulty puzzle) DIFFICULTY-MEDIUM)) u1 u0)),
          hard-solved: (+ (get hard-solved player-data) 
                        (if (and is-correct (is-eq (get difficulty puzzle) DIFFICULTY-HARD)) u1 u0))
        }
      )
      
      ;; Update puzzle solved count if correct
      (if is-correct
        (map-set daily-puzzles
          { day-id: day-id }
          (merge puzzle {
            solved-count: (+ (get solved-count puzzle) u1)
          })
        )
        true
      )
      
      (ok score)
    )
  )
)

;; End a daily puzzle challenge
(define-public (end-puzzle (day-id uint))
  (let (
    (puzzle (unwrap! (map-get? daily-puzzles { day-id: day-id }) ERR-PUZZLE-NOT-FOUND))
  )
    (asserts! (is-admin) ERR-UNAUTHORIZED)
    (asserts! (get active puzzle) ERR-NOT-ACTIVE)
    
    (map-set daily-puzzles
      { day-id: day-id }
      (merge puzzle {
        active: false
      })
    )
    
    (ok true)
  )
)

;; Get player's score for a specific puzzle
(define-read-only (get-player-score (day-id uint) (player principal))
  (match (map-get? player-solutions { day-id: day-id, player: player })
    solution (get score solution)
    u0
  )
)

;; Get the top score for a puzzle
(define-read-only (get-top-score (day-id uint))
  ;; This is simplified. In a real contract, you'd need to track top scores
  (default-to u0 (get-top-score-internal day-id))
)

;; Simulated function to get top score (would be more complex in reality)
(define-private (get-top-score-internal (day-id uint))
  ;; In a real implementation, this would query a sorted list of scores
  ;; This is a placeholder
  (some u500)
)

;; Get winning player for a puzzle (simplified)
(define-read-only (get-winning-player (day-id uint))
  ;; This is simplified. In a real contract, you'd need to track the winning player
  (some 'SP2PABAF9FTAJYNFZH93XENAJ8FVY99RRM50D2JG9)
)

;; Calculate prize for a player
(define-read-only (calculate-prize (day-id uint) (player principal))
  (let (
    (puzzle (unwrap! (map-get? daily-puzzles { day-id: day-id }) ERR-PUZZLE-NOT-FOUND))
    (player-solution (unwrap! (map-get? player-solutions { day-id: day-id, player: player }) ERR-SOLUTION-NOT-FOUND))
    (prize-pool (get prize-pool puzzle))
  )
    (asserts! (not (get active puzzle)) ERR-NOT-AVAILABLE)
    (asserts! (get correct player-solution) ERR-NOT-WINNER)
    
    ;; Prize distribution logic - simplified for clarity
    ;; In reality, would use a more complex distribution based on rank
    (let (
      (platform-fee (/ (* prize-pool (var-get platform-fee-percent)) u100))
      (distributable-pool (- prize-pool platform-fee))
      (winner (unwrap! (get-winning-player day-id) ERR-NOT-WINNER))
    )
      (if (is-eq player winner)
        ;; Winner gets 50% of pool
        (ok (/ distributable-pool u2))
        ;; Other correct answers split the remaining 50%
        (ok (/ (/ distributable-pool u2) (get solved-count puzzle)))
      )
    )
  )
)

;; Claim prize
(define-public (claim-prize (day-id uint))
  (let (
    (puzzle (unwrap! (map-get? daily-puzzles { day-id: day-id }) ERR-PUZZLE-NOT-FOUND))
    (player-solution (unwrap! (map-get? player-solutions { day-id: day-id, player: tx-sender }) ERR-SOLUTION-NOT-FOUND))
    (prize-claim (default-to { claimed: false, amount: u0 } (map-get? prize-claims { day-id: day-id, player: tx-sender })))
    (prize-amount (unwrap! (calculate-prize day-id tx-sender) ERR-NOT-WINNER))
  )
    (asserts! (is-active) ERR-SYSTEM-PAUSED)
    (asserts! (not (get active puzzle)) ERR-NOT-AVAILABLE)
    (asserts! (not (get claimed prize-claim)) ERR-PRIZE-CLAIMED)
    (asserts! (> prize-amount u0) ERR-NOT-WINNER)
    
    ;; Mark prize as claimed
    (map-set prize-claims
      { day-id: day-id, player: tx-sender }
      { claimed: true, amount: prize-amount }
    )
    
    ;; Transfer prize to player
    (unwrap! (as-contract (stx-transfer? prize-amount (as-contract tx-sender) tx-sender)) ERR-INSUFFICIENT-BALANCE)
    
    (ok prize-amount)
  )
)

;; Get player stats
(define-read-only (get-player-stats (player principal))
  (default-to 
    { puzzles-attempted: u0, puzzles-solved: u0, total-score: u0, easy-solved: u0, medium-solved: u0, hard-solved: u0 }
    (map-get? player-stats { player: player })
  )
)

;; Get puzzle details
(define-read-only (get-puzzle (day-id uint))
  (map-get? daily-puzzles { day-id: day-id })
)

;; Get current day
(define-read-only (get-current-day)
  (var-get day-counter)
)

;; Helper function to convert string to lowercase (simplified)
(define-private (to-lowercase (s (string-ascii 20)))
  ;; In a real contract, this would do actual case conversion
  ;; This is just a placeholder that returns the original string
  s
)

;; Initialize contract
(begin
  (var-set game-admin tx-sender)
  (var-set paused false)
)