export type { Database } from './database.gen'

export interface RegisterForm {
  email: string;
  password?: string;
  fullName: string;
  sex: string;
  /** ISO yyyy-mm-dd. OSAS checks it against the birth date on the submitted ID. */
  dateOfBirth: string;
  phone: string;
  college: string;
  program: string;
  yearLevel: string;
  studentId: string;
}
