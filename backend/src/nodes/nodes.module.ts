import { Module } from '@nestjs/common';
import { NodeHealthService } from './node-health.service';
import { NodesController } from './nodes.controller';
import { NodesService } from './nodes.service';

@Module({
  controllers: [NodesController],
  providers: [NodesService, NodeHealthService],
  // NodeHealthService is exported for the sweep in DevicesModule, which is what
  // actually probes the fleet — see LastSeenService.
  exports: [NodesService, NodeHealthService],
})
export class NodesModule {}
