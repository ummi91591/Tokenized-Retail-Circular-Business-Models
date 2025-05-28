;; Business Verification Contract
;; Validates and manages circular economy retailers

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-already-verified (err u101))
(define-constant err-not-found (err u102))
(define-constant err-not-verified (err u103))

;; Business verification status
(define-data-var next-business-id uint u1)

;; Business data structure
(define-map businesses
  { business-id: uint }
  {
    owner: principal,
    name: (string-ascii 100),
    verification-status: (string-ascii 20),
    circular-score: uint,
    registration-block: uint
  }
)

;; Business owner mapping
(define-map business-owners
  { owner: principal }
  { business-id: uint }
)

;; Register a new business
(define-public (register-business (name (string-ascii 100)))
  (let
    (
      (business-id (var-get next-business-id))
      (caller tx-sender)
    )
    (asserts! (is-none (map-get? business-owners { owner: caller })) err-already-verified)
    (map-set businesses
      { business-id: business-id }
      {
        owner: caller,
        name: name,
        verification-status: "pending",
        circular-score: u0,
        registration-block: block-height
      }
    )
    (map-set business-owners { owner: caller } { business-id: business-id })
    (var-set next-business-id (+ business-id u1))
    (ok business-id)
  )
)

;; Verify a business (admin only)
(define-public (verify-business (business-id uint) (circular-score uint))
  (let
    (
      (business (unwrap! (map-get? businesses { business-id: business-id }) err-not-found))
    )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (map-set businesses
      { business-id: business-id }
      (merge business {
        verification-status: "verified",
        circular-score: circular-score
      })
    )
    (ok true)
  )
)

;; Get business info
(define-read-only (get-business (business-id uint))
  (map-get? businesses { business-id: business-id })
)

;; Check if business is verified
(define-read-only (is-business-verified (business-id uint))
  (match (map-get? businesses { business-id: business-id })
    business (is-eq (get verification-status business) "verified")
    false
  )
)

;; Get business by owner
(define-read-only (get-business-by-owner (owner principal))
  (map-get? business-owners { owner: owner })
)
