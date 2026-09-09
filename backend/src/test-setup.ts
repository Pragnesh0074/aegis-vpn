import { Logger } from '@nestjs/common';

// Services log deliberately (reconcile drift, retry warnings, boot failures). Useful
// in production, pure noise in test output — and some specs exercise the error paths
// on purpose, so the logs would look like failures.
Logger.overrideLogger(false);
