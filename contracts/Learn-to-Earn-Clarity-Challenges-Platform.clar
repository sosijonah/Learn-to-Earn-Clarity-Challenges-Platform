(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-CHALLENGE-EXISTS (err u101))
(define-constant ERR-CHALLENGE-NOT-FOUND (err u102))
(define-constant ERR-INVALID-SUBMISSION (err u103))
(define-constant ERR-ALREADY-SUBMITTED (err u104))
(define-constant ERR-INSUFFICIENT-FUNDS (err u105))
(define-constant ERR-NOT-REVIEWER (err u106))
(define-constant ERR-INSUFFICIENT-REPUTATION (err u107))
(define-constant ERR-HINT-NOT-FOUND (err u108))
(define-constant ERR-MAX-HINTS-REACHED (err u109))

(define-data-var contract-owner principal tx-sender)
(define-data-var total-challenges uint u0)
(define-data-var total-submissions uint u0)
(define-data-var platform-fee uint u1000) ;; 10% in basis points
(define-data-var leaderboard-size uint u0)
(define-data-var hint-cost uint u10)

(define-map challenges
    uint 
    {
        title: (string-ascii 100),
        description: (string-ascii 500),
        difficulty: uint,
        reward: uint,
        creator: principal,
        active: bool,
        submissions-count: uint
    }
)

(define-map challenge-submissions
    { challenge-id: uint, user: principal }
    {
        submission-code: (string-ascii 1000),
        status: (string-ascii 20),
        reviewer: (optional principal),
        timestamp: uint
    }
)

(define-map user-profiles
    principal
    {
        challenges-completed: uint,
        total-rewards: uint,
        reputation-score: uint,
        is-reviewer: bool
    }
)

(define-map challenge-reviewers
    principal 
    bool
)

(define-map leaderboard-by-rewards
    uint
    principal
)

(define-map leaderboard-by-challenges
    uint
    principal
)

(define-map challenge-hints
    { challenge-id: uint, hint-level: uint }
    {
        hint-text: (string-ascii 300),
        reputation-cost: uint
    }
)

(define-map user-hint-purchases
    { challenge-id: uint, user: principal }
    {
        hints-purchased: uint,
        total-reputation-spent: uint
    }
)

(define-public (initialize-contract)
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
        (map-set user-profiles tx-sender {
            challenges-completed: u0,
            total-rewards: u0,
            reputation-score: u100,
            is-reviewer: true
        })
        (map-set challenge-reviewers tx-sender true)
        (ok true)
    )
)

(define-public (create-challenge (title (string-ascii 100)) (description (string-ascii 500)) (difficulty uint) (reward uint))
    (let (
        (challenge-id (+ (var-get total-challenges) u1))
    )
        (asserts! (>= (stx-get-balance tx-sender) reward) ERR-INSUFFICIENT-FUNDS)
        (try! (stx-transfer? reward tx-sender (as-contract tx-sender)))
        
        (map-set challenges challenge-id {
            title: title,
            description: description,
            difficulty: difficulty,
            reward: reward,
            creator: tx-sender,
            active: true,
            submissions-count: u0
        })
        
        (var-set total-challenges challenge-id)
        (ok challenge-id)
    )
)

(define-public (submit-challenge (challenge-id uint) (submission-code (string-ascii 1000)))
    (let (
        (challenge (unwrap! (map-get? challenges challenge-id) ERR-CHALLENGE-NOT-FOUND))
        (submission-key { challenge-id: challenge-id, user: tx-sender })
    )
        (asserts! (get active challenge) ERR-CHALLENGE-NOT-FOUND)
        (asserts! (is-none (map-get? challenge-submissions submission-key)) ERR-ALREADY-SUBMITTED)
        
        (map-set challenge-submissions submission-key {
            submission-code: submission-code,
            status: "pending",
            reviewer: none,
            timestamp: stacks-block-height
        })
        
        (map-set challenges challenge-id 
            (merge challenge { submissions-count: (+ (get submissions-count challenge) u1) })
        )
        
        (var-set total-submissions (+ (var-get total-submissions) u1))
        (ok true)
    )
)

(define-public (review-submission (challenge-id uint) (submitter principal) (approved bool))
    (let (
        (submission-key { challenge-id: challenge-id, user: submitter })
        (submission (unwrap! (map-get? challenge-submissions submission-key) ERR-INVALID-SUBMISSION))
        (challenge (unwrap! (map-get? challenges challenge-id) ERR-CHALLENGE-NOT-FOUND))
        (user-profile (default-to 
            { challenges-completed: u0, total-rewards: u0, reputation-score: u0, is-reviewer: false }
            (map-get? user-profiles submitter)
        ))
    )
        (asserts! (is-some (map-get? challenge-reviewers tx-sender)) ERR-NOT-REVIEWER)
        
        (if approved
            (begin
                (try! (as-contract (stx-transfer? (get reward challenge) tx-sender submitter)))
                (map-set user-profiles submitter 
                    (merge user-profile {
                        challenges-completed: (+ (get challenges-completed user-profile) u1),
                        total-rewards: (+ (get total-rewards user-profile) (get reward challenge)),
                        reputation-score: (+ (get reputation-score user-profile) (get difficulty challenge))
                    })
                )
                (update-leaderboards submitter 
                    (+ (get total-rewards user-profile) (get reward challenge))
                    (+ (get challenges-completed user-profile) u1)
                )
                (map-set challenge-submissions submission-key
                    (merge submission {
                        status: "approved",
                        reviewer: (some tx-sender)
                    })
                )
            )
            (map-set challenge-submissions submission-key
                (merge submission {
                    status: "rejected",
                    reviewer: (some tx-sender)
                })
            )
        )
        (ok true)
    )
)

(define-public (add-reviewer (new-reviewer principal))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
        (map-set challenge-reviewers new-reviewer true)
        (map-set user-profiles new-reviewer {
            challenges-completed: u0,
            total-rewards: u0,
            reputation-score: u50,
            is-reviewer: true
        })
        (ok true)
    )
)

(define-public (create-hint (challenge-id uint) (hint-level uint) (hint-text (string-ascii 300)) (reputation-cost uint))
    (let (
        (challenge (unwrap! (map-get? challenges challenge-id) ERR-CHALLENGE-NOT-FOUND))
        (hint-key { challenge-id: challenge-id, hint-level: hint-level })
    )
        (asserts! (is-eq tx-sender (get creator challenge)) ERR-NOT-AUTHORIZED)
        (asserts! (get active challenge) ERR-CHALLENGE-NOT-FOUND)
        (asserts! (is-none (map-get? challenge-hints hint-key)) ERR-CHALLENGE-EXISTS)
        
        (map-set challenge-hints hint-key {
            hint-text: hint-text,
            reputation-cost: reputation-cost
        })
        (ok true)
    )
)

(define-public (purchase-hint (challenge-id uint) (hint-level uint))
    (let (
        (challenge (unwrap! (map-get? challenges challenge-id) ERR-CHALLENGE-NOT-FOUND))
        (hint-key { challenge-id: challenge-id, hint-level: hint-level })
        (hint (unwrap! (map-get? challenge-hints hint-key) ERR-HINT-NOT-FOUND))
        (user-profile (unwrap! (map-get? user-profiles tx-sender) ERR-INVALID-SUBMISSION))
        (purchase-key { challenge-id: challenge-id, user: tx-sender })
        (user-purchases (default-to 
            { hints-purchased: u0, total-reputation-spent: u0 }
            (map-get? user-hint-purchases purchase-key)
        ))
        (required-reputation (get reputation-cost hint))
    )
        (asserts! (get active challenge) ERR-CHALLENGE-NOT-FOUND)
        (asserts! (>= (get reputation-score user-profile) required-reputation) ERR-INSUFFICIENT-REPUTATION)
        (asserts! (is-eq hint-level (+ (get hints-purchased user-purchases) u1)) ERR-HINT-NOT-FOUND)
        (asserts! (<= hint-level u5) ERR-MAX-HINTS-REACHED)
        
        (map-set user-profiles tx-sender 
            (merge user-profile {
                reputation-score: (- (get reputation-score user-profile) required-reputation)
            })
        )
        
        (map-set user-hint-purchases purchase-key {
            hints-purchased: (+ (get hints-purchased user-purchases) u1),
            total-reputation-spent: (+ (get total-reputation-spent user-purchases) required-reputation)
        })
        
        (ok (get hint-text hint))
    )
)

(define-read-only (get-challenge (challenge-id uint))
    (ok (map-get? challenges challenge-id))
)

(define-read-only (get-user-profile (user principal))
    (ok (map-get? user-profiles user))
)

(define-read-only (get-submission (challenge-id uint) (user principal))
    (ok (map-get? challenge-submissions { challenge-id: challenge-id, user: user }))
)

(define-read-only (get-platform-stats)
    (ok {
        total-challenges: (var-get total-challenges),
        total-submissions: (var-get total-submissions),
        leaderboard-size: (var-get leaderboard-size)
    })
)

(define-read-only (get-hint (challenge-id uint) (hint-level uint))
    (ok (map-get? challenge-hints { challenge-id: challenge-id, hint-level: hint-level }))
)

(define-read-only (get-user-hint-purchases (challenge-id uint) (user principal))
    (ok (map-get? user-hint-purchases { challenge-id: challenge-id, user: user }))
)

(define-read-only (get-available-hint-level (challenge-id uint) (user principal))
    (let (
        (user-purchases (default-to 
            { hints-purchased: u0, total-reputation-spent: u0 }
            (map-get? user-hint-purchases { challenge-id: challenge-id, user: user })
        ))
    )
        (ok (+ (get hints-purchased user-purchases) u1))
    )
)

(define-private (update-leaderboards (user principal) (total-rewards uint) (challenges-completed uint))
    (let (
        (current-size (var-get leaderboard-size))
    )
        (map-set leaderboard-by-rewards current-size user)
        (map-set leaderboard-by-challenges current-size user)
        (var-set leaderboard-size (+ current-size u1))
        true
    )
)

(define-read-only (get-top-earners (start uint) (limit uint))
    (let (
        (end (+ start limit))
        (max-size (var-get leaderboard-size))
    )
        (ok (fold get-leaderboard-entry (list start) (list)))
    )
)

(define-read-only (get-top-solvers (start uint) (limit uint))
    (let (
        (end (+ start limit))
        (max-size (var-get leaderboard-size))
    )
        (ok (fold get-leaderboard-entry (list start) (list)))
    )
)

(define-private (get-leaderboard-entry (index uint) (acc (list 50 principal)))
    (match (map-get? leaderboard-by-rewards index)
        user (unwrap-panic (as-max-len? (append acc user) u50))
        acc
    )
)
