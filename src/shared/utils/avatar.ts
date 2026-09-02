import { supabase } from '@/shared/utils/supabase'

/**
 * Reads the user's current profile photo from Google OAuth identity metadata and
 * re-applies it as the app avatar (user_metadata.avatar_url).
 *
 * Google populates both `user_metadata.avatar_url` and `user_metadata.picture`.
 * Once a user uploads a custom photo in Edit Profile we overwrite `avatar_url`,
 * but `picture` still holds the original Google image, which is what this
 * "Use my Google photo" control restores.
 *
 * @returns the applied photo URL, or null when there is no Google photo to use.
 */
export async function restoreGooglePhoto(): Promise<string | null> {
  const { data, error } = await supabase.auth.getUser()
  if (error || !data?.user) return null

  const meta = (data.user.user_metadata ?? {}) as Record<string, unknown>
  const picture =
    typeof meta.picture === 'string' && meta.picture
      ? meta.picture
      : typeof meta.avatar_url === 'string' && meta.avatar_url
        ? meta.avatar_url
        : ''

  if (!picture) return null

  const { error: updateError } = await supabase.auth.updateUser({ data: { avatar_url: picture } })
  if (updateError) {
    console.warn('[avatar] restore google photo failed:', updateError.message)
    return null
  }
  return picture
}
