import { Module } from '@nestjs/common';
import { AppConfig } from '../config/configuration';
import { IpAllocatorService } from './ip-allocator.service';
import { ExecWgRunner } from './runners/exec-wg.runner';
import { FakeWgRunner } from './runners/fake-wg.runner';
import { WG_RUNNER, type WgRunner } from './wg-runner';
import { WireguardService } from './wireguard.service';

@Module({
  providers: [
    ExecWgRunner,
    FakeWgRunner,
    {
      // WG_RUNNER decides which implementation is bound. env.validation.ts already
      // rejects 'fake' under NODE_ENV=production, so this cannot silently no-op live.
      provide: WG_RUNNER,
      inject: [AppConfig, ExecWgRunner, FakeWgRunner],
      useFactory: (config: AppConfig, exec: ExecWgRunner, fake: FakeWgRunner): WgRunner =>
        config.wgRunner === 'exec' ? exec : fake,
    },
    IpAllocatorService,
    WireguardService,
  ],
  exports: [WireguardService, IpAllocatorService],
})
export class WireguardModule {}
