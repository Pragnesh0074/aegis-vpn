import { IsJWT } from 'class-validator';

export class RefreshDto {
  @IsJWT({ message: 'refreshToken must be a JWT' })
  refreshToken!: string;
}
