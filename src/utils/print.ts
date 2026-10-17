import { Capacitor, registerPlugin } from '@capacitor/core'
import { Filesystem, Directory } from '@capacitor/filesystem'
import { Share } from '@capacitor/share'
import { Notify } from 'quasar'

// Printing and sharing for generated HTML documents (the rent report, receipts).
// Native: PrintPlugin.java (Android PrintManager, whose dialog includes "Save as
// PDF"). Web: a hidden iframe. There is no JS PDF library: PDF is Print → Save as PDF.

interface PrintPlugin {
  print(opts: { html: string; name: string; paper: string; orientation: string }): Promise<void>
}
const Print = registerPlugin<PrintPlugin>('Print')

export interface PrintOptions {
  name: string
  paper?: 'a4' | 'long'
  orientation?: 'portrait' | 'landscape'
}

export async function printHtml(html: string, { name, paper = 'a4', orientation = 'portrait' }: PrintOptions): Promise<void> {
  if (Capacitor.isNativePlatform()) {
    // An APK from before the plugin existed has no Print; the web bundle can arrive first (live update).
    if (!Capacitor.isPluginAvailable('Print')) {
      Notify.create({ message: 'Update the app to print.', color: 'grey-9', textColor: 'white', position: 'top', classes: 'custom-notify' })
      return
    }
    await Print.print({ html, name, paper, orientation })
    return
  }
  const frame = document.createElement('iframe')
  frame.style.cssText = 'position:fixed;width:0;height:0;border:0;visibility:hidden'
  frame.srcdoc = html
  frame.onload = () => {
    frame.contentWindow?.focus()
    frame.contentWindow?.print()
    // Removing it at once would close the dialog on some browsers.
    setTimeout(() => frame.remove(), 60_000)
  }
  document.body.appendChild(frame)
}

/**
 * Renders the document the way the preview shows it, as a PNG data URL. An image,
 * not the .html file: Messenger, Facebook and the other social apps only show up
 * in the share sheet for images. Same engine as the WebView, so no library.
 */
async function htmlToPng(html: string): Promise<string> {
  const frame = document.createElement('iframe')
  frame.style.cssText = 'position:fixed;left:-10000px;top:0;width:600px;height:100px;border:0'
  frame.srcdoc = html
  const loaded = new Promise((resolve) => (frame.onload = resolve))
  document.body.appendChild(frame)
  try {
    await loaded
    const root = frame.contentDocument!.documentElement
    // A wide page (the rent report) overflows the first width; widen to fit it plus its margin.
    frame.style.width = `${Math.max(600, root.scrollWidth + 32)}px`
    const w = root.scrollWidth
    const h = root.scrollHeight
    const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}"><foreignObject width="100%" height="100%">${new XMLSerializer().serializeToString(root)}</foreignObject></svg>`
    const img = new Image()
    img.src = `data:image/svg+xml;charset=utf-8,${encodeURIComponent(svg)}`
    await img.decode()
    // 2x for sharpness, less for a long report so the canvas stays under Android's ~16M px cap.
    const scale = Math.min(2, Math.sqrt(12e6 / (w * h)))
    const canvas = document.createElement('canvas')
    canvas.width = Math.round(w * scale)
    canvas.height = Math.round(h * scale)
    const ctx = canvas.getContext('2d')!
    ctx.fillStyle = '#fff'
    ctx.fillRect(0, 0, canvas.width, canvas.height)
    ctx.scale(scale, scale)
    ctx.drawImage(img, 0, 0)
    return canvas.toDataURL('image/png')
  } finally {
    frame.remove()
  }
}

// Dismissing the sheet rejects (native: "Share canceled", web: AbortError); that is not a failure.
const ignoreCancel = (e: unknown) => {
  if ((e as Error)?.name !== 'AbortError' && !/cancel/i.test((e as Error)?.message ?? '')) throw e
}

/** Shares the document as `<name>.png`: the share sheet on a device, else a download. */
export async function shareHtml(html: string, { name, title }: { name: string; title: string }): Promise<void> {
  const file = `${name}.png`
  const png = await htmlToPng(html)
  if (Capacitor.isNativePlatform()) {
    const { uri } = await Filesystem.writeFile({ path: file, data: png.split(',')[1]!, directory: Directory.Cache })
    await Share.share({ title, files: [uri] }).catch(ignoreCancel)
    return
  }
  const blob = new File([await (await fetch(png)).blob()], file, { type: 'image/png' })
  if (navigator.canShare?.({ files: [blob] })) {
    await navigator.share({ title, files: [blob] }).catch(ignoreCancel)
    return
  }
  const a = document.createElement('a')
  a.href = png
  a.download = file
  a.click()
}
