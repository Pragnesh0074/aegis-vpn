import { Module } from '@nestjs/common';
import { AppConfig } from '../config/configuration';
import { IpAllocatorService } from './ip-allocator.service';
import { ExecWgRunner } from './runners/exec-wg.runner';
import { FakeWgRunner } from './runners/fake-wg.runner';
import { WG_EXEC_OPTIONS, WG_RUNNER, type WgExecOptions, type WgRunner } from './wg-runner';
import { WgRunnerRegistry } from './wg-runner.registry';
import { WireguardService } from './wireguard.service';

@Module({
  providers: [
    {
      // The same options the agent builds from its own, much narrower environment.
      provide: WG_EXEC_OPTIONS,
      inject: [AppConfig],
      useFactory: (config: AppConfig): WgExecOptions => ({
        interfaceName: config.wgInterface,
        binary: config.wgBinary,
        quickBinary: config.wgQuickBinary,
      }),
    },
    ExecWgRunner,
    FakeWgRunner,
    {
      // The runner for THIS host's interface. Remote nodes are reached through their
      // agent instead — `WgRunnerRegistry` picks between the two per node.
      //
      // WG_RUNNER decides which implementation is bound. env.validation.ts already
      // rejects 'fake' under NODE_ENV=production, so this cannot silently no-op live.
      provide: WG_RUNNER,
      inject: [AppConfig, ExecWgRunner, FakeWgRunner],
      useFactory: (config: AppConfig, exec: ExecWgRunner, fake: FakeWgRunner): WgRunner =>
        config.wgRunner === 'exec' ? exec : fake,
    },
    WgRunnerRegistry,
    IpAllocatorService,
    WireguardService,
  ],
  exports: [WireguardService, IpAllocatorService, WgRunnerRegistry],
})
export class WireguardModule {}
