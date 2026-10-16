import { describe, it, expect } from 'vitest'
import { canChange, linkify, reactionChips, snippet } from './chat'

describe('linkify', () => {
  it('leaves plain text alone', () => {
    expect(linkify('see you at 5')).toEqual([{ text: 'see you at 5' }])
  })

  it('links a URL and drops trailing punctuation', () => {
    expect(linkify('map: https://maps.app/x. thanks')).toEqual([
      { text: 'map: ' },
      { text: 'https://maps.app/x', href: 'https://maps.app/x', external: true },
      { text: '. thanks' },
    ])
  })

  it('adds a scheme to www links', () => {
    expect(linkify('www.usep.edu.ph')[0]).toMatchObject({ href: 'https://www.usep.edu.ph' })
  })

  it('links PH mobile numbers in both forms', () => {
    expect(linkify('call 0917-123-4567')[1]).toEqual({ text: '0917-123-4567', href: 'tel:+639171234567' })
    expect(linkify('+639171234567')[0]).toMatchObject({ href: 'tel:+639171234567' })
  })

  it('ignores digits inside a longer number', () => {
    expect(linkify('ref 1209171234567')).toEqual([{ text: 'ref 1209171234567' }])
  })
})

describe('reactionChips', () => {
  it('folds the same emoji into one chip and flags mine', () => {
    expect(reactionChips({ a: '👍', b: '👍', c: '😂' }, 'b')).toEqual([
      { emoji: '👍', count: 2, mine: true },
      { emoji: '😂', count: 1, mine: false },
    ])
  })
})

describe('snippet', () => {
  it('names what a textless message is', () => {
    expect(snippet({ body: '', deletedAt: 'x' })).toBe('Message removed')
    expect(snippet({ body: '', accommodationId: 'a' })).toBe('Listing')
    expect(snippet({ body: '', file: true, attachmentUrl: 'u' })).toBe('File')
    expect(snippet({ body: '', attachmentUrl: 'u' })).toBe('Photo')
  })
})

describe('canChange', () => {
  const sent = '2026-10-16T02:00:00Z'
  const at = (min: number) => new Date(sent).getTime() + min * 60_000
  it('allows edit/unsend inside the window and refuses after', () => {
    expect(canChange({ sentAt: sent }, at(14))).toBe(true)
    expect(canChange({ sentAt: sent }, at(15))).toBe(false)
  })
})
