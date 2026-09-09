import { IsEmail, IsString, MaxLength, MinLength } from 'class-validator';

export class RegisterDto {
  @IsEmail({}, { message: 'A valid email address is required' })
  @MaxLength(254)
  email!: string;

  // 10 chars minimum, and no composition rules: length beats character classes, and
  // arbitrary rules push people toward predictable substitutions.
  @IsString()
  @MinLength(10, { message: 'Password must be at least 10 characters' })
  @MaxLength(128)
  password!: string;
}
