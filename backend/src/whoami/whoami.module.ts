import { Module } from '@nestjs/common';
import { WhoamiController } from './whoami.controller';
import { WhoamiService } from './whoami.service';

@Module({
  controllers: [WhoamiController],
  providers: [WhoamiService],
})
export class WhoamiModule {}
