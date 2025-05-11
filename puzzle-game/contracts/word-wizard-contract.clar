;; Word Wizards Smart Contract - Stage 1 (MVP)
;; This contract manages a basic word puzzle game

;; Error codes
(define-constant ERR-UNAUTHORIZED (err u100))
(define-constant ERR-PUZZLE-NOT-FOUND (err u101))
(define-constant ERR-ALREADY-SOLVED (err u102))
(define-constant ERR-INVALID-SOLUTION (err u106))
(define-constant ERR-NOT-ACTIVE (err u107))

;; Data maps
(define-map daily-puzzles
  { day-id: uint }
  {
    word: (string-ascii 20),
    hint: (string-ascii 100),
    creator: principal,
    active: bool
  }
)

(define-map player-solutions
  { day-id: uint, player: principal }
  {
    solution: (string-ascii 20),
    correct: bool,
    submitted-at: uint
  }
)

(define-map player-stats
  { player: principal }
  {
    puzzles-attempted: uint,
    puzzles-solved: uint
  }
)

;; Variables
(define-data-var day-counter uint u0)
(define-data-var game-admin principal tx-sender)

;; Access control
(define-private (is-admin)
  (is-eq tx-sender (var-get game-admin))
)

;; Set admin
(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-admin) ERR-UNAUTHORIZED)
    (ok (var-set game-admin new-admin))
  )
)

;; Create a new daily puzzle
(define-public (create-puzzle (word (string-ascii 20)) (hint (string-ascii 100)))
  (let (
    (day-id (+ (var-get day-counter) u1))
  )
    (asserts! (is-admin) ERR-UNAUTHORIZED)
    (asserts! (> (len word) u0) ERR-INVALID-SOLUTION)
    (asserts! (> (len hint) u0) ERR-INVALID-SOLUTION)
    
    (map-set daily-puzzles
      { day-id: day-id }
      {
        word: word,
        hint: hint,
        creator: tx-sender,
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
    (player-data (default-to { puzzles-attempted: u0, puzzles-solved: u0 } 
                           (map-get? player-stats { player: tx-sender })))
  )
    (asserts! (get active puzzle) ERR-NOT-ACTIVE)
    (asserts! (is-none (map-get? player-solutions { day-id: day-id, player: tx-sender })) ERR-ALREADY-SOLVED)
    
    ;; Check if solution is correct
    (let (
      (is-correct (is-eq solution (get word puzzle)))
    )
      ;; Record solution
      (map-set player-solutions
        { day-id: day-id, player: tx-sender }
        {
          solution: solution,
          correct: is-correct,
          submitted-at: block-height
        }
      )
      
      ;; Update player stats
      (map-set player-stats
        { player: tx-sender }
        {
          puzzles-attempted: (+ (get puzzles-attempted player-data) u1),
          puzzles-solved: (+ (get puzzles-solved player-data) (if is-correct u1 u0))
        }
      )
      
      (ok is-correct)
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

;; Get player's solution status for a specific puzzle
(define-read-only (get-player-solution (day-id uint) (player principal))
  (map-get? player-solutions { day-id: day-id, player: player })
)

;; Get player stats
(define-read-only (get-player-stats (player principal))
  (default-to 
    { puzzles-attempted: u0, puzzles-solved: u0 }
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

;; Initialize contract
(begin
  (var-set game-admin tx-sender)
)