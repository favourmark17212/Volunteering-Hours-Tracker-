(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u401))
(define-constant ERR_NOT_FOUND (err u404))
(define-constant ERR_ALREADY_EXISTS (err u409))
(define-constant ERR_INVALID_INPUT (err u400))
(define-constant ERR_INSUFFICIENT_HOURS (err u402))
(define-constant ERR_GOAL_NOT_ACHIEVED (err u403))
(define-constant ERR_BADGE_ALREADY_EARNED (err u405))
(define-constant ERR_SELF_ENDORSEMENT (err u406))
(define-constant ERR_NO_SHARED_ACTIVITY (err u407))

(define-data-var next-log-id uint u1)
(define-data-var next-activity-id uint u1)
(define-data-var next-milestone-id uint u1)
(define-data-var next-badge-id uint u1)
(define-data-var next-endorsement-id uint u1)

(define-map volunteers
  principal
  {
    name: (string-ascii 50),
    email: (string-ascii 100),
    total-hours: uint,
    verified-hours: uint,
    registration-block: uint,
    is-active: bool
  }
)

(define-map activities
  uint
  {
    name: (string-ascii 100),
    organization: (string-ascii 100),
    description: (string-ascii 200),
    created-by: principal,
    is-active: bool,
    creation-block: uint
  }
)

(define-map time-logs
  uint
  {
    volunteer: principal,
    activity-id: uint,
    hours: uint,
    date: uint,
    description: (string-ascii 200),
    is-verified: bool,
    verified-by: (optional principal),
    log-block: uint
  }
)

(define-map volunteer-activity-hours
  {volunteer: principal, activity-id: uint}
  uint
)

(define-map organization-volunteers
  (string-ascii 100)
  (list 100 principal)
)

(define-map milestones
  uint
  {
    volunteer: principal,
    target-hours: uint,
    deadline: uint,
    description: (string-ascii 200),
    is-achieved: bool,
    achieved-block: (optional uint),
    creation-block: uint
  }
)

(define-map volunteer-milestones
  principal
  (list 20 uint)
)

(define-map badges
  uint
  {
    name: (string-ascii 50),
    description: (string-ascii 200),
    requirement-type: (string-ascii 20),
    requirement-value: uint,
    icon: (string-ascii 100),
    creation-block: uint
  }
)

(define-map volunteer-badges
  {volunteer: principal, badge-id: uint}
  {
    earned-block: uint,
    earned-hours: uint
  }
)

(define-map volunteer-badge-list
  principal
  (list 50 uint)
)

(define-map endorsements
  uint
  {
    endorser: principal,
    endorsed: principal,
    activity-id: uint,
    message: (string-ascii 200),
    skill-category: (string-ascii 50),
    rating: uint,
    endorsement-block: uint
  }
)

(define-map volunteer-endorsements-received
  principal
  (list 50 uint)
)

(define-map volunteer-endorsements-given
  principal
  (list 50 uint)
)

(define-map endorsement-check
  {endorser: principal, endorsed: principal, activity-id: uint}
  bool
)

(define-map activity-verifiers
  uint
  (list 50 principal)
)

(define-map activity-verifier-check
  {activity-id: uint, verifier: principal}
  bool
)

(define-read-only (get-activity-verifiers (activity-id uint))
  (default-to (list) (map-get? activity-verifiers activity-id))
)

(define-read-only (is-activity-verifier (activity-id uint) (verifier principal))
  (default-to false (map-get? activity-verifier-check {activity-id: activity-id, verifier: verifier}))
)

(define-public (add-activity-verifier (activity-id uint) (verifier principal))
  (let
    (
      (activity-info (unwrap! (map-get? activities activity-id) ERR_NOT_FOUND))
      (current (default-to (list) (map-get? activity-verifiers activity-id)))
      (already (default-to false (map-get? activity-verifier-check {activity-id: activity-id, verifier: verifier})))
    )
    (asserts! (or (is-eq tx-sender CONTRACT_OWNER)
                  (is-eq tx-sender (get created-by activity-info))) ERR_NOT_AUTHORIZED)
    (asserts! (get is-active activity-info) ERR_NOT_FOUND)
    (asserts! (not already) ERR_ALREADY_EXISTS)
    (asserts! (< (len current) u50) ERR_INVALID_INPUT)
    (map-set activity-verifiers activity-id
      (unwrap! (as-max-len? (append current verifier) u50) ERR_INVALID_INPUT))
    (map-set activity-verifier-check {activity-id: activity-id, verifier: verifier} true)
    (ok true)
  )
)

(define-read-only (get-volunteer-info (volunteer principal))
  (map-get? volunteers volunteer)
)

(define-read-only (get-activity-info (activity-id uint))
  (map-get? activities activity-id)
)

(define-read-only (get-time-log (log-id uint))
  (map-get? time-logs log-id)
)

(define-read-only (get-volunteer-total-hours (volunteer principal))
  (default-to u0 (get total-hours (map-get? volunteers volunteer)))
)

(define-read-only (get-volunteer-verified-hours (volunteer principal))
  (default-to u0 (get verified-hours (map-get? volunteers volunteer)))
)

(define-read-only (get-volunteer-activity-hours (volunteer principal) (activity-id uint))
  (default-to u0 (map-get? volunteer-activity-hours {volunteer: volunteer, activity-id: activity-id}))
)

(define-read-only (is-volunteer-registered (volunteer principal))
  (is-some (map-get? volunteers volunteer))
)

(define-read-only (is-activity-active (activity-id uint))
  (match (map-get? activities activity-id)
    activity (get is-active activity)
    false
  )
)

(define-read-only (get-milestone-info (milestone-id uint))
  (map-get? milestones milestone-id)
)

(define-read-only (get-volunteer-milestones (volunteer principal))
  (default-to (list) (map-get? volunteer-milestones volunteer))
)

(define-read-only (get-milestone-progress (milestone-id uint))
  (match (map-get? milestones milestone-id)
    milestone
    (let
      (
        (volunteer-hours (get-volunteer-verified-hours (get volunteer milestone)))
        (target-hours (get target-hours milestone))
      )
      (ok {
        current-hours: volunteer-hours,
        target-hours: target-hours,
        progress-percentage: (if (> target-hours u0) 
                               (/ (* volunteer-hours u100) target-hours) 
                               u0),
        is-achieved: (get is-achieved milestone)
      })
    )
    ERR_NOT_FOUND
  )
)

(define-read-only (is-milestone-achievable (milestone-id uint))
  (match (map-get? milestones milestone-id)
    milestone
    (let
      (
        (volunteer-hours (get-volunteer-verified-hours (get volunteer milestone)))
        (target-hours (get target-hours milestone))
      )
      (>= volunteer-hours target-hours)
    )
    false
  )
)

(define-read-only (get-badge-info (badge-id uint))
  (map-get? badges badge-id)
)

(define-read-only (get-volunteer-badges (volunteer principal))
  (default-to (list) (map-get? volunteer-badge-list volunteer))
)

(define-read-only (has-earned-badge (volunteer principal) (badge-id uint))
  (is-some (map-get? volunteer-badges {volunteer: volunteer, badge-id: badge-id}))
)

(define-read-only (get-badge-earning-details (volunteer principal) (badge-id uint))
  (map-get? volunteer-badges {volunteer: volunteer, badge-id: badge-id})
)

(define-read-only (check-badge-eligibility (volunteer principal) (badge-id uint))
  (match (map-get? badges badge-id)
    badge
    (let
      (
        (volunteer-hours (get-volunteer-verified-hours volunteer))
        (requirement-type (get requirement-type badge))
        (requirement-value (get requirement-value badge))
      )
      (and
        (not (has-earned-badge volunteer badge-id))
        (if (is-eq requirement-type "verified-hours")
          (>= volunteer-hours requirement-value)
          (if (is-eq requirement-type "total-hours") 
            (>= (get-volunteer-total-hours volunteer) requirement-value)
            false
          )
        )
      )
    )
    false
  )
)

(define-read-only (get-endorsement-info (endorsement-id uint))
  (map-get? endorsements endorsement-id)
)

(define-read-only (get-volunteer-endorsements-received (volunteer principal))
  (default-to (list) (map-get? volunteer-endorsements-received volunteer))
)

(define-read-only (get-volunteer-endorsements-given (volunteer principal))
  (default-to (list) (map-get? volunteer-endorsements-given volunteer))
)

(define-read-only (count-endorsements-received (volunteer principal))
  (len (get-volunteer-endorsements-received volunteer))
)

(define-read-only (has-endorsed (endorser principal) (endorsed principal) (activity-id uint))
  (default-to false (map-get? endorsement-check {endorser: endorser, endorsed: endorsed, activity-id: activity-id}))
)

(define-read-only (get-endorsement-rating-average (volunteer principal))
  (let
    (
      (endorsement-ids (get-volunteer-endorsements-received volunteer))
      (total-endorsements (len endorsement-ids))
    )
    (if (> total-endorsements u0)
      (ok u0)
      (ok u0)
    )
  )
)

(define-private (have-shared-activity (volunteer-a principal) (volunteer-b principal))
  (let
    (
      (volunteer-a-info (unwrap! (map-get? volunteers volunteer-a) false))
      (volunteer-b-info (unwrap! (map-get? volunteers volunteer-b) false))
    )
    (and 
      (> (get total-hours volunteer-a-info) u0)
      (> (get total-hours volunteer-b-info) u0)
    )
  )
)

(define-public (register-volunteer (name (string-ascii 50)) (email (string-ascii 100)))
  (let
    (
      (existing-volunteer (map-get? volunteers tx-sender))
    )
    (asserts! (is-none existing-volunteer) ERR_ALREADY_EXISTS)
    (asserts! (> (len name) u0) ERR_INVALID_INPUT)
    (asserts! (> (len email) u0) ERR_INVALID_INPUT)
    (map-set volunteers tx-sender
      {
        name: name,
        email: email,
        total-hours: u0,
        verified-hours: u0,
        registration-block: stacks-block-height,
        is-active: true
      }
    )
    (ok true)
  )
)

(define-public (create-activity (name (string-ascii 100)) (organization (string-ascii 100)) (description (string-ascii 200)))
  (let
    (
      (activity-id (var-get next-activity-id))
    )
    (asserts! (> (len name) u0) ERR_INVALID_INPUT)
    (asserts! (> (len organization) u0) ERR_INVALID_INPUT)
    (map-set activities activity-id
      {
        name: name,
        organization: organization,
        description: description,
        created-by: tx-sender,
        is-active: true,
        creation-block: stacks-block-height
      }
    )
    (var-set next-activity-id (+ activity-id u1))
    (ok activity-id)
  )
)

(define-public (log-hours (activity-id uint) (hours uint) (date uint) (description (string-ascii 200)))
  (let
    (
      (log-id (var-get next-log-id))
      (volunteer-info (unwrap! (map-get? volunteers tx-sender) ERR_NOT_AUTHORIZED))
      (activity-info (unwrap! (map-get? activities activity-id) ERR_NOT_FOUND))
      (current-total (get total-hours volunteer-info))
      (current-activity-hours (get-volunteer-activity-hours tx-sender activity-id))
    )
    (asserts! (get is-active volunteer-info) ERR_NOT_AUTHORIZED)
    (asserts! (get is-active activity-info) ERR_NOT_FOUND)
    (asserts! (> hours u0) ERR_INVALID_INPUT)
    (asserts! (> date u0) ERR_INVALID_INPUT)
    
    (map-set time-logs log-id
      {
        volunteer: tx-sender,
        activity-id: activity-id,
        hours: hours,
        date: date,
        description: description,
        is-verified: false,
        verified-by: none,
        log-block: stacks-block-height
      }
    )
    
    (map-set volunteers tx-sender
      (merge volunteer-info {total-hours: (+ current-total hours)})
    )
    
    (map-set volunteer-activity-hours 
      {volunteer: tx-sender, activity-id: activity-id}
      (+ current-activity-hours hours)
    )
    
    (var-set next-log-id (+ log-id u1))
    (ok log-id)
  )
)

(define-public (verify-hours (log-id uint))
  (let
    (
      (log-info (unwrap! (map-get? time-logs log-id) ERR_NOT_FOUND))
      (activity-info (unwrap! (map-get? activities (get activity-id log-info)) ERR_NOT_FOUND))
      (volunteer-info (unwrap! (map-get? volunteers (get volunteer log-info)) ERR_NOT_FOUND))
      (current-verified (get verified-hours volunteer-info))
      (hours-to-verify (get hours log-info))
    )
    (asserts! (or (is-eq tx-sender CONTRACT_OWNER)
                  (is-eq tx-sender (get created-by activity-info))
                  (is-activity-verifier (get activity-id log-info) tx-sender)) ERR_NOT_AUTHORIZED)
    (asserts! (not (get is-verified log-info)) ERR_ALREADY_EXISTS)
    
    (map-set time-logs log-id
      (merge log-info {
        is-verified: true,
        verified-by: (some tx-sender)
      })
    )
    
    (map-set volunteers (get volunteer log-info)
      (merge volunteer-info {verified-hours: (+ current-verified hours-to-verify)})
    )
    (try! (check-and-award-badges (get volunteer log-info)))
    (ok true)
  )
)

(define-public (deactivate-volunteer (volunteer principal))
  (let
    (
      (volunteer-info (unwrap! (map-get? volunteers volunteer) ERR_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (map-set volunteers volunteer
      (merge volunteer-info {is-active: false})
    )
    (ok true)
  )
)

(define-public (deactivate-activity (activity-id uint))
  (let
    (
      (activity-info (unwrap! (map-get? activities activity-id) ERR_NOT_FOUND))
    )
    (asserts! (or (is-eq tx-sender CONTRACT_OWNER)
                  (is-eq tx-sender (get created-by activity-info))) ERR_NOT_AUTHORIZED)
    (map-set activities activity-id
      (merge activity-info {is-active: false})
    )
    (ok true)
  )
)

(define-public (update-volunteer-info (name (string-ascii 50)) (email (string-ascii 100)))
  (let
    (
      (volunteer-info (unwrap! (map-get? volunteers tx-sender) ERR_NOT_FOUND))
    )
    (asserts! (> (len name) u0) ERR_INVALID_INPUT)
    (asserts! (> (len email) u0) ERR_INVALID_INPUT)
    (map-set volunteers tx-sender
      (merge volunteer-info {
        name: name,
        email: email
      })
    )
    (ok true)
  )
)

(define-read-only (get-leaderboard-by-total-hours)
  (ok "Feature not implemented in MVP")
)

(define-read-only (get-leaderboard-by-verified-hours)
  (ok "Feature not implemented in MVP")
)

(define-public (create-milestone (target-hours uint) (deadline uint) (description (string-ascii 200)))
  (let
    (
      (milestone-id (var-get next-milestone-id))
      (volunteer-info (unwrap! (map-get? volunteers tx-sender) ERR_NOT_AUTHORIZED))
      (current-milestones (get-volunteer-milestones tx-sender))
    )
    (asserts! (get is-active volunteer-info) ERR_NOT_AUTHORIZED)
    (asserts! (> target-hours u0) ERR_INVALID_INPUT)
    (asserts! (> deadline stacks-block-height) ERR_INVALID_INPUT)
    (asserts! (< (len current-milestones) u20) ERR_INVALID_INPUT)
    
    (map-set milestones milestone-id
      {
        volunteer: tx-sender,
        target-hours: target-hours,
        deadline: deadline,
        description: description,
        is-achieved: false,
        achieved-block: none,
        creation-block: stacks-block-height
      }
    )
    
    (map-set volunteer-milestones tx-sender
      (unwrap! (as-max-len? (append current-milestones milestone-id) u20) ERR_INVALID_INPUT)
    )
    
    (var-set next-milestone-id (+ milestone-id u1))
    (ok milestone-id)
  )
)

(define-public (achieve-milestone (milestone-id uint))
  (let
    (
      (milestone-info (unwrap! (map-get? milestones milestone-id) ERR_NOT_FOUND))
      (volunteer-hours (get-volunteer-verified-hours (get volunteer milestone-info)))
      (target-hours (get target-hours milestone-info))
    )
    (asserts! (is-eq tx-sender (get volunteer milestone-info)) ERR_NOT_AUTHORIZED)
    (asserts! (not (get is-achieved milestone-info)) ERR_ALREADY_EXISTS)
    (asserts! (>= volunteer-hours target-hours) ERR_GOAL_NOT_ACHIEVED)
    
    (map-set milestones milestone-id
      (merge milestone-info {
        is-achieved: true,
        achieved-block: (some stacks-block-height)
      })
    )
    (ok true)
  )
)

(define-public (create-badge (name (string-ascii 50)) (description (string-ascii 200)) (requirement-type (string-ascii 20)) (requirement-value uint) (icon (string-ascii 100)))
  (let
    (
      (badge-id (var-get next-badge-id))
    )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (asserts! (> (len name) u0) ERR_INVALID_INPUT)
    (asserts! (> requirement-value u0) ERR_INVALID_INPUT)
    (asserts! (or (is-eq requirement-type "verified-hours") (is-eq requirement-type "total-hours")) ERR_INVALID_INPUT)
    
    (map-set badges badge-id
      {
        name: name,
        description: description,
        requirement-type: requirement-type,
        requirement-value: requirement-value,
        icon: icon,
        creation-block: stacks-block-height
      }
    )
    
    (var-set next-badge-id (+ badge-id u1))
    (ok badge-id)
  )
)

(define-private (award-badge (volunteer principal) (badge-id uint))
  (let
    (
      (current-badges (get-volunteer-badges volunteer))
      (volunteer-hours (get-volunteer-verified-hours volunteer))
    )
    (asserts! (not (has-earned-badge volunteer badge-id)) ERR_BADGE_ALREADY_EARNED)
    (asserts! (< (len current-badges) u50) ERR_INVALID_INPUT)
    
    (map-set volunteer-badges 
      {volunteer: volunteer, badge-id: badge-id}
      {
        earned-block: stacks-block-height,
        earned-hours: volunteer-hours
      }
    )
    
    (map-set volunteer-badge-list volunteer
      (unwrap! (as-max-len? (append current-badges badge-id) u50) ERR_INVALID_INPUT)
    )
    (ok true)
  )
)

(define-private (check-and-award-badges (volunteer principal))
  (let
    (
      (badge-1-eligible (check-badge-eligibility volunteer u1))
      (badge-2-eligible (check-badge-eligibility volunteer u2))
      (badge-3-eligible (check-badge-eligibility volunteer u3))
      (badge-4-eligible (check-badge-eligibility volunteer u4))
      (badge-5-eligible (check-badge-eligibility volunteer u5))
    )
    (if badge-1-eligible (try! (award-badge volunteer u1)) true)
    (if badge-2-eligible (try! (award-badge volunteer u2)) true)
    (if badge-3-eligible (try! (award-badge volunteer u3)) true)
    (if badge-4-eligible (try! (award-badge volunteer u4)) true)
    (if badge-5-eligible (try! (award-badge volunteer u5)) true)
    (ok true)
  )
)

(define-public (initialize-default-badges)
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (try! (create-badge "First Steps" "Earned your first verified hour" "verified-hours" u1 "star"))
    (try! (create-badge "Helper" "Reached 10 verified hours" "verified-hours" u10 "handshake"))
    (try! (create-badge "Contributor" "Reached 50 verified hours" "verified-hours" u50 "muscle"))
    (try! (create-badge "Champion" "Reached 100 verified hours" "verified-hours" u100 "trophy"))
    (try! (create-badge "Hero" "Reached 500 verified hours" "verified-hours" u500 "superhero"))
    (ok true)
  )
)

(define-public (endorse-volunteer (endorsed principal) (activity-id uint) (message (string-ascii 200)) (skill-category (string-ascii 50)) (rating uint))
  (let
    (
      (endorsement-id (var-get next-endorsement-id))
      (endorser-info (unwrap! (map-get? volunteers tx-sender) ERR_NOT_AUTHORIZED))
      (endorsed-info (unwrap! (map-get? volunteers endorsed) ERR_NOT_FOUND))
      (activity-info (unwrap! (map-get? activities activity-id) ERR_NOT_FOUND))
      (endorser-received (get-volunteer-endorsements-received endorsed))
      (endorser-given (get-volunteer-endorsements-given tx-sender))
      (endorser-activity-hours (get-volunteer-activity-hours tx-sender activity-id))
      (endorsed-activity-hours (get-volunteer-activity-hours endorsed activity-id))
    )
    (asserts! (not (is-eq tx-sender endorsed)) ERR_SELF_ENDORSEMENT)
    (asserts! (get is-active endorser-info) ERR_NOT_AUTHORIZED)
    (asserts! (get is-active endorsed-info) ERR_NOT_FOUND)
    (asserts! (> endorser-activity-hours u0) ERR_NO_SHARED_ACTIVITY)
    (asserts! (> endorsed-activity-hours u0) ERR_NO_SHARED_ACTIVITY)
    (asserts! (not (has-endorsed tx-sender endorsed activity-id)) ERR_ALREADY_EXISTS)
    (asserts! (and (>= rating u1) (<= rating u5)) ERR_INVALID_INPUT)
    (asserts! (> (len skill-category) u0) ERR_INVALID_INPUT)
    (asserts! (< (len endorser-received) u50) ERR_INVALID_INPUT)
    (asserts! (< (len endorser-given) u50) ERR_INVALID_INPUT)
    
    (map-set endorsements endorsement-id
      {
        endorser: tx-sender,
        endorsed: endorsed,
        activity-id: activity-id,
        message: message,
        skill-category: skill-category,
        rating: rating,
        endorsement-block: stacks-block-height
      }
    )
    
    (map-set volunteer-endorsements-received endorsed
      (unwrap! (as-max-len? (append endorser-received endorsement-id) u50) ERR_INVALID_INPUT)
    )
    
    (map-set volunteer-endorsements-given tx-sender
      (unwrap! (as-max-len? (append endorser-given endorsement-id) u50) ERR_INVALID_INPUT)
    )
    
    (map-set endorsement-check 
      {endorser: tx-sender, endorsed: endorsed, activity-id: activity-id}
      true
    )
    
    (var-set next-endorsement-id (+ endorsement-id u1))
    (ok endorsement-id)
  )
)

(define-read-only (get-volunteer-summary (volunteer principal))
  (match (map-get? volunteers volunteer)
    info
    (let
      (
        (badge-list (default-to (list) (map-get? volunteer-badge-list volunteer)))
        (received (default-to (list) (map-get? volunteer-endorsements-received volunteer)))
        (given (default-to (list) (map-get? volunteer-endorsements-given volunteer)))
      )
      (ok {
        name: (get name info),
        email: (get email info),
        total-hours: (get total-hours info),
        verified-hours: (get verified-hours info),
        registration-block: (get registration-block info),
        is-active: (get is-active info),
        badges-count: (len badge-list),
        endorsements-received-count: (len received),
        endorsements-given-count: (len given)
      })
    )
    ERR_NOT_FOUND
  )
)

(define-read-only (get-organization-stats (organization (string-ascii 100)))
  (ok "Feature not implemented in MVP")
)
