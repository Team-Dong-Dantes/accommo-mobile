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

/** A student's registration, with the proof-of-enrolment files and the text the phone read off them. */
export interface StudentRegisterForm extends RegisterForm {
  schoolIdFile?: File | null;
  assessmentFile?: File | null;
  schoolIdText?: string | null;
  assessmentText?: string | null;
}
