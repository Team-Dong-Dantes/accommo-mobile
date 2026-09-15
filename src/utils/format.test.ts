import { describe, expect, it } from 'vitest'
import { capitalizeName, composeStudentId, initialsOf, isPhMobile, isStudentId } from './format'

describe('isStudentId', () => {
  it('accepts a year and a student number of four to six digits', () => {
    expect(isStudentId('19-4820')).toBe(true)
    expect(isStudentId('19-48201')).toBe(true)
    expect(isStudentId('19-482017')).toBe(true)
  })

  it('rejects a number outside that range', () => {
    expect(isStudentId('19-482')).toBe(false)
    expect(isStudentId('19-4820174')).toBe(false)
  })

  // Every one of these is really in student_profiles today, from the free-text
  // box this replaces.
  it('rejects what the old free-text box let through', () => {
    expect(isStudentId('Lol')).toBe(false)
    expect(isStudentId('TEST-LICHTZY-0')).toBe(false)
    expect(isStudentId('2024-00123')).toBe(false)
    expect(isStudentId('123456789012')).toBe(false)
    expect(isStudentId('')).toBe(false)
    expect(isStudentId(null)).toBe(false)
  })
})

describe('composeStudentId', () => {
  it('joins the two halves with a hyphen', () => {
    expect(composeStudentId('19', '4820')).toBe('19-4820')
  })

  // Skipping must reach the column as NULL: the caller stores `|| null`, and a
  // second empty string would collide on student_profiles_student_id_key.
  it('gives an empty string when either half is missing', () => {
    expect(composeStudentId('19', '')).toBe('')
    expect(composeStudentId('', '4820')).toBe('')
    expect(composeStudentId('', '')).toBe('')
  })
})

describe('isPhMobile', () => {
  it('accepts the shapes people actually type and paste', () => {
    expect(isPhMobile('9123456789')).toBe(true)
    expect(isPhMobile('09123456789')).toBe(true)
    expect(isPhMobile('+63 912 345 6789')).toBe(true)
    expect(isPhMobile('0912-345-6789')).toBe(true)
  })

  // normalizePhPhone turns an empty field into "+63", which used to reach a NOT
  // NULL column unchallenged.
  it('rejects an empty or near-empty value', () => {
    expect(isPhMobile('')).toBe(false)
    expect(isPhMobile(null)).toBe(false)
    expect(isPhMobile('+63')).toBe(false)
  })

  it('rejects the wrong length', () => {
    expect(isPhMobile('912345678')).toBe(false)
    expect(isPhMobile('91234567890')).toBe(false)
  })

  it('rejects a number that does not start with 9', () => {
    expect(isPhMobile('8123456789')).toBe(false)
  })

  // ensureUserRow's fallback, which 117 rows carry; it should never come back
  // through a form as though someone had entered it.
  it('rejects the placeholder and finger-mashing', () => {
    expect(isPhMobile('9000000000')).toBe(false)
    expect(isPhMobile('+639000000000')).toBe(false)
    expect(isPhMobile('9999999999')).toBe(false)
  })
})

// Names are fixed rather than refused: typing "juan dela cruz" in a hurry should
// produce a correct name, not a red field.
describe('capitalizeName', () => {
  it('capitalises every part of a name', () => {
    expect(capitalizeName('juan dela cruz')).toBe('Juan Dela Cruz')
  })

  it('capitalises after an apostrophe or a hyphen', () => {
    expect(capitalizeName("o'brien")).toBe("O'Brien")
    expect(capitalizeName('mary-jane')).toBe('Mary-Jane')
  })

  // Nothing is lower-cased, so capitals the person typed on purpose survive.
  it('leaves interior capitals alone', () => {
    expect(capitalizeName('McDonald')).toBe('McDonald')
    expect(capitalizeName('DeGuzman')).toBe('DeGuzman')
  })

  it('handles accented letters', () => {
    expect(capitalizeName('ñoño')).toBe('Ñoño')
  })

  it('leaves an already-correct name untouched', () => {
    expect(capitalizeName('Juan Dela Cruz')).toBe('Juan Dela Cruz')
  })

  it('survives an empty value', () => {
    expect(capitalizeName('')).toBe('')
  })
})

// The surname's LAST word is the one that counts: "Dela Cruz" initials to C,
// not D. That is long-standing behaviour and every existing avatar depends on
// it, so this fixes only the suffix and middle-initial cases.
//
// These drive the avatar on every screen in both apps, and they used to be
// computed twice — here and by a hand-rolled copy in stores/auth.ts — so the two
// disagreed depending on which path wrote the row.
describe('initialsOf', () => {
  it('takes the given name and the surname', () => {
    expect(initialsOf('Juan Dela Cruz')).toBe('JC')
  })

  // The case the register screen's extension field made routine: taking the
  // literal last word gave "JJ", the J of Jr.
  it('ignores a generational suffix', () => {
    expect(initialsOf('Juan D. Dela Cruz Jr.')).toBe('JC')
    expect(initialsOf('Juan Dela Cruz III')).toBe('JC')
    expect(initialsOf('Juan Dela Cruz Sr')).toBe('JC')
  })

  it('ignores a middle initial, with or without its period', () => {
    expect(initialsOf('Juan D. Dela Cruz')).toBe('JC')
    expect(initialsOf('Juan D Dela Cruz')).toBe('JC')
  })

  it('keeps a suffix-looking word that is really the surname', () => {
    expect(initialsOf('Poison Ivy')).toBe('PI')
  })

  it('falls back to two letters of a single name', () => {
    expect(initialsOf('Madonna')).toBe('MA')
  })

  it('handles an empty name rather than throwing', () => {
    expect(initialsOf('')).toBe('?')
    expect(initialsOf('   ')).toBe('?')
  })

  it('uppercases whatever it finds', () => {
    expect(initialsOf('juan dela cruz')).toBe('JC')
  })
})
