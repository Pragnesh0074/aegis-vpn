import { Controller, Get } from '@nestjs/common';
import { NodesService, type NodeSummary } from './nodes.service';

@Controller('nodes')
export class NodesController {
  constructor(private readonly nodes: NodesService) {}

  /** Server list for the client's picker. Authenticated — not a public inventory. */
  @Get()
  list(): Promise<NodeSummary[]> {
    return this.nodes.listActive();
  }
}
