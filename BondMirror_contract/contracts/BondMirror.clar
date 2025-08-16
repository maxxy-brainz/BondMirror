
;; title: BondMirror
;; version: 1.0.0
;; summary: Synthetic Assets for Government and Corporate Bond Performance Tracking
;; description: BondMirror creates synthetic exposure to traditional bond assets,
;; allowing users to track and trade synthetic representations of government and corporate bonds.

;; traits
;;

;; token definitions
(define-fungible-token synthetic-bond)

;; constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_INVALID_AMOUNT (err u101))
(define-constant ERR_INSUFFICIENT_BALANCE (err u102))
(define-constant ERR_BOND_NOT_FOUND (err u103))
(define-constant ERR_BOND_EXPIRED (err u104))
(define-constant ERR_PRICE_TOO_OLD (err u105))
(define-constant ERR_INVALID_BOND_TYPE (err u106))

;; Maximum age for price data in blocks (approximately 24 hours)
(define-constant MAX_PRICE_AGE u144)

;; Bond types
(define-constant GOVERNMENT_BOND u1)
(define-constant CORPORATE_BOND u2)

;; data vars
(define-data-var contract-owner principal CONTRACT_OWNER)
(define-data-var total-bonds-created uint u0)
(define-data-var oracle-enabled bool true)

;; data maps
;; Bond registry storing bond metadata
(define-map bonds
  { bond-id: uint }
  {
    bond-type: uint,        ;; 1 for government, 2 for corporate
    issuer: (string-ascii 64),
    symbol: (string-ascii 16),
    maturity-date: uint,    ;; Block height when bond matures
    face-value: uint,       ;; Face value in micro-STX
    coupon-rate: uint,      ;; Annual coupon rate in basis points (e.g., 500 = 5%)
    created-at: uint,       ;; Block height when created
    is-active: bool
  }
)

;; Current price data for bonds
(define-map bond-prices
  { bond-id: uint }
  {
    current-price: uint,    ;; Current market price in micro-STX
    last-updated: uint,     ;; Block height of last price update
    price-change-24h: int   ;; Price change in last 24h (can be negative)
  }
)

;; User positions in synthetic bonds
(define-map user-positions
  { user: principal, bond-id: uint }
  {
    shares: uint,           ;; Number of synthetic shares owned
    entry-price: uint,      ;; Price when position was opened
    entry-block: uint       ;; Block height when position was opened
  }
)

;; Oracle addresses authorized to update prices
(define-map authorized-oracles principal bool)

;; public functions

;; Initialize the contract and set up the owner
(define-public (initialize)
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    ;; Add contract owner as authorized oracle
    (map-set authorized-oracles (var-get contract-owner) true)
    (ok true)
  )
)

;; Create a new synthetic bond
(define-public (create-bond 
  (bond-type uint)
  (issuer (string-ascii 64))
  (symbol (string-ascii 16))
  (maturity-date uint)
  (face-value uint)
  (coupon-rate uint)
  (initial-price uint))
  (let
    (
      (bond-id (+ (var-get total-bonds-created) u1))
    )
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (asserts! (or (is-eq bond-type GOVERNMENT_BOND) (is-eq bond-type CORPORATE_BOND)) ERR_INVALID_BOND_TYPE)
    (asserts! (> maturity-date block-height) ERR_BOND_EXPIRED)
    (asserts! (> face-value u0) ERR_INVALID_AMOUNT)
    (asserts! (> initial-price u0) ERR_INVALID_AMOUNT)
    
    ;; Create bond record
    (map-set bonds { bond-id: bond-id }
      {
        bond-type: bond-type,
        issuer: issuer,
        symbol: symbol,
        maturity-date: maturity-date,
        face-value: face-value,
        coupon-rate: coupon-rate,
        created-at: block-height,
        is-active: true
      }
    )
    
    ;; Set initial price
    (map-set bond-prices { bond-id: bond-id }
      {
        current-price: initial-price,
        last-updated: block-height,
        price-change-24h: 0
      }
    )
    
    (var-set total-bonds-created bond-id)
    (ok bond-id)
  )
)

;; Purchase synthetic bond shares
(define-public (buy-synthetic-bond (bond-id uint) (shares uint))
  (let
    (
      (bond-data (unwrap! (map-get? bonds { bond-id: bond-id }) ERR_BOND_NOT_FOUND))
      (price-data (unwrap! (map-get? bond-prices { bond-id: bond-id }) ERR_BOND_NOT_FOUND))
      (current-price (get current-price price-data))
      (total-cost (* shares current-price))
      (existing-position (default-to 
        { shares: u0, entry-price: u0, entry-block: u0 }
        (map-get? user-positions { user: tx-sender, bond-id: bond-id })
      ))
    )
    (asserts! (get is-active bond-data) ERR_BOND_EXPIRED)
    (asserts! (> shares u0) ERR_INVALID_AMOUNT)
    (asserts! (>= (stx-get-balance tx-sender) total-cost) ERR_INSUFFICIENT_BALANCE)
    (asserts! (<= (- block-height (get last-updated price-data)) MAX_PRICE_AGE) ERR_PRICE_TOO_OLD)
    
    ;; Transfer STX as collateral
    (try! (stx-transfer? total-cost tx-sender (as-contract tx-sender)))
    
    ;; Mint synthetic tokens
    (try! (ft-mint? synthetic-bond shares tx-sender))
    
    ;; Update user position
    (let
      (
        (new-total-shares (+ (get shares existing-position) shares))
        (weighted-entry-price (if (is-eq (get shares existing-position) u0)
          current-price
          (/ (+ (* (get shares existing-position) (get entry-price existing-position))
                (* shares current-price))
             new-total-shares)
        ))
      )
      (map-set user-positions { user: tx-sender, bond-id: bond-id }
        {
          shares: new-total-shares,
          entry-price: weighted-entry-price,
          entry-block: block-height
        }
      )
    )
    
    (ok shares)
  )
)

;; Sell synthetic bond shares
(define-public (sell-synthetic-bond (bond-id uint) (shares uint))
  (let
    (
      (bond-data (unwrap! (map-get? bonds { bond-id: bond-id }) ERR_BOND_NOT_FOUND))
      (price-data (unwrap! (map-get? bond-prices { bond-id: bond-id }) ERR_BOND_NOT_FOUND))
      (current-price (get current-price price-data))
      (user-position (unwrap! (map-get? user-positions { user: tx-sender, bond-id: bond-id }) ERR_INSUFFICIENT_BALANCE))
      (user-shares (get shares user-position))
      (payout (* shares current-price))
    )
    (asserts! (get is-active bond-data) ERR_BOND_EXPIRED)
    (asserts! (> shares u0) ERR_INVALID_AMOUNT)
    (asserts! (>= user-shares shares) ERR_INSUFFICIENT_BALANCE)
    (asserts! (<= (- block-height (get last-updated price-data)) MAX_PRICE_AGE) ERR_PRICE_TOO_OLD)
    
    ;; Burn synthetic tokens
    (try! (ft-burn? synthetic-bond shares tx-sender))
    
    ;; Transfer STX payout
    (try! (as-contract (stx-transfer? payout tx-sender tx-sender)))
    
    ;; Update user position
    (if (is-eq user-shares shares)
      ;; Remove position entirely
      (map-delete user-positions { user: tx-sender, bond-id: bond-id })
      ;; Update with remaining shares
      (map-set user-positions { user: tx-sender, bond-id: bond-id }
        {
          shares: (- user-shares shares),
          entry-price: (get entry-price user-position),
          entry-block: (get entry-block user-position)
        }
      )
    )
    
    (ok payout)
  )
)

;; Update bond price (only authorized oracles)
(define-public (update-bond-price (bond-id uint) (new-price uint))
  (let
    (
      (bond-data (unwrap! (map-get? bonds { bond-id: bond-id }) ERR_BOND_NOT_FOUND))
      (old-price-data (unwrap! (map-get? bond-prices { bond-id: bond-id }) ERR_BOND_NOT_FOUND))
      (price-change (- (to-int new-price) (to-int (get current-price old-price-data))))
    )
    (asserts! (default-to false (map-get? authorized-oracles tx-sender)) ERR_UNAUTHORIZED)
    (asserts! (get is-active bond-data) ERR_BOND_EXPIRED)
    (asserts! (> new-price u0) ERR_INVALID_AMOUNT)
    
    (map-set bond-prices { bond-id: bond-id }
      {
        current-price: new-price,
        last-updated: block-height,
        price-change-24h: price-change
      }
    )
    
    (ok true)
  )
)

;; Add authorized oracle
(define-public (add-oracle (oracle principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (map-set authorized-oracles oracle true)
    (ok true)
  )
)

;; Remove authorized oracle
(define-public (remove-oracle (oracle principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (map-delete authorized-oracles oracle)
    (ok true)
  )
)

;; Deactivate bond (for matured or delisted bonds)
(define-public (deactivate-bond (bond-id uint))
  (let
    (
      (bond-data (unwrap! (map-get? bonds { bond-id: bond-id }) ERR_BOND_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    
    (map-set bonds { bond-id: bond-id }
      (merge bond-data { is-active: false })
    )
    
    (ok true)
  )
)

;; read only functions

;; Get bond information
(define-read-only (get-bond-info (bond-id uint))
  (map-get? bonds { bond-id: bond-id })
)

;; Get bond price information
(define-read-only (get-bond-price (bond-id uint))
  (map-get? bond-prices { bond-id: bond-id })
)

;; Get user position
(define-read-only (get-user-position (user principal) (bond-id uint))
  (map-get? user-positions { user: user, bond-id: bond-id })
)

;; Get total number of bonds created
(define-read-only (get-total-bonds)
  (var-get total-bonds-created)
)

;; Check if address is authorized oracle
(define-read-only (is-authorized-oracle (oracle principal))
  (default-to false (map-get? authorized-oracles oracle))
)

;; Get contract owner
(define-read-only (get-contract-owner)
  (var-get contract-owner)
)

;; Calculate position value
(define-read-only (get-position-value (user principal) (bond-id uint))
  (match (map-get? user-positions { user: user, bond-id: bond-id })
    position
    (match (map-get? bond-prices { bond-id: bond-id })
      price-data
      (some (* (get shares position) (get current-price price-data)))
      none
    )
    none
  )
)

;; Calculate position profit/loss
(define-read-only (get-position-pnl (user principal) (bond-id uint))
  (match (map-get? user-positions { user: user, bond-id: bond-id })
    position
    (match (map-get? bond-prices { bond-id: bond-id })
      price-data
      (let
        (
          (current-value (* (get shares position) (get current-price price-data)))
          (entry-value (* (get shares position) (get entry-price position)))
        )
        (some (- (to-int current-value) (to-int entry-value)))
      )
      none
    )
    none
  )
)

;; Get synthetic bond token balance
(define-read-only (get-synthetic-balance (user principal))
  (ft-get-balance synthetic-bond user)
)

;; private functions

;; Helper function to check if bond has matured
(define-private (is-bond-matured (bond-id uint))
  (match (map-get? bonds { bond-id: bond-id })
    bond-data
    (>= block-height (get maturity-date bond-data))
    false
  )
)

