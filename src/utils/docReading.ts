// What a school ID or an assessment of fees says, checked against what the
// student typed at registration.
//
// Twin file: accommo-mobile/src/utils/docReading.ts and
// accommo-web/src/utils/docReading.ts are byte-for-byte the same. The phone
// runs it to tell the student at once; the console runs it on the stored text
// to tell OSAS. A web test fails if the two drift apart.
//
// Text recognition misreads, so nothing here rejects a document: a clear match
// is ok, anything else asks a person to look.

export type ReadDocType = 'school_id' | 'assessment_of_fees'

/** The registration answers a document is checked against. */
export interface DocExpected {
  fullName: string
  /** "21-123456" */
  studentId: string
  /** "College of Arts and Sciences (CAS)" */
  college: string
}

export interface DocFinding {
  label: string
  ok: boolean
  detail: string
}

/**
 * Stored per document type on student_profiles.document_text. The raw text, not
 * the verdict, so the console re-checks it against the profile as it is now.
 */
export interface DocReading {
  text: string
  read_at: string
}

export type DocReadings = Partial<Record<ReadDocType, DocReading>>

/** Upper case, accents and punctuation gone: "Peña, Ma." → "PENA MA". */
function normalize(s: string): string {
  return s
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .toUpperCase()
    .replace(/[^A-Z0-9]+/g, ' ')
    .trim()
}

function editDistance(a: string, b: string): number {
  const row = Array.from({ length: b.length + 1 }, (_, i) => i)
  for (let i = 1; i <= a.length; i++) {
    let diag = row[0]!
    row[0] = i
    for (let j = 1; j <= b.length; j++) {
      const above = row[j]!
      row[j] = Math.min(above + 1, row[j - 1]! + 1, diag + (a[i - 1] === b[j - 1] ? 0 : 1))
      diag = above
    }
  }
  return row[b.length]!
}

/** One misread letter is forgiven in a name part of five letters or more. */
function hasWord(words: Set<string>, token: string): boolean {
  if (words.has(token)) return true
  if (token.length < 5) return false
  for (const w of words) if (Math.abs(w.length - token.length) <= 1 && editDistance(w, token) <= 1) return true
  return false
}

const SUFFIXES = new Set(['JR', 'SR', 'II', 'III', 'IV'])

function nameFinding(text: string, fullName: string): DocFinding {
  const words = new Set(normalize(text).split(' '))
  // Single letters are middle initials, too short to look for, and a
  // suffix is often left off the document.
  const parts = normalize(fullName).split(' ').filter((p) => p.length >= 2 && !SUFFIXES.has(p))
  const missing = parts.filter((p) => !hasWord(words, p))
  return {
    label: 'Name',
    ok: parts.length > 0 && missing.length === 0,
    detail: !parts.length
      ? 'No name on the account to compare.'
      : missing.length
        ? `Couldn't find ${missing.map((m) => `“${m}”`).join(', ')} on it.`
        : `Shows ${fullName}.`,
  }
}

/** The usual misreads of a digit: O for 0, I or l for 1, S for 5, B for 8. */
function asDigits(s: string): string {
  return s.replace(/[Oo]/g, '0').replace(/[Il|]/g, '1').replace(/S/g, '5').replace(/B/g, '8')
}

function studentIdFinding(text: string, studentId: string): DocFinding {
  const parts = studentId.match(/^(\d{2})-(\d{4,6})$/)
  if (!parts) return { label: 'Student number', ok: false, detail: 'No student number on the account to compare.' }
  const wanted = new RegExp(`(?<!\\d)${parts[1]}\\s?[-–—.]?\\s?${parts[2]}(?!\\d)`)
  if (wanted.test(asDigits(text))) return { label: 'Student number', ok: true, detail: `Shows ${studentId}.` }
  const other = text.match(/(?<!\d)(\d{2})\s?[-–]\s?(\d{4,6})(?!\d)/)
  return {
    label: 'Student number',
    ok: false,
    detail: other
      ? `Shows ${other[1]}-${other[2]}, not ${studentId}.`
      : `Couldn't find ${studentId} on it.`,
  }
}

function schoolFinding(text: string): DocFinding {
  const ok = /ISABELA STATE UNIVERSITY|\bISU\b/.test(normalize(text))
  return { label: 'School', ok, detail: ok ? 'Isabela State University.' : "Couldn't find “Isabela State University” on it." }
}

type Semester = '1st' | '2nd' | 'summer'

/**
 * The school year and semester running on a date. ISU's first semester runs
 * August to December, the second January to May, the summer term June and July.
 */
export function currentTerm(today: Date): { startYear: number; semester: Semester } {
  const m = today.getMonth()
  const y = today.getFullYear()
  return m >= 7 ? { startYear: y, semester: '1st' } : { startYear: y - 1, semester: m <= 4 ? '2nd' : 'summer' }
}

function readSemester(text: string): Semester | null {
  const t = normalize(text)
  if (/\b(1ST|FIRST) SEM/.test(t)) return '1st'
  if (/\b(2ND|SECOND) SEM/.test(t)) return '2nd'
  if (/\bSUMMER\b|\bMID ?YEAR\b/.test(t)) return 'summer'
  return null
}

/** "2026-2027", "2026 – 2027", "SY 2026-27" → 2026. */
function readSchoolYears(text: string): number[] {
  const years: number[] = []
  for (const m of text.matchAll(/(?<!\d)(20\d{2})\s*[-–—/]\s*(20\d{2}|\d{2})(?!\d)/g)) {
    const start = Number(m[1])
    const end = Number(m[2]!.length === 2 ? `20${m[2]}` : m[2])
    if (end === start + 1) years.push(start)
  }
  return years
}

/** The total on the assessment, e.g. "₱12,345.00", or null when none is printed near "total". */
export function readTotal(text: string): string | null {
  const lines = text.split(/\r?\n/)
  const amount = /(\d{1,3}(?:,\d{3})+(?:\.\d{2})?|\d+\.\d{2})(?!\d)/
  for (let i = 0; i < lines.length; i++) {
    if (!/total/i.test(lines[i]!)) continue
    const found = lines[i]!.match(amount) ?? lines[i + 1]?.match(amount)
    if (found) return `₱${found[1]}`
  }
  return null
}

const SEMESTER_LABEL: Record<Semester, string> = { '1st': '1st semester', '2nd': '2nd semester', summer: 'summer term' }

function termFinding(text: string, today: Date): DocFinding {
  const now = currentTerm(today)
  const years = readSchoolYears(text)
  const semester = readSemester(text)
  const total = readTotal(text)
  const tail = total ? ` Total fees: ${total}.` : ' No total found.'
  const sy = (start: number) => `${start}–${start + 1}`

  // Before August a student may already hold next year's first-semester copy.
  const early = now.semester === 'summer' && years.includes(now.startYear + 1)
  if (!years.includes(now.startYear) && !early) {
    return {
      label: 'Current term',
      ok: false,
      detail: (years.length ? `Shows school year ${sy(years[0]!)}, not ${sy(now.startYear)}.` : "Couldn't find the school year on it.") + tail,
    }
  }
  if (!early && semester && semester !== now.semester) {
    return { label: 'Current term', ok: false, detail: `Shows the ${SEMESTER_LABEL[semester]}, not the ${SEMESTER_LABEL[now.semester]}.` + tail }
  }
  const shown = early ? now.startYear + 1 : now.startYear
  return {
    label: 'Current term',
    ok: true,
    detail: `School year ${sy(shown)}${semester ? `, ${SEMESTER_LABEL[semester]}` : ''}.` + tail,
  }
}

function collegeFinding(text: string, college: string): DocFinding {
  if (!college) return { label: 'College', ok: false, detail: 'No college on the account to compare.' }
  const t = ` ${normalize(text)} `
  const acronym = college.match(/\(([A-Z]+)\)\s*$/)?.[1]
  const name = normalize(college.replace(/\([^)]*\)\s*$/, ''))
  const ok = t.includes(` ${name} `) || (!!acronym && t.includes(` ${acronym} `))
  return { label: 'College', ok, detail: ok ? `${college}.` : `Couldn't find ${college} on it.` }
}

/** Too little text to be a document at all: blurred, dark, or not a document. */
function unreadable(text: string): boolean {
  return normalize(text).replace(/[^A-Z]/g, '').length < 25
}

export function checkDocument(type: ReadDocType, text: string, expected: DocExpected, today = new Date()): DocFinding[] {
  if (unreadable(text)) {
    return [{ label: 'Readable', ok: false, detail: "Couldn't read the text. A sharper, well-lit copy helps." }]
  }
  const shared = [nameFinding(text, expected.fullName), studentIdFinding(text, expected.studentId)]
  return type === 'school_id'
    ? [...shared, schoolFinding(text)]
    : [...shared, termFinding(text, today), collegeFinding(text, expected.college)]
}
