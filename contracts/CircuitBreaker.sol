// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

/**
 * @dev Circuit breaker to monitor and handle for external failures.
 *
 * These functions can be used to:
 * - Track failed and successful external calls
 * - Trip a circuit breaker when a failure treshold is reached
 * - Reset a circuit breaker when a cooldown timer is met
 */
library CircuitBreaker {
  enum Status { CLOSED, OPEN }
  event Opened(uint retryAt);
  event Closed();

  struct Breaker {
    Status status; // OPEN or CLOSED (HalfOpen is a subset of OPEN)
    uint8 failureCount; // Counter for number of failed calls
    uint8 failureTreshold; // When failure count >= treshold, trip / open the breaker
    uint cooldown; // How long after a trip before the breaker is half-opened (in seconds)
    uint retryAt; // Unix timestamp when breaker is half-opened (in seconds)
  }

  /**
    * @dev Returns a new Circuit Breaker.
    */
  function build(uint8 _failureTreshold, uint _cooldown) internal pure returns (Breaker memory) {
    require(_failureTreshold > 0, 'Breaker failure treshold must be greater than zero.');
    require(_cooldown > 0, 'Breaker cooldown must be greater than zero.');
    return Breaker(
      Status.CLOSED,
      0,
      _failureTreshold,
      _cooldown,
      0
    );
  }

  /**
    * @dev Tracks a successful function call.
    */
  function success(Breaker storage self) internal {
    if (_canReset(self)) _reset(self);
  }

  /**
    * @dev Returns true if breaker can be reset.
    */
  function _canReset(Breaker storage self) private view returns (bool) {
    return isHalfOpen(self);
  }

  /**
    * @dev Resets the circuit breaker. HALFOPEN -> CLOSED
    */
  function _reset(Breaker storage self) private {
    self.status = Status.CLOSED;
    self.failureCount = 0;
    emit Closed();
  }

  /**
    * @dev Tracks a failed function call.
    */
  function fail(Breaker storage self) internal {
    self.failureCount++;
    if (_canTrip(self)) _trip(self);
  }

  /**
    * @dev Returns true if breaker can be tripped.
    */
  function _canTrip(Breaker storage self) private view returns (bool) {
    return (isClosed(self) && self.failureCount >= self.failureTreshold) || isHalfOpen(self);
  }

  /**
    * @dev Trips the circuit breaker. CLOSED / HALFOPEN -> OPEN
    */
  function _trip(Breaker storage self) private {
    self.status = Status.OPEN;
    self.retryAt = now + self.cooldown;
    emit Opened(self.retryAt);
  }

  function isClosed(Breaker storage self) internal view returns (bool) {
    return self.status == Status.CLOSED;
  }

  function isOpen(Breaker storage self) internal view returns (bool) {
    return self.status == Status.OPEN && now < self.retryAt; // Waiting for retry cooldown
  }

  function isHalfOpen(Breaker storage self) internal view returns (bool) {
    return self.status == Status.OPEN && now >= self.retryAt; // Has passed retry cooldown
  }
}
