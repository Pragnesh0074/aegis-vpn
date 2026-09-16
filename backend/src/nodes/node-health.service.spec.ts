import { NodeHealthService } from './node-health.service';

/**
 * `Node.active` says what an operator wants; this says what is actually there.
 * The behaviour worth pinning is the middle ground — one failed probe is a bad
 * minute, not an outage.
 */
describe('NodeHealthService', () => {
  let health: NodeHealthService;

  beforeEach(() => {
    health = new NodeHealthService();
  });

  it('treats a node nothing has probed as healthy', () => {
    // A restart must not be an outage for as long as the first sweep takes.
    expect(health.isHealthy('unknown')).toBe(true);
    expect(health.get('unknown')).toBeNull();
  });

  it('tolerates a single failure', () => {
    health.unreachable('n1', 'Frankfurt #1', 'timeout');

    expect(health.isHealthy('n1')).toBe(true);
    expect(health.get('n1')?.failures).toBe(1);
  });

  it('gives up at the threshold', () => {
    for (let i = 0; i < NodeHealthService.FAILURES_BEFORE_UNHEALTHY; i++) {
      health.unreachable('n1', 'Frankfurt #1', 'connection refused');
    }

    expect(health.isHealthy('n1')).toBe(false);
    expect(health.get('n1')?.lastError).toBe('connection refused');
  });

  it('recovers on a single success', () => {
    // Recovery is not symmetrical with failure on purpose: a node that answers
    // is answering, and holding it out of selection to be sure would extend an
    // outage that is already over.
    for (let i = 0; i < NodeHealthService.FAILURES_BEFORE_UNHEALTHY; i++) {
      health.unreachable('n1', 'Frankfurt #1', 'down');
    }
    health.reachable('n1', 'Frankfurt #1');

    expect(health.isHealthy('n1')).toBe(true);
    expect(health.get('n1')?.failures).toBe(0);
    expect(health.get('n1')?.lastError).toBeNull();
  });

  it('counts failures per node', () => {
    for (let i = 0; i < NodeHealthService.FAILURES_BEFORE_UNHEALTHY; i++) {
      health.unreachable('n1', 'Frankfurt #1', 'down');
    }

    expect(health.isHealthy('n1')).toBe(false);
    expect(health.isHealthy('n2')).toBe(true);
  });

  it('remembers when a node was last reachable', () => {
    health.reachable('n1', 'Frankfurt #1');
    health.unreachable('n1', 'Frankfurt #1', 'down');

    // Kept across the failure: "last seen twenty minutes ago" is the first thing
    // anyone wants to know about a node that has stopped answering.
    expect(health.get('n1')?.lastReachableAt).toBeInstanceOf(Date);
  });
});
