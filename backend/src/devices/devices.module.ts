import { Module } from '@nestjs/common';
import { NodesModule } from '../nodes/nodes.module';
import { UsersModule } from '../users/users.module';
import { WireguardModule } from '../wireguard/wireguard.module';
import { DevicesController } from './devices.controller';
import { DevicesService } from './devices.service';
import { LastSeenService } from './last-seen.service';

@Module({
  imports: [UsersModule, NodesModule, WireguardModule],
  controllers: [DevicesController],
  providers: [DevicesService, LastSeenService],
})
export class DevicesModule {}
