// The registration flow's screens, what each one asks, and its fixed options.

export type StepKey =
  | 'name'
  | 'phone'
  | 'email'
  | 'password'
  | 'verify'
  | 'studies'
  | 'studentId'
  | 'schoolId'
  | 'assessment'
  | 'governmentId'
  | 'businessPermit';

/** The short name in the step header — what this screen is, for the progress row. */
export const STEP_TITLE: Record<StepKey, string> = {
  name: 'Your name',
  phone: 'Mobile',
  email: 'E-mail',
  password: 'Password',
  verify: 'Confirm e-mail',
  studies: 'Studies',
  studentId: 'Student ID',
  schoolId: 'School ID',
  assessment: 'Assessment',
  governmentId: 'Government ID',
  businessPermit: 'Permit',
};

/**
 * The question each screen asks, which is also its title. One thing per screen
 * is the whole point of this flow, so the question carries the screen rather
 * than sitting under a page heading that repeats on every one of them.
 */
export const STEP_QUESTION: Record<StepKey, { title: string; note?: string }> = {
  name: { title: "What's your name?", note: 'As it appears on your school records.' },
  phone: { title: "What's your mobile number?", note: 'Landlords/Landladies reach you here about your application.' },
  email: { title: 'What e-mail should we use?', note: 'We send a code here to confirm it is yours.' },
  password: { title: 'Choose a password' },
  verify: { title: 'Confirm your e-mail' },
  studies: { title: 'What are you studying?' },
  studentId: {
    title: "What's your student ID?",
    note: 'The number printed on your ISU school ID. You can add it later from Profile if you do not have it to hand.',
  },
  // Not "Can you prove your enrolment?", which read as a challenge — the app
  // asking a student to justify themselves before it will let them in. This is
  // the same task the landlord/landlady screen calls "Verify your property", and the two
  // should sound like the same app doing the same thing.
  schoolId: {
    title: 'Verify your enrolment',
    note: 'Start with your school ID. Optional — only OSAS sees it, and you can add it later from Profile.',
  },
  assessment: {
    title: 'Verify your enrolment',
    note: 'Now your Assessment of Fees. Optional — you can browse Accommo while OSAS checks.',
  },
  governmentId: {
    title: 'Verify your property',
    note: 'Start with your government ID. Only OSAS sees it; they cannot accredit a property without it.',
  },
  businessPermit: {
    title: 'Verify your property',
    note: 'Now the permit for the property. Only OSAS sees it; they cannot accredit a property without it.',
  },
};

export const sexOptions = ['Male', 'Female'];

/** N/A leads and is the default: most people have no extension. */
export const NAME_EXT_NONE = 'N/A';
export const nameExtensions = [NAME_EXT_NONE, 'Jr.', 'Sr.', 'II', 'III', 'IV', 'V'];
