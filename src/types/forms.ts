export type { Database } from './database.gen'

export interface RegisterForm {
  email: string;
  password?: string;
  fullName: string;
  sex: string;
  phone: string;
  college: string;
  program: string;
  yearLevel: string;
  studentId: string;
}
