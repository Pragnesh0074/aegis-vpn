import { Module } from '@nestjs/common';
import { NodesController } from './nodes.controller';
import { NodesService } from './nodes.service';

@Module({
  controllers: [NodesController],
  providers: [NodesService],
  exports: [NodesService], // DevicesModule (C7) selects a node when issuing a peer
})
export class NodesModule {}
