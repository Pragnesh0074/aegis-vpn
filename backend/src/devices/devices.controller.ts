import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Post,
} from '@nestjs/common';
import type { AuthenticatedUser } from '../auth/auth.types';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import type { DeviceConfigResponse, DeviceSummary } from './device.response';
import { DevicesService } from './devices.service';
import { CreateDeviceDto } from './dto/create-device.dto';

@Controller('devices')
export class DevicesController {
  constructor(private readonly devices: DevicesService) {}

  @Get()
  list(@CurrentUser() user: AuthenticatedUser): Promise<DeviceSummary[]> {
    return this.devices.listForUser(user.userId);
  }

  /**
   * Registers a device's public key and issues a WireGuard peer.
   *
   * The response carries the server's peer details and the assigned tunnel IP. The
   * client's private key is never part of this exchange in either direction.
   */
  @Post()
  @HttpCode(HttpStatus.CREATED)
  create(
    @CurrentUser() user: AuthenticatedUser,
    @Body() dto: CreateDeviceDto,
  ): Promise<DeviceConfigResponse> {
    return this.devices.issue(user.userId, dto);
  }

  @Delete(':id')
  @HttpCode(HttpStatus.NO_CONTENT)
  async remove(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id', ParseUUIDPipe) id: string,
  ): Promise<void> {
    await this.devices.revoke(user.userId, id);
  }
}
