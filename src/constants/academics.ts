// ISU colleges, their programs and the year-level labels.
// Shared by student registration and the student profile editor so the two
// can never drift apart and write mismatched values into student_profiles.

export const yearOptions = ['1st Year', '2nd Year', '3rd Year', '4th Year', '5th Year', '6th Year'];

export const collegePrograms: Record<string, string[]> = {
  'College of Agriculture (CA)': [
    'BS in Agriculture major in Agronomy',
    'BS in Agriculture major in Horticulture',
    'BS in Agriculture major in Animal Science',
    'BS in Agribusiness',
    'BS in Animal Husbandry',
    'Diploma in Agricultural Technology (DAT)',
  ],
  'College of Arts and Sciences (CAS)': [
    'BS in Biology',
    'BS in Mathematics',
    'BS in Psychology',
    'BA in Communication',
    'BA in English Language Studies',
    'BS in Environmental Science',
  ],
  'College of Business, Accountancy and Public Administration (CBAPA)': [
    'BS in Accountancy',
    'BS in Management Accounting',
    'BS in Business Administration',
    'BS in Entrepreneurship',
    'BA in Public Administration',
    'BS in Hospitality Management',
    'BS in Tourism Management',
  ],
  'College of Computing Studies, Information and Communication Technology (CCSICT)': [
    'BS in Computer Science',
    'BS in Information Technology',
    'BS in Information Systems',
    'BS in Library and Information Science',
    'BS in Data Science and Analytics',
  ],
  'College of Criminal Justice Education (CCJE)': [
    'BS in Criminology',
    'BS in Law Enforcement Administration',
  ],
  'College of Education (COEd)': [
    'Bachelor of Elementary Education (BEEd)',
    'Bachelor of Secondary Education (BSEd)',
    'Bachelor of Physical Education (BPEd)',
    'Bachelor of Technology and Livelihood Education (BTLEd)',
  ],
  'College of Engineering (COE)': [
    'BS in Agricultural and Biosystems Engineering',
    'BS in Civil Engineering',
  ],
  'College of Nursing (CON)': [
    'BS in Nursing (BSN)',
  ],
  'Institute of Fisheries (IOF)': [
    'BS in Fisheries and Aquatic Sciences',
  ],
  'School of Veterinary Medicine (SVM)': [
    'Doctor of Veterinary Medicine (DVM)',
  ],
};

export const collegeOptions = Object.keys(collegePrograms);

/** '3rd Year' -> 3. Falls back to 1 for anything unparsable. */
export function yearLevelFromLabel(label: string): number {
  return parseInt(label.charAt(0), 10) || 1;
}

/** 3 -> '3rd Year'. Empty when the level is unknown. */
export function yearLevelToLabel(level: number | null | undefined): string {
  if (!level) return '';
  return yearOptions[level - 1] ?? `${level}`;
}
