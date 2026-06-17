const logger = require('./logger');
const metrics = require('./metrics');

const STATE = { CLOSED: 0, OPEN: 1, HALF_OPEN: 2 };

class CircuitBreaker {
  constructor(name, {
    failureThreshold = 5,
    successThreshold = 2,
    timeoutMs = 30000,
    halfOpenMaxRequests = 1,
  } = {}) {
    this.name = name;
    this.failureThreshold = failureThreshold;
    this.successThreshold = successThreshold;
    this.timeoutMs = timeoutMs;
    this.halfOpenMaxRequests = halfOpenMaxRequests;

    this.state = STATE.CLOSED;
    this.failureCount = 0;
    this.successCount = 0;
    this.lastFailureTime = null;
    this.halfOpenRequests = 0;
    this.nextAttempt = null;
  }

  async call(fn, fallback) {
    if (this.state === STATE.OPEN) {
      if (this.nextAttempt && Date.now() >= this.nextAttempt) {
        this.state = STATE.HALF_OPEN;
        this.halfOpenRequests = 0;
        logger.info({ service: this.name }, 'Circuit breaker half-open');
      } else {
        logger.warn({ service: this.name, remainingMs: this.nextAttempt - Date.now() }, 'Circuit breaker open — using fallback');
        metrics.circuitBreakerFailures.inc({ service: this.name });
        return fallback ? fallback() : this._defaultFallback();
      }
    }

    if (this.state === STATE.HALF_OPEN && this.halfOpenRequests >= this.halfOpenMaxRequests) {
      logger.warn({ service: this.name }, 'Half-open limit reached — deferring');
      return fallback ? fallback() : this._defaultFallback();
    }

    this.halfOpenRequests++;
    const { result, error } = await this._try(fn);

    if (error) {
      this._onFailure();
      metrics.circuitBreakerState.set({ service: this.name }, this.state);
      metrics.circuitBreakerFailures.inc({ service: this.name });
      if (fallback) return fallback();
      throw error;
    }

    this._onSuccess();
    metrics.circuitBreakerState.set({ service: this.name }, this.state);
    return result;
  }

  async _try(fn) {
    try {
      const result = await fn();
      return { result, error: null };
    } catch (error) {
      return { result: null, error };
    }
  }

  _onFailure() {
    this.failureCount++;
    this.lastFailureTime = Date.now();
    this.successCount = 0;

    if (this.state === STATE.HALF_OPEN) {
      this.halfOpenRequests = 0;
      this.state = STATE.OPEN;
      this.nextAttempt = Date.now() + this.timeoutMs;
      logger.error({ service: this.name, failureCount: this.failureCount }, 'Circuit breaker opened');
    } else if (this.failureCount >= this.failureThreshold) {
      this.state = STATE.OPEN;
      this.nextAttempt = Date.now() + this.timeoutMs;
      logger.error({ service: this.name, failureCount: this.failureCount }, 'Circuit breaker opened');
    }
  }

  _onSuccess() {
    if (this.state === STATE.HALF_OPEN) {
      this.halfOpenRequests = 0;
      this.successCount++;
      if (this.successCount >= this.successThreshold) {
        this.state = STATE.CLOSED;
        this.failureCount = 0;
        this.successCount = 0;
        this.nextAttempt = null;
        logger.info({ service: this.name }, 'Circuit breaker closed');
      }
    } else {
      this.failureCount = 0;
    }
  }

  _defaultFallback() {
    return { circuitBreakerOpen: true, service: this.name };
  }

  getStateName() {
    return ['CLOSED', 'OPEN', 'HALF_OPEN'][this.state];
  }
}

module.exports = { CircuitBreaker, STATE };
