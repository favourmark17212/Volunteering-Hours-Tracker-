(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u401))
(define-constant ERR_NOT_FOUND (err u404))
(define-constant ERR_ALREADY_EXISTS (err u409))
(define-constant ERR_INVALID_INPUT (err u400))
(define-constant ERR_INSUFFICIENT_HOURS (err u402))

(define-data-var next-log-id uint u1)
(define-data-var next-activity-id uint u1)

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
                  (is-eq tx-sender (get created-by activity-info))) ERR_NOT_AUTHORIZED)
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

(define-read-only (get-organization-stats (organization (string-ascii 100)))
  (ok "Feature not implemented in MVP")
)
