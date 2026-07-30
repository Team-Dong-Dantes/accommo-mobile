export type { Database } from './database.gen'

export interface User {
  id: string;
  email: string;
  full_name?: string;
  initials?: string;
  sex?: string;
  role?: string;
  phone?: string;
  student_id?: string;
  college?: string;
  program?: string;
  year_level?: number;
  created_at?: string;
  updated_at?: string;
}

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
