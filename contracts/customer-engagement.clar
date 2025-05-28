;; Customer Engagement Contract
;; Promotes circular consumption and rewards sustainable behavior

(define-constant err-insufficient-points (err u500))
(define-constant err-customer-not-found (err u501))
(define-constant err-invalid-action (err u502))
(define-constant err-reward-not-found (err u503))

(define-data-var next-customer-id uint u1)
(define-data-var next-action-id uint u1)

;; Customer profiles
(define-map customers
  { customer-id: uint }
  {
    wallet: principal,
    points-balance: uint,
    total-earned: uint,
    engagement-level: (string-ascii 20),
    join-date: uint
  }
)

;; Customer wallet mapping
(define-map customer-wallets
  { wallet: principal }
  { customer-id: uint }
)

;; Sustainable actions and rewards
(define-map sustainable-actions
  { action-id: uint }
  {
    customer-id: uint,
    action-type: (string-ascii 50),
    points-earned: uint,
    product-id: (optional uint),
    timestamp: uint
  }
)

;; Reward redemptions
(define-map reward-redemptions
  { customer-id: uint, redemption-id: uint }
  {
    reward-type: (string-ascii 50),
    points-cost: uint,
    timestamp: uint
  }
)

;; Redemption counters
(define-map redemption-counts
  { customer-id: uint }
  { count: uint }
)

;; Register new customer
(define-public (register-customer)
  (let
    (
      (customer-id (var-get next-customer-id))
      (caller tx-sender)
    )
    (asserts! (is-none (map-get? customer-wallets { wallet: caller })) err-customer-not-found)

    (map-set customers
      { customer-id: customer-id }
      {
        wallet: caller,
        points-balance: u0,
        total-earned: u0,
        engagement-level: "bronze",
        join-date: block-height
      }
    )

    (map-set customer-wallets { wallet: caller } { customer-id: customer-id })
    (var-set next-customer-id (+ customer-id u1))
    (ok customer-id)
  )
)

;; Record sustainable action and award points
(define-public (record-sustainable-action
  (action-type (string-ascii 50))
  (product-id (optional uint))
)
  (let
    (
      (customer-mapping (unwrap! (map-get? customer-wallets { wallet: tx-sender }) err-customer-not-found))
      (customer-id (get customer-id customer-mapping))
      (customer (unwrap! (map-get? customers { customer-id: customer-id }) err-customer-not-found))
      (action-id (var-get next-action-id))
      (points-earned (calculate-action-points action-type))
      (new-balance (+ (get points-balance customer) points-earned))
      (new-total (+ (get total-earned customer) points-earned))
      (new-level (calculate-engagement-level new-total))
    )
    ;; Record action
    (map-set sustainable-actions
      { action-id: action-id }
      {
        customer-id: customer-id,
        action-type: action-type,
        points-earned: points-earned,
        product-id: product-id,
        timestamp: block-height
      }
    )

    ;; Update customer profile
    (map-set customers
      { customer-id: customer-id }
      (merge customer {
        points-balance: new-balance,
        total-earned: new-total,
        engagement-level: new-level
      })
    )

    (var-set next-action-id (+ action-id u1))
    (ok points-earned)
  )
)

;; Redeem rewards
(define-public (redeem-reward
  (reward-type (string-ascii 50))
  (points-cost uint)
)
  (let
    (
      (customer-mapping (unwrap! (map-get? customer-wallets { wallet: tx-sender }) err-customer-not-found))
      (customer-id (get customer-id customer-mapping))
      (customer (unwrap! (map-get? customers { customer-id: customer-id }) err-customer-not-found))
      (redemption-count (default-to { count: u0 } (map-get? redemption-counts { customer-id: customer-id })))
      (new-redemption-id (get count redemption-count))
    )
    (asserts! (>= (get points-balance customer) points-cost) err-insufficient-points)

    ;; Record redemption
    (map-set reward-redemptions
      { customer-id: customer-id, redemption-id: new-redemption-id }
      {
        reward-type: reward-type,
        points-cost: points-cost,
        timestamp: block-height
      }
    )

    ;; Update customer balance
    (map-set customers
      { customer-id: customer-id }
      (merge customer {
        points-balance: (- (get points-balance customer) points-cost)
      })
    )

    ;; Update redemption count
    (map-set redemption-counts
      { customer-id: customer-id }
      { count: (+ new-redemption-id u1) }
    )

    (ok new-redemption-id)
  )
)

;; Helper function to calculate points for actions
(define-private (calculate-action-points (action-type (string-ascii 50)))
  (if (is-eq action-type "recycle")
    u10
    (if (is-eq action-type "repair")
      u25
      (if (is-eq action-type "reuse")
        u15
        (if (is-eq action-type "share")
          u20
          u5
        )
      )
    )
  )
)

;; Helper function to calculate engagement level
(define-private (calculate-engagement-level (total-points uint))
  (if (>= total-points u1000)
    "platinum"
    (if (>= total-points u500)
      "gold"
      (if (>= total-points u100)
        "silver"
        "bronze"
      )
    )
  )
)

;; Get customer info
(define-read-only (get-customer (customer-id uint))
  (map-get? customers { customer-id: customer-id })
)

;; Get customer by wallet
(define-read-only (get-customer-by-wallet (wallet principal))
  (match (map-get? customer-wallets { wallet: wallet })
    customer-mapping (map-get? customers { customer-id: (get customer-id customer-mapping) })
    none
  )
)

;; Get sustainable action
(define-read-only (get-sustainable-action (action-id uint))
  (map-get? sustainable-actions { action-id: action-id })
)

;; Get reward redemption
(define-read-only (get-reward-redemption (customer-id uint) (redemption-id uint))
  (map-get? reward-redemptions { customer-id: customer-id, redemption-id: redemption-id })
)
